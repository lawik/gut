defmodule Gut.Conference.PromotionEmailTest do
  @moduledoc """
  Attendees promoted from a workshop waitlist into a seat are emailed, and
  freed seats are handed out in waitlist order rather than to newcomers.
  """
  use Gut.DataCase
  use Oban.Testing, repo: Gut.Repo

  @actor Gut.system_actor("test")

  defp small_workshop(limit \\ 1) do
    room = generate(workshop_room(name: "Lab", limit: 10))

    slot =
      generate(
        workshop_timeslot(
          name: "Morning",
          start: ~U[2026-10-06 09:00:00Z],
          end: ~U[2026-10-06 12:00:00Z]
        )
      )

    generate(
      workshop(
        name: "Nerves",
        limit: limit,
        workshop_room_id: room.id,
        workshop_timeslot_id: slot.id
      )
    )
  end

  defp register(workshop, participant) do
    Gut.Conference.register_for_workshop!(
      %{workshop_id: workshop.id, workshop_participant_id: participant.id},
      actor: @actor
    )
  end

  defp participant_with_email(name, email) do
    user = generate(user(role: :attendee, email: email))
    generate(workshop_participant(name: name, user_id: user.id))
  end

  describe "promotion" do
    test "emails the promoted attendee, and only them" do
      workshop = small_workshop()
      seated = register(workshop, participant_with_email("Seated", "seated@test.com"))
      waiting = register(workshop, participant_with_email("Wanda", "wanda@test.com"))
      still = register(workshop, participant_with_email("Still", "still@test.com"))
      assert waiting.status == :waitlisted
      assert still.status == :waitlisted

      # A withdrawal frees a seat; nobody is emailed until staff promote.
      Gut.Conference.destroy_workshop_participation!(seated, actor: @actor)
      assert all_enqueued(worker: Gut.Workers.PromotionEmail) == []

      assert {:ok, 1} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)

      assert [job] = all_enqueued(worker: Gut.Workers.PromotionEmail)
      assert job.args["participation_id"] == waiting.id

      assert :ok = perform_job(Gut.Workers.PromotionEmail, job.args)
      assert_receive {:email, email}
      assert [{_, "wanda@test.com"}] = email.to
      assert email.subject == "You now have a seat in Nerves"
      assert email.html_body =~ "Hello Wanda!"
      assert email.html_body =~ "<strong>Nerves</strong>"
      assert email.html_body =~ "Morning, Tuesday October 06, 09:00-12:00, Lab"
      assert email.html_body =~ "info@goatmire.com or via Discord"
      assert email.html_body =~ "/browse-link?token="
      assert email.text_body =~ "you were next on the waitlist"
    end

    test "a direct registration into a free seat sends nothing" do
      workshop = small_workshop(5)
      register(workshop, participant_with_email("Direct", "direct@test.com"))

      assert all_enqueued(worker: Gut.Workers.PromotionEmail) == []
    end

    test "a promoted participant without an email is skipped at delivery" do
      workshop = small_workshop()
      seated = register(workshop, generate(workshop_participant(name: "Seated")))
      waiting = register(workshop, generate(workshop_participant(name: "No account")))

      Gut.Conference.destroy_workshop_participation!(seated, actor: @actor)
      assert {:ok, 1} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)

      assert {:cancel, _} =
               perform_job(Gut.Workers.PromotionEmail, %{"participation_id" => waiting.id})

      refute_receive {:email, _}
    end

    test "delivery is cancelled if the participation is gone or back on the waitlist" do
      workshop = small_workshop()
      seated = register(workshop, participant_with_email("Seated", "seated@test.com"))
      waiting = register(workshop, participant_with_email("Wanda", "wanda@test.com"))

      Gut.Conference.destroy_workshop_participation!(seated, actor: @actor)
      assert {:ok, 1} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)

      promoted = Ash.get!(Gut.Conference.WorkshopParticipation, waiting.id, actor: @actor)

      Gut.Conference.update_workshop_participation!(promoted, %{status: :waitlisted},
        actor: @actor
      )

      assert {:cancel, _} =
               perform_job(Gut.Workers.PromotionEmail, %{"participation_id" => waiting.id})

      assert {:cancel, _} =
               perform_job(Gut.Workers.PromotionEmail, %{
                 "participation_id" => Ash.UUID.generate()
               })

      refute_receive {:email, _}
    end

    test "escapes names in the email" do
      workshop = small_workshop()
      seated = register(workshop, generate(workshop_participant(name: "Seated")))
      register(workshop, participant_with_email("<script>x</script>", "x@test.com"))

      Gut.Conference.destroy_workshop_participation!(seated, actor: @actor)
      assert {:ok, 1} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)

      [job] = all_enqueued(worker: Gut.Workers.PromotionEmail)
      assert :ok = perform_job(Gut.Workers.PromotionEmail, job.args)
      assert_receive {:email, email}
      refute email.html_body =~ "<script>"
      assert email.html_body =~ "&lt;script&gt;"
    end
  end

  describe "fairness" do
    test "a freed seat is held for the waitlist instead of going to a newcomer" do
      workshop = small_workshop()
      seated = register(workshop, generate(workshop_participant(name: "Seated")))
      first = register(workshop, generate(workshop_participant(name: "First in line")))
      assert first.status == :waitlisted

      Gut.Conference.destroy_workshop_participation!(seated, actor: @actor)

      newcomer = register(workshop, generate(workshop_participant(name: "Newcomer")))
      assert newcomer.status == :waitlisted

      assert {:ok, 1} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)

      assert Ash.get!(Gut.Conference.WorkshopParticipation, first.id, actor: @actor).status ==
               :registered

      assert Ash.get!(Gut.Conference.WorkshopParticipation, newcomer.id, actor: @actor).status ==
               :waitlisted
    end

    test "with nobody waiting, a free seat is still given out directly" do
      workshop = small_workshop(2)
      register(workshop, generate(workshop_participant(name: "One")))
      two = register(workshop, generate(workshop_participant(name: "Two")))
      assert two.status == :registered
    end
  end
end
