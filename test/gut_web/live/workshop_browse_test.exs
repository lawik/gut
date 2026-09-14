defmodule GutWeb.WorkshopBrowseLiveTest do
  use GutWeb.FeatureCase

  defp create_workshop_data(_context) do
    room = generate(workshop_room(name: "Main Hall", limit: 30))
    slot = generate(workshop_timeslot(name: "Morning Session"))

    workshop =
      generate(
        workshop(
          name: "Intro to Elixir",
          limit: 20,
          workshop_room_id: room.id,
          workshop_timeslot_id: slot.id
        )
      )

    %{room: room, slot: slot, workshop: workshop}
  end

  defp select_workshop(session, workshop, slot) do
    unwrap(session, fn view ->
      view
      |> Phoenix.LiveViewTest.element(
        "div[phx-value-workshop_id='#{workshop.id}'][phx-value-timeslot_id='#{slot.id}']"
      )
      |> Phoenix.LiveViewTest.render_click()
    end)
  end

  describe "unauthenticated user" do
    setup [:create_workshop_data]

    test "sees workshop grid with workshop names", %{pid: pid, workshop: workshop} do
      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/workshops/browse")
      |> assert_has("h4", text: workshop.name)
    end

    test "does not see radio buttons for selection", %{pid: pid} do
      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/workshops/browse")
      |> refute_has("input[type='radio']")
    end

    test "sees email prompt with login link button", %{pid: pid} do
      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/workshops/browse")
      |> assert_has("input[type='email']")
      |> assert_has("button", text: "Send login link")
    end

    test "can request magic link and sees confirmation", %{pid: pid} do
      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/workshops/browse")
      |> fill_in("Email address", with: "attendee@test.com")
      |> click_button("Send login link")
      |> assert_has("h2", text: "Check your email!")
    end
  end

  describe "waitlist holds freed seats" do
    setup [:create_workshop_data]

    test "a workshop with people waiting shows as full even with a free seat", %{
      pid: pid,
      slot: slot
    } do
      tiny = generate(workshop(name: "Tiny", limit: 1, workshop_timeslot_id: slot.id))
      seated = generate(workshop_participant(name: "Seated"))
      waiting = generate(workshop_participant(name: "Waiting"))

      {:ok, seated_participation} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: tiny.id, workshop_participant_id: seated.id},
          actor: Gut.system_actor("test")
        )

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: tiny.id, workshop_participant_id: waiting.id},
          actor: Gut.system_actor("test")
        )

      Gut.Conference.destroy_workshop_participation!(seated_participation,
        actor: Gut.system_actor("test")
      )

      build_unauthenticated_conn(pid)
      |> visit("/workshops/browse")
      |> assert_has("div[phx-value-workshop_id='#{tiny.id}']", text: "Full (waitlist available)")
    end
  end

  describe "day counts" do
    setup [:create_workshop_data]

    test "shows registered and waitlist totals for the day", %{
      pid: pid,
      slot: slot,
      workshop: workshop
    } do
      small_room = generate(workshop_room(name: "Small Room", limit: 1))

      small_workshop =
        generate(
          workshop(
            name: "Tiny Workshop",
            limit: 1,
            workshop_room_id: small_room.id,
            workshop_timeslot_id: slot.id
          )
        )

      actor = Gut.system_actor("test")

      for w <- [workshop, small_workshop] do
        participant = generate(workshop_participant())

        Gut.Conference.register_for_workshop!(
          %{workshop_id: w.id, workshop_participant_id: participant.id},
          actor: actor
        )
      end

      waitlisted = generate(workshop_participant())

      Gut.Conference.register_for_workshop!(
        %{workshop_id: small_workshop.id, workshop_participant_id: waitlisted.id},
        actor: actor
      )

      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/workshops/browse")
      |> assert_has("span", text: "2 registered")
      |> assert_has("span", text: "1 on waitlist")
    end
  end

  describe "read more modal" do
    setup [:create_workshop_data]

    test "shows read more link when workshop has description", %{conn: conn} do
      conn
      |> visit("/workshops/browse")
      |> assert_has("a", text: "Read more")
    end

    test "clicking read more opens modal with full description", %{
      conn: conn,
      workshop: workshop
    } do
      conn
      |> visit("/workshops/browse")
      |> click_link("Read more")
      |> assert_has(".modal h3", text: workshop.name)
      |> assert_has(".modal p", text: workshop.description)
    end

    test "modal can be closed with close button", %{conn: conn} do
      conn
      |> visit("/workshops/browse")
      |> click_link("Read more")
      |> assert_has(".modal")
      |> click_button(".modal-action button", "Close")
      |> refute_has(".modal")
    end
  end

  describe "authenticated user" do
    setup [:create_workshop_data]

    test "sees workshop grid with radio buttons", %{conn: conn, workshop: workshop} do
      conn
      |> visit("/workshops/browse")
      |> assert_has("h4", text: workshop.name)
      |> assert_has("input[type='radio']")
    end

    test "sees name input", %{conn: conn} do
      conn
      |> visit("/workshops/browse")
      |> assert_has("span", text: "Name *")
    end

    test "cannot save without name", %{conn: conn, workshop: workshop, slot: slot} do
      conn
      |> visit("/workshops/browse")
      |> select_workshop(workshop, slot)
      |> fill_in("Name *", with: "")
      |> click_button("Register")
      |> assert_has("p", text: "Name is required")
    end

    test "can save with name after selecting workshop", %{
      conn: conn,
      workshop: workshop,
      slot: slot
    } do
      conn
      |> visit("/workshops/browse")
      |> select_workshop(workshop, slot)
      |> fill_in("Name *", with: "Test User")
      |> click_button("Register")
      |> assert_has("h2", text: "Registration Complete!")
    end
  end

  describe "unsubscribing from all workshops" do
    setup [:create_workshop_data]

    test "can deselect the only workshop and save to free the spot", %{
      conn: conn,
      user: user,
      workshop: workshop,
      slot: slot
    } do
      participant =
        generate(workshop_participant(user_id: user.id, name: "Existing Attendee"))

      Gut.Conference.register_for_workshop!(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: Gut.system_actor("test")
      )

      conn
      |> visit("/workshops/browse")
      |> assert_has("button", text: "Save Changes")
      |> select_workshop(workshop, slot)
      |> click_button("Save Changes")
      |> assert_has("h2", text: "Registration Complete!")

      assert Gut.Conference.WorkshopParticipation
             |> Ash.read!(actor: Gut.system_actor("test")) == []
    end
  end
end
