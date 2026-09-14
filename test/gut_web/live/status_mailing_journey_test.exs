defmodule GutWeb.StatusMailingJourneyTest do
  @moduledoc """
  Staff send the workshop status email from the status-mailing page; the
  preview reflects the intro as it is edited; non-staff are kept out.
  """
  use GutWeb.FeatureCase
  use Oban.Testing, repo: Gut.Repo

  @system_actor Gut.system_actor("test")

  setup do
    slot = generate(workshop_timeslot(name: "Morning"))
    room = generate(workshop_room(name: "Lab", limit: 1))

    full =
      generate(workshop(name: "Nerves", workshop_timeslot_id: slot.id, workshop_room_id: room.id))

    open = generate(workshop(name: "Intro to Elixir", limit: 20, workshop_timeslot_id: slot.id))

    register = fn workshop, participant ->
      Gut.Conference.register_for_workshop!(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )
    end

    register.(full, generate(workshop_participant(name: "Filler")))

    seated_user = generate(user(role: :attendee, email: "seated@test.com"))
    seated = generate(workshop_participant(name: "Sam Seated", user_id: seated_user.id))
    register.(open, seated)

    waiting_user = generate(user(role: :attendee, email: "waiting@test.com"))
    waiting = generate(workshop_participant(name: "Wanda Waitlist", user_id: waiting_user.id))
    register.(full, waiting)

    %{seated: seated, waiting: waiting}
  end

  test "staff preview and send the status emails", %{conn: conn, seated: seated, waiting: waiting} do
    session =
      conn
      |> visit("/workshops")
      |> click_link("Status emails")
      |> assert_has("h1", text: "Workshop status emails")
      |> assert_has("#recipient-count", text: "Goes to 2 participants")
      # The waitlisted participant is picked as the example.
      |> assert_has("#status-preview", text: "As it will be sent to Wanda Waitlist")
      |> assert_has("#status-preview", text: "You are on the waitlist for")
      |> assert_has("#status-preview strong", text: "Nerves")
      |> assert_has("#status-preview", text: "Still has seats in this timeslot: Intro to Elixir")
      |> assert_has("#status-preview", text: "contact us")
      |> assert_has("#sent-mailings", text: "No status emails have been sent yet.")

    session
    |> fill_in("Intro", with: "See you _soon_!")
    |> assert_has("#status-preview em", text: "soon")
    |> refute_has("#status-preview", text: "contact us")
    |> click_button("Send status emails")
    |> assert_has("div", text: "Status emails sent to 2 participants.")
    |> assert_has("#sent-mailings td", text: "2")
    |> assert_has("#sent-mailings td", text: "See you _soon_!")
    # The intro resets to the default afterwards.
    |> assert_has("#status-preview", text: "contact us")

    ids =
      all_enqueued(worker: Gut.Workers.StatusEmail)
      |> Enum.map(& &1.args["participant_id"])
      |> Enum.sort()

    assert ids == Enum.sort([seated.id, waiting.id])
  end

  test "an attendee cannot open the page", %{conn: conn} do
    conn
    |> log_in_as(:attendee)
    |> visit("/workshops/status-mailing")
    |> refute_has("h1", text: "Workshop status emails")
  end

  test "a speaker cannot open the page", %{conn: conn} do
    conn
    |> log_in_as(:speaker)
    |> visit("/workshops/status-mailing")
    |> refute_has("h1", text: "Workshop status emails")
  end
end
