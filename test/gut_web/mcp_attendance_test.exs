defmodule GutWeb.McpAttendanceTest do
  @moduledoc """
  End-to-end check of the MCP workshop attendance tools: authenticate with a
  staff API key against /mcp and call the tool over JSON-RPC.
  """
  use GutWeb.ConnCase, async: false

  import Gut.Generators

  @system_actor Gut.system_actor("test")

  defp api_key_for(user) do
    Gut.Accounts.create_api_key!(
      %{user_id: user.id, expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)},
      actor: @system_actor
    ).__metadata__.plaintext_api_key
  end

  defp call_tool(conn, api_key, tool, arguments) do
    payload = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => %{"name" => tool, "arguments" => arguments}
    }

    conn
    |> put_req_header("authorization", "Bearer " <> api_key)
    |> put_req_header("accept", "application/json")
    |> post(~p"/mcp", payload)
  end

  test "staff api key can fetch workshop attendance stats", %{conn: conn} do
    slot = generate(workshop_timeslot(name: "Morning Stats Slot"))
    room = generate(workshop_room(name: "Stats Room"))

    workshop =
      generate(
        workshop(
          name: "Stats Workshop",
          limit: 2,
          workshop_timeslot_id: slot.id,
          workshop_room_id: room.id
        )
      )

    for _ <- 1..3 do
      participant = generate(workshop_participant())

      Gut.Conference.register_for_workshop!(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )
    end

    staff = generate(user(role: :staff))
    conn = call_tool(conn, api_key_for(staff), "list_workshop_attendance", %{})

    response = json_response(conn, 200)
    text = get_in(response, ["result", "content", Access.at(0), "text"])

    assert text =~ "Stats Workshop"
    assert text =~ "registration_count"
    assert text =~ "waitlist_count"
    assert text =~ "spots_remaining"
    assert text =~ "Morning Stats Slot"
    assert text =~ "Stats Room"

    # Attendance stats must stay aggregate-only: no attendee PII in the output.
    # Generated participants are named "Participant N" with @test.com emails.
    refute text =~ "Participant "
    refute text =~ "@test.com"

    conn2 = call_tool(build_conn(), api_key_for(staff), "list_timeslot_attendance", %{})
    slot_text = get_in(json_response(conn2, 200), ["result", "content", Access.at(0), "text"])

    assert slot_text =~ "Morning Stats Slot"
    assert slot_text =~ "registered_attendees"
    assert slot_text =~ "workshop_count"
  end

  test "an unauthenticated tool call cannot read attendance stats" do
    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("accept", "application/json")
      |> post(~p"/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => %{"name" => "list_workshop_attendance", "arguments" => %{}}
      })

    response = json_response(conn, 200)
    refute get_in(response, ["result", "content", Access.at(0), "text"]) =~ "Stats Workshop"
  end
end
