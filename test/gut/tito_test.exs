defmodule Gut.TitoTest do
  use ExUnit.Case, async: true

  defp ticket(attrs) do
    Map.merge(
      %{
        "email" => "attendee@example.com",
        "state" => "complete",
        "void" => false,
        "test_mode" => false
      },
      attrs
    )
  end

  defp stub_tickets(tickets) do
    Req.Test.stub(Gut.Tito, fn conn ->
      # This module is strictly read-only against Tito.
      assert conn.method == "GET"
      assert conn.request_path == "/v3/goatmire/elixir-2026/tickets"
      Req.Test.json(conn, %{"tickets" => tickets})
    end)
  end

  describe "valid_ticket?/1" do
    test "true when a complete ticket is assigned to the email" do
      stub_tickets([ticket(%{"email" => "attendee@example.com"})])
      assert {:ok, true} = Gut.Tito.valid_ticket?("attendee@example.com")
    end

    test "matches email case-insensitively and trims whitespace" do
      stub_tickets([ticket(%{"email" => "Attendee@Example.com"})])
      assert {:ok, true} = Gut.Tito.valid_ticket?("  attendee@EXAMPLE.com ")
    end

    test "false when no returned ticket matches the email exactly" do
      stub_tickets([ticket(%{"email" => "other@example.com"})])
      assert {:ok, false} = Gut.Tito.valid_ticket?("attendee@example.com")
    end

    test "false for void, test-mode, or non-complete tickets" do
      stub_tickets([
        ticket(%{"void" => true}),
        ticket(%{"test_mode" => true}),
        ticket(%{"state" => "unassigned", "email" => nil})
      ])

      assert {:ok, false} = Gut.Tito.valid_ticket?("attendee@example.com")
    end

    test "does not call the API for a blank email" do
      # No stub installed: a request would raise.
      assert {:ok, false} = Gut.Tito.valid_ticket?("   ")
    end

    test "returns an error on non-200 responses" do
      Req.Test.stub(Gut.Tito, fn conn ->
        Plug.Conn.send_resp(conn, 500, "oops")
      end)

      assert {:error, {:http_status, 500}} = Gut.Tito.valid_ticket?("attendee@example.com")
    end
  end

  describe "tickets_for_email/1" do
    test "returns only tickets whose email matches exactly" do
      stub_tickets([
        ticket(%{"email" => "attendee@example.com", "reference" => "AAA-1"}),
        ticket(%{"email" => "attendee@example.com.au", "reference" => "BBB-1"})
      ])

      assert {:ok, [%{"reference" => "AAA-1"}]} =
               Gut.Tito.tickets_for_email("attendee@example.com")
    end
  end
end
