defmodule Gut.Conference.StatusMailingTest do
  @moduledoc """
  Unit tests for the workshop status mailing: who receives it, who may send
  it, and what the generated email says.
  """
  use Gut.DataCase
  use Oban.Testing, repo: Gut.Repo

  alias Gut.Emails.WorkshopStatus

  @system_actor Gut.system_actor("test")

  defp participant_with_user(name, email) do
    user = generate(user(role: :attendee, email: email))
    generate(workshop_participant(name: name, user_id: user.id))
  end

  defp register(workshop, participant) do
    Gut.Conference.register_for_workshop!(
      %{workshop_id: workshop.id, workshop_participant_id: participant.id},
      actor: @system_actor
    )
  end

  # Two timeslots. Slot A: a full workshop (limit 1) plus two alternatives,
  # one of which is also full. Slot B: one workshop with room to spare.
  defp schedule do
    slot_a = generate(workshop_timeslot(name: "Morning", start: ~U[2026-10-06 09:00:00Z]))

    slot_b =
      generate(
        workshop_timeslot(
          name: "Afternoon",
          start: ~U[2026-10-06 13:00:00Z],
          end: ~U[2026-10-06 16:00:00Z]
        )
      )

    room = generate(workshop_room(name: "Lab", limit: 1))

    full =
      generate(
        workshop(
          name: "Nerves",
          limit: 10,
          workshop_timeslot_id: slot_a.id,
          workshop_room_id: room.id
        )
      )

    open = generate(workshop(name: "Intro to Elixir", limit: 20, workshop_timeslot_id: slot_a.id))
    also_full = generate(workshop(name: "Tiny", limit: 1, workshop_timeslot_id: slot_a.id))

    afternoon =
      generate(workshop(name: "OTP Patterns", limit: 20, workshop_timeslot_id: slot_b.id))

    register(full, generate(workshop_participant(name: "Filler")))
    register(also_full, generate(workshop_participant(name: "Other filler")))

    %{full: full, open: open, also_full: also_full, afternoon: afternoon}
  end

  describe "recipients" do
    test "participants with a user email and at least one participation, nobody else" do
      %{full: full, afternoon: afternoon} = schedule()

      seated = participant_with_user("Seated", "seated@test.com")
      register(afternoon, seated)

      waitlisted = participant_with_user("Waiting", "waiting@test.com")
      register(full, waitlisted)

      # No workshops at all.
      participant_with_user("Idle", "idle@test.com")

      # Registered but no account to email.
      register(afternoon, generate(workshop_participant(name: "No account")))

      names = WorkshopStatus.recipients() |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["Seated", "Waiting"]
    end
  end

  describe "sending" do
    test "staff can send; one job per recipient and the count is stored" do
      %{afternoon: afternoon} = schedule()
      a = participant_with_user("A", "a@test.com")
      b = participant_with_user("B", "b@test.com")
      register(afternoon, a)
      register(afternoon, b)
      staff = generate(user(role: :staff))

      assert {:ok, mailing} =
               Gut.Conference.send_status_mailing(%{intro: "Hello all"}, actor: staff)

      assert mailing.recipient_count == 2
      assert mailing.sent_at

      ids =
        all_enqueued(worker: Gut.Workers.StatusEmail)
        |> Enum.map(& &1.args["participant_id"])
        |> Enum.sort()

      assert ids == Enum.sort([a.id, b.id])

      assert Enum.all?(
               all_enqueued(worker: Gut.Workers.StatusEmail),
               &(&1.args["mailing_id"] == mailing.id)
             )
    end

    test "organizers and attendees cannot send" do
      speaker_user = generate(user(role: :speaker))
      attendee_user = generate(user(role: :attendee))

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.send_status_mailing(%{intro: "Hi"}, actor: speaker_user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.send_status_mailing(%{intro: "Hi"}, actor: attendee_user)
    end

    test "the intro is required" do
      staff = generate(user(role: :staff))

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.send_status_mailing(%{intro: "   "}, actor: staff)
    end
  end

  describe "the email" do
    setup do
      %{full: full, afternoon: afternoon} = schedule()
      participant = participant_with_user("Wanda", "wanda@test.com")
      register(afternoon, participant)
      register(full, participant)

      {:ok, mailing} =
        Gut.Conference.send_status_mailing(%{intro: "Here is **where you stand**."},
          actor: @system_actor
        )

      %{participant: participant, mailing: mailing}
    end

    test "lists seats, waitlists and open alternatives in the same timeslot", %{
      participant: participant,
      mailing: mailing
    } do
      assert :ok =
               perform_job(Gut.Workers.StatusEmail, %{
                 "mailing_id" => mailing.id,
                 "participant_id" => participant.id
               })

      assert_receive {:email, email}
      assert [{_, "wanda@test.com"}] = email.to
      assert email.subject == "Your Goatmire workshop registrations"

      html = email.html_body
      assert html =~ "Hello Wanda!"
      assert html =~ "<strong>where you stand</strong>"
      assert html =~ "You have a seat in"
      assert html =~ "<strong>OTP Patterns</strong>"
      assert html =~ "Afternoon, Tuesday October 06, 13:00-16:00"
      assert html =~ "You are on the waitlist for"
      assert html =~ "<strong>Nerves</strong>"
      assert html =~ "Lab"
      # Intro to Elixir has seats in the same slot; Tiny is full and not suggested.
      assert html =~ "Still has seats in this timeslot: Intro to Elixir (20 seats left)"
      refute html =~ "Tiny"
      assert html =~ "/browse-link?token="

      text = email.text_body
      assert text =~ "You have a seat in:\n  - OTP Patterns"
      assert text =~ "You are on the waitlist for:\n  - Nerves"
      assert text =~ "Intro to Elixir (20 left)"
      assert text =~ "/browse-link?token="
    end

    test "says so when the participant has no seat anywhere" do
      %{full: full} = schedule()
      only_waiting = participant_with_user("Wally", "wally@test.com")
      register(full, only_waiting)

      data = WorkshopStatus.build(only_waiting, "Intro")
      assert data.registered == []
      assert [%{name: "Nerves"}] = data.waitlisted

      html = WorkshopStatus.html(data, "https://example.com/link")
      assert html =~ "You do not currently have a seat in any workshop."
      assert html =~ "You are on the waitlist for"
    end

    test "escapes participant and workshop names" do
      slot = generate(workshop_timeslot())
      workshop = generate(workshop(name: "<b>Bold</b> workshop", workshop_timeslot_id: slot.id))
      participant = participant_with_user("<script>x</script>", "x@test.com")
      register(workshop, participant)

      html = WorkshopStatus.html(WorkshopStatus.build(participant, "Hi"), "https://example.com")
      refute html =~ "<script>"
      refute html =~ "<b>Bold</b>"
      assert html =~ "&lt;b&gt;Bold&lt;/b&gt;"
    end

    test "cancels when the mailing or participant is gone", %{mailing: mailing} do
      assert {:cancel, _} =
               perform_job(Gut.Workers.StatusEmail, %{
                 "mailing_id" => Ash.UUID.generate(),
                 "participant_id" => Ash.UUID.generate()
               })

      assert {:cancel, _} =
               perform_job(Gut.Workers.StatusEmail, %{
                 "mailing_id" => mailing.id,
                 "participant_id" => Ash.UUID.generate()
               })

      refute_receive {:email, _}
    end

    test "the default intro tells people how to free up their seat" do
      intro = WorkshopStatus.default_intro()
      assert intro =~ "Goatmire approaches"
      assert intro =~ "cannot attend"
      assert intro =~ "info@goatmire.com or via Discord"
      assert intro =~ "remove you to make space for others"
    end
  end
end
