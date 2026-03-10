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
end
