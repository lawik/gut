defmodule GutWeb.CsvExportTest do
  use GutWeb.FeatureCase

  @endpoint GutWeb.Endpoint
  import Phoenix.ConnTest, only: [get: 2]

  describe "speakers CSV" do
    test "exports all speakers", %{conn: conn} do
      generate(speaker(full_name: "Alice Smith", first_name: "Alice", last_name: "Smith"))
      generate(speaker(full_name: "Bob Jones", first_name: "Bob", last_name: "Jones"))

      resp = get(conn, "/export/speakers")

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "content-type") |> hd() =~ "text/csv"
      assert Plug.Conn.get_resp_header(resp, "content-disposition") |> hd() =~ "speakers.csv"
      assert resp.resp_body =~ "Full Name"
      assert resp.resp_body =~ "Alice Smith"
      assert resp.resp_body =~ "Bob Jones"
    end

    test "exports all speakers regardless of default page size", %{conn: conn} do
      for i <- 1..30 do
        generate(
          speaker(full_name: "Speaker #{i}", first_name: "First#{i}", last_name: "Last#{i}")
        )
      end

      resp = get(conn, "/export/speakers")

      assert resp.status == 200

      for i <- 1..30 do
        assert resp.resp_body =~ "Speaker #{i},"
      end
    end

    test "includes all CSV headers", %{conn: conn} do
      resp = get(conn, "/export/speakers")

      assert resp.status == 200

      for header <- [
            "Full Name",
            "First Name",
            "Last Name",
            "Arrival Date",
            "Arrival Time",
            "Leaving Date",
            "Leaving Time",
            "Hotel Stay Start",
            "Hotel Stay End",
            "Hotel Covered Start",
            "Hotel Covered End",
            "Room Number",
            "Hotel Status",
            "Sharing With",
            "Wants Early Check-in",
            "Double Bed",
            "Special Requests",
            "Notes"
          ] do
        assert resp.resp_body =~ header
      end
    end

    test "exports speaker field values", %{conn: conn} do
      generate(
        speaker(
          full_name: "Grace Hopper",
          first_name: "Grace",
          last_name: "Hopper",
          arrival_date: ~D[2026-06-15],
          room_number: "305",
          confirmed_with_hotel: :confirmed,
          wants_early_checkin: true,
          notes: "VIP speaker"
        )
      )

      resp = get(conn, "/export/speakers")

      assert resp.resp_body =~ "Grace Hopper"
      assert resp.resp_body =~ "2026-06-15"
      assert resp.resp_body =~ "305"
      assert resp.resp_body =~ "confirmed"
      assert resp.resp_body =~ "VIP speaker"
    end

    test "filters by full_name", %{conn: conn} do
      generate(speaker(full_name: "Alice Smith", first_name: "Alice", last_name: "Smith"))
      generate(speaker(full_name: "Bob Jones", first_name: "Bob", last_name: "Jones"))

      resp = get(conn, "/export/speakers?full_name=Alice")

      assert resp.status == 200
      assert resp.resp_body =~ "Alice Smith"
      refute resp.resp_body =~ "Bob Jones"
    end

    test "text filter is case-insensitive", %{conn: conn} do
      generate(speaker(full_name: "Alice Smith", first_name: "Alice", last_name: "Smith"))
      generate(speaker(full_name: "Bob Smithson", first_name: "Bob", last_name: "Smithson"))
      generate(speaker(full_name: "Charlie Brown", first_name: "Charlie", last_name: "Brown"))

      resp = get(conn, "/export/speakers?last_name=smith")

      assert resp.status == 200
      assert resp.resp_body =~ "Alice Smith"
      assert resp.resp_body =~ "Bob Smithson"
      refute resp.resp_body =~ "Charlie Brown"
    end

    test "filters by confirmed_with_hotel", %{conn: conn} do
      generate(
        speaker(
          full_name: "Confirmed Speaker",
          first_name: "C",
          last_name: "S",
          confirmed_with_hotel: :confirmed
        )
      )

      generate(
        speaker(
          full_name: "Unconfirmed Speaker",
          first_name: "U",
          last_name: "S",
          confirmed_with_hotel: :unconfirmed
        )
      )

      resp = get(conn, "/export/speakers?confirmed_with_hotel=confirmed")

      assert resp.resp_body =~ "Confirmed Speaker"
      refute resp.resp_body =~ "Unconfirmed Speaker"
    end

    test "respects sort parameter", %{conn: conn} do
      generate(speaker(full_name: "Zelda Last", first_name: "Zelda", last_name: "Last"))
      generate(speaker(full_name: "Alice First", first_name: "Alice", last_name: "First"))

      resp = get(conn, "/export/speakers?sort=full_name")

      assert resp.status == 200
      # Alice should appear before Zelda in ascending sort
      alice_pos = :binary.match(resp.resp_body, "Alice First") |> elem(0)
      zelda_pos = :binary.match(resp.resp_body, "Zelda Last") |> elem(0)
      assert alice_pos < zelda_pos
    end
  end

  describe "workshops CSV" do
    setup do
      room_a = generate(workshop_room(name: "Main Hall"))
      room_b = generate(workshop_room(name: "Room B"))
      timeslot = generate(workshop_timeslot(name: "Morning"))
      %{room_a: room_a, room_b: room_b, timeslot: timeslot}
    end

    test "exports all workshops", %{
      conn: conn,
      room_a: room_a,
      room_b: room_b,
      timeslot: timeslot
    } do
      generate(
        workshop(
          name: "Elixir 101",
          workshop_room_id: room_a.id,
          workshop_timeslot_id: timeslot.id
        )
      )

      generate(
        workshop(
          name: "Phoenix Deep Dive",
          workshop_room_id: room_b.id,
          workshop_timeslot_id: timeslot.id
        )
      )

      resp = get(conn, "/export/workshops")

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "content-type") |> hd() =~ "text/csv"
      assert Plug.Conn.get_resp_header(resp, "content-disposition") |> hd() =~ "workshops.csv"
      assert resp.resp_body =~ "Elixir 101"
      assert resp.resp_body =~ "Phoenix Deep Dive"
    end

    test "includes all CSV headers", %{conn: conn} do
      resp = get(conn, "/export/workshops")

      for header <- [
            "Name",
            "Description",
            "Limit",
            "Registered",
            "Waitlisted",
            "Room",
            "Timeslot"
          ] do
        assert resp.resp_body =~ header
      end
    end

    test "includes room and timeslot names", %{conn: conn, room_a: room_a, timeslot: timeslot} do
      generate(
        workshop(
          name: "Elixir 101",
          workshop_room_id: room_a.id,
          workshop_timeslot_id: timeslot.id
        )
      )

      resp = get(conn, "/export/workshops")

      assert resp.resp_body =~ "Main Hall"
      assert resp.resp_body =~ "Morning"
    end

    test "filters by name", %{conn: conn, room_a: room_a, room_b: room_b, timeslot: timeslot} do
      generate(
        workshop(
          name: "Elixir 101",
          workshop_room_id: room_a.id,
          workshop_timeslot_id: timeslot.id
        )
      )

      generate(
        workshop(
          name: "Phoenix Deep Dive",
          workshop_room_id: room_b.id,
          workshop_timeslot_id: timeslot.id
        )
      )

      resp = get(conn, "/export/workshops?name=Elixir")

      assert resp.resp_body =~ "Elixir 101"
      refute resp.resp_body =~ "Phoenix Deep Dive"
    end
  end

  describe "sponsors CSV" do
    test "exports all sponsors", %{conn: conn} do
      generate(sponsor(name: "Acme Corp"))
      generate(sponsor(name: "BigCo"))

      resp = get(conn, "/export/sponsors")

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "content-type") |> hd() =~ "text/csv"
      assert Plug.Conn.get_resp_header(resp, "content-disposition") |> hd() =~ "sponsors.csv"
      assert resp.resp_body =~ "Acme Corp"
      assert resp.resp_body =~ "BigCo"
    end

    test "includes all CSV headers", %{conn: conn} do
      resp = get(conn, "/export/sponsors")

      for header <- [
            "Name",
            "Status",
            "Outreach",
            "Responded",
            "Interested",
            "Confirmed",
            "Sponsorship Level",
            "Amount (EUR)",
            "Likelihood",
            "Logos Received",
            "Announced",
            "Not Happening"
          ] do
        assert resp.resp_body =~ header
      end
    end

    test "exports sponsor field values", %{conn: conn} do
      generate(
        sponsor(
          name: "Gold Sponsor",
          status: :warm,
          amount_eur: 5000,
          likelihood: 80,
          responded: true,
          interested: true,
          sponsorship_level: "Gold"
        )
      )

      resp = get(conn, "/export/sponsors")

      assert resp.resp_body =~ "Gold Sponsor"
      assert resp.resp_body =~ "warm"
      assert resp.resp_body =~ "5000"
      assert resp.resp_body =~ "80"
      assert resp.resp_body =~ "Gold"
    end

    test "filters by name", %{conn: conn} do
      generate(sponsor(name: "Acme Corp"))
      generate(sponsor(name: "BigCo"))

      resp = get(conn, "/export/sponsors?name=Acme")

      assert resp.resp_body =~ "Acme Corp"
      refute resp.resp_body =~ "BigCo"
    end

    test "filters by status", %{conn: conn} do
      generate(sponsor(name: "Warm Lead", status: :warm))
      generate(sponsor(name: "Cold Lead", status: :cold))

      resp = get(conn, "/export/sponsors?status=warm")

      assert resp.resp_body =~ "Warm Lead"
      refute resp.resp_body =~ "Cold Lead"
    end

    test "filters by boolean fields", %{conn: conn} do
      generate(sponsor(name: "Confirmed Corp", confirmed: true))
      generate(sponsor(name: "Pending Corp", confirmed: false))

      resp = get(conn, "/export/sponsors?confirmed=true")

      assert resp.resp_body =~ "Confirmed Corp"
      refute resp.resp_body =~ "Pending Corp"
    end

    test "combines multiple filters", %{conn: conn} do
      generate(sponsor(name: "Target", status: :warm, confirmed: true))
      generate(sponsor(name: "Wrong Status", status: :cold, confirmed: true))
      generate(sponsor(name: "Not Confirmed", status: :warm, confirmed: false))

      resp = get(conn, "/export/sponsors?status=warm&confirmed=true")

      assert resp.resp_body =~ "Target"
      refute resp.resp_body =~ "Wrong Status"
      refute resp.resp_body =~ "Not Confirmed"
    end
  end

  describe "export link has download attribute" do
    test "speakers export link has download attribute", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("a[download]", text: "Export CSV")
    end

    test "workshops export link has download attribute", %{conn: conn} do
      conn
      |> visit("/workshops")
      |> assert_has("a[download]", text: "Export CSV")
    end

    test "sponsors export link has download attribute", %{conn: conn} do
      conn
      |> visit("/sponsors")
      |> assert_has("a[download]", text: "Export CSV")
    end

    test "speakers export link preserves current filters", %{conn: conn} do
      conn
      |> visit("/speakers?full_name=Alice")
      |> assert_has("a[download][href*='full_name=Alice']", text: "Export CSV")
    end

    test "sponsors export link preserves current filters", %{conn: conn} do
      conn
      |> visit("/sponsors?status=warm")
      |> assert_has("a[download][href*='status=warm']", text: "Export CSV")
    end
  end

  describe "authentication" do
    test "returns 403 for unauthenticated users", %{pid: pid} do
      conn = build_unauthenticated_conn(pid)

      resp = get(conn, "/export/speakers")

      assert resp.status == 403
    end

    test "returns 403 for non-staff users", %{conn: conn} do
      conn = log_in_as(conn, :attendee)

      resp = get(conn, "/export/speakers")

      assert resp.status == 403
    end
  end
end
