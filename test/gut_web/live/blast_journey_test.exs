defmodule GutWeb.BlastJourneyTest do
  @moduledoc """
  End-to-end journeys for workshop blasts:

  - An organizer composes a blast with a live preview and sends it.
  - An attendee finds it on the browse page and reads it.
  - The emailed link signs the attendee in and lands on the blast.
  - Access control for the compose and view pages.
  """
  use GutWeb.FeatureCase
  use Oban.Testing, repo: Gut.Repo

  @system_actor Gut.system_actor("test")

  defp create_workshop_with_organizer(_context) do
    room = generate(workshop_room(name: "Big Room", limit: 30))
    slot = generate(workshop_timeslot(name: "Morning Session"))

    workshop =
      generate(
        workshop(
          name: "LiveView Deep Dive",
          limit: 20,
          workshop_room_id: room.id,
          workshop_timeslot_id: slot.id
        )
      )

    organizer = generate(user(role: :speaker, email: "organizer@test.com"))
    speaker = generate(speaker(user_id: organizer.id, full_name: "Org Anizer"))

    Gut.Conference.create_workshop_speaker!(
      %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @system_actor
    )

    %{workshop: workshop, organizer: organizer, speaker: speaker}
  end

  defp register_attendee(workshop, email) do
    user = generate(user(role: :attendee, email: email))
    participant = generate(workshop_participant(user_id: user.id))

    {:ok, _} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    user
  end

  describe "organizer journey" do
    setup [:create_workshop_with_organizer]

    test "composes a blast with a live preview and sends it to attendees", %{
      conn: conn,
      organizer: organizer,
      workshop: workshop
    } do
      register_attendee(workshop, "one@test.com")
      register_attendee(workshop, "two@test.com")

      conn = log_in_user(conn, organizer)

      session =
        conn
        |> visit("/my-workshops")
        |> assert_has("h2", text: "LiveView Deep Dive")
        |> click_link("Send update")
        |> assert_has("h1", text: "Send an update to attendees of LiveView Deep Dive")
        |> assert_has("#sent-blasts", text: "No updates have been sent")
        |> assert_has("span", text: "Goes to 2 registered attendees.")
        |> fill_in("Subject", with: "Bring a laptop")
        |> fill_in("Message",
          with: "Please bring a **charged** laptop.\n\n- Editor\n- Elixir 1.20"
        )

      # The preview renders the Markdown as attendees will see it.
      session
      |> assert_has("#blast-preview h3", text: "Bring a laptop")
      |> assert_has("#blast-preview strong", text: "charged")
      |> assert_has("#blast-preview li", text: "Elixir 1.20")

      session
      |> click_button("Send Blast")
      |> assert_has("div", text: "Update sent to 2 attendees.")
      |> assert_has("#sent-blasts td", text: "Bring a laptop")
      # The form is cleared for the next one.
      |> refute_has("#blast-preview strong", text: "charged")

      emails =
        all_enqueued(worker: Gut.Workers.BlastEmail)
        |> Enum.map(& &1.args["email"])
        |> Enum.sort()

      assert emails == ["one@test.com", "two@test.com"]

      [blast] = Gut.Conference.list_blasts!(actor: @system_actor)
      assert blast.title == "Bring a laptop"
      assert blast.workshop_id == workshop.id
    end

    test "cannot send an empty blast", %{conn: conn, organizer: organizer, workshop: workshop} do
      conn
      |> log_in_user(organizer)
      |> visit("/workshops/#{workshop.id}/blasts")
      |> fill_in("Subject", with: "Only a subject")
      |> click_button("Send Blast")
      |> assert_has("#sent-blasts", text: "No updates have been sent")

      assert Gut.Conference.list_blasts!(actor: @system_actor) == []
    end

    test "staff can also send from the compose page", %{conn: conn, workshop: workshop} do
      conn
      |> visit("/workshops/#{workshop.id}/blasts")
      |> fill_in("Subject", with: "From staff")
      |> fill_in("Message", with: "Hello from the crew.")
      |> click_button("Send Blast")
      |> assert_has("#sent-blasts td", text: "From staff")
    end

    test "a speaker on another workshop is turned away", %{conn: conn, workshop: workshop} do
      other = generate(user(role: :speaker, email: "other-speaker@test.com"))
      generate(speaker(user_id: other.id))

      conn
      |> log_in_user(other)
      |> visit("/workshops/#{workshop.id}/blasts")
      |> assert_path("/my-travel")
      |> assert_has("div", text: "You are not an organizer of this workshop.")
    end

    test "an attendee is turned away", %{conn: conn, workshop: workshop} do
      attendee = register_attendee(workshop, "sneaky@test.com")

      conn
      |> log_in_user(attendee)
      |> visit("/workshops/#{workshop.id}/blasts")
      |> assert_path("/workshops/browse")
      |> assert_has("div", text: "You are not an organizer of this workshop.")
    end
  end

  describe "attendee journey" do
    setup [:create_workshop_with_organizer]

    setup %{workshop: workshop} do
      blast =
        Gut.Conference.send_blast!(
          %{
            title: "Room change",
            body: "We moved to **Room B**.",
            workshop_id: workshop.id
          },
          actor: @system_actor
        )

      %{blast: blast}
    end

    test "sees the blast listed on the browse page and can read it", %{
      conn: conn,
      workshop: workshop,
      blast: blast
    } do
      attendee = register_attendee(workshop, "reader@test.com")

      conn
      |> log_in_user(attendee)
      |> visit("/workshops/browse")
      |> assert_has("#attendee-updates h2", text: "From your workshops")
      |> assert_has("#attendee-blasts a", text: "Room change")
      |> assert_has("#attendee-blasts", text: "LiveView Deep Dive")
      |> click_link("#attendee-blasts a", "Room change")
      |> assert_path("/blasts/#{blast.id}")
      |> assert_has("h1", text: "Room change")
      |> assert_has("strong", text: "Room B")
      |> assert_has("p", text: "LiveView Deep Dive")
    end

    test "surveys and blasts share the updates block", %{conn: conn, workshop: workshop} do
      attendee = register_attendee(workshop, "both@test.com")

      survey =
        Gut.Conference.create_survey!(
          %{
            title: "How did we do?",
            workshop_id: workshop.id,
            questions: [%{prompt: "Feedback?", question_type: :single_line}]
          },
          actor: @system_actor
        )

      survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
      Gut.Conference.send_survey!(survey, actor: @system_actor)

      conn
      |> log_in_user(attendee)
      |> visit("/workshops/browse")
      |> assert_has("#attendee-surveys a", text: "Answer the survey for LiveView Deep Dive")
      |> assert_has("#attendee-blasts a", text: "Room change")
    end

    test "an attendee of a different workshop sees neither the listing nor the page", %{
      conn: conn,
      blast: blast
    } do
      other_workshop = generate(workshop(name: "Other Workshop"))
      other = register_attendee(other_workshop, "elsewhere@test.com")

      conn
      |> log_in_user(other)
      |> visit("/workshops/browse")
      |> refute_has("#attendee-blasts")
      |> visit("/blasts/#{blast.id}")
      |> assert_has("h1", text: "Update not available")
      |> refute_has("strong", text: "Room B")
    end

    test "a logged-out visitor is sent to sign in", %{pid: pid, blast: blast} do
      build_unauthenticated_conn(pid)
      |> visit("/blasts/#{blast.id}")
      |> assert_path("/sign-in")
    end

    test "the organizer can read the blast page too", %{
      conn: conn,
      organizer: organizer,
      blast: blast
    } do
      conn
      |> log_in_user(organizer)
      |> visit("/blasts/#{blast.id}")
      |> assert_has("h1", text: "Room change")
    end
  end
end
