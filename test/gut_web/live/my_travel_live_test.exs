defmodule GutWeb.MyTravelLiveTest do
  use GutWeb.FeatureCase

  import Ecto.Query, only: [from: 2]

  @system_actor Gut.system_actor("test")

  defp build_speaker(conn) do
    user = generate(user(role: :speaker))

    speaker =
      generate(
        speaker(
          first_name: "Grace",
          last_name: "Hopper",
          full_name: "Grace Hopper",
          user_id: user.id
        )
      )

    conn = log_in_user(conn, user)
    {conn, user, speaker}
  end

  defp approve!(speaker) do
    speaker_id = speaker.id

    {1, _} =
      Gut.Repo.update_all(
        from(s in "speakers", where: s.id == type(^speaker_id, :binary_id)),
        set: [contract_approved_at: DateTime.utc_now(), contract_approved_git_sha: "test-sha"]
      )

    Ash.get!(Gut.Conference.Speaker, speaker_id, actor: @system_actor)
  end

  defp force_change!(speaker, attrs) do
    speaker_id = speaker.id

    {1, _} =
      Gut.Repo.update_all(
        from(s in "speakers", where: s.id == type(^speaker_id, :binary_id)),
        set: attrs
      )

    Ash.get!(Gut.Conference.Speaker, speaker_id, actor: @system_actor)
  end

  describe "agreement rendering and name injection" do
    test "substitutes FIRSTNAME / LASTNAME with the speaker's real name", %{conn: conn} do
      {conn, _user, _speaker} = build_speaker(conn)

      conn
      |> visit("/my-travel")
      |> assert_has("strong", text: "Grace Hopper")
      |> refute_has("article", text: "FIRSTNAME")
      |> refute_has("article", text: "LASTNAME")
    end

    test "renders core agreement clauses", %{conn: conn} do
      {conn, _user, _speaker} = build_speaker(conn)

      conn
      |> visit("/my-travel")
      |> assert_has("h1", text: "Goatmire Elixir 2026")
      |> assert_has("h3", text: "1. Parties")
      |> assert_has("h3", text: "3. Financial Arrangements")
      |> assert_has("strong", text: "three nights")
      |> assert_has("p", text: "1500 SEK per night")
    end

    test "missing speaker profile is reported gracefully", %{conn: conn} do
      user = generate(user(role: :speaker))
      conn = log_in_user(conn, user)

      conn
      |> visit("/my-travel")
      |> assert_has("p", text: "No speaker profile is associated with your account.")
    end
  end

  describe "phase 1: contract not approved" do
    test "shows approval-required state and locks the later sections", %{conn: conn} do
      {conn, _user, _speaker} = build_speaker(conn)

      conn
      |> visit("/my-travel")
      |> assert_has("span", text: "Approval required")
      |> assert_has("button", text: "I approve the agreement")
      |> assert_has("span", text: "Locked until agreement approved", count: 2)
    end
  end

  describe "phase 2: approving the contract" do
    test "click records timestamp and revision, then unlocks form", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)

      conn
      |> visit("/my-travel")
      |> click_button("I approve the agreement")
      |> assert_has("span", text: "Approved")
      |> refute_has("span", text: "Locked until agreement approved")
      |> refute_has("button", text: "I approve the agreement")

      reloaded = Ash.get!(Gut.Conference.Speaker, speaker.id, actor: @system_actor)
      assert %DateTime{} = reloaded.contract_approved_at
      assert is_binary(reloaded.contract_approved_git_sha)
      assert reloaded.contract_approved_git_sha != ""
    end
  end

  describe "phase 3: travel form" do
    test "saves arrival and departure details", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Arrival Date", with: "2026-09-29")
      |> fill_in("Arrival Time", with: "18:30")
      |> fill_in("Departure Date", with: "2026-10-03")
      |> fill_in("Departure Time", with: "10:00")
      |> click_button("Save Travel Details")
      |> assert_has("p", text: "Travel details saved")

      reloaded = Ash.get!(Gut.Conference.Speaker, speaker.id, actor: @system_actor)
      assert reloaded.arrival_date == ~D[2026-09-29]
      assert reloaded.arrival_time == ~T[18:30:00]
      assert reloaded.leaving_date == ~D[2026-10-03]
      assert reloaded.leaving_time == ~T[10:00:00]
    end
  end

  describe "phase 4: hotel booking calculations" do
    test "stay equal to the default coverage produces a zero estimate", %{conn: conn} do
      # 30 Sep -> 3 Oct = 3 nights. Default days_covered = 3.
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-09-30")
      |> fill_in("Check-out", with: "2026-10-03")
      |> assert_has("span", text: "Estimated bill")
      |> assert_has("span", text: "0 SEK")
    end

    test "uncovered nights are billed at 1500 SEK each", %{conn: conn} do
      # 28 Sep -> 3 Oct = 5 nights. Covered 3, uncovered 2 -> 3000 SEK.
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-09-28")
      |> fill_in("Check-out", with: "2026-10-03")
      |> assert_has("span", text: "3000 SEK")
    end

    test "plus one adds 200 SEK per night across the whole stay", %{conn: conn} do
      # 5 nights, 2 uncovered. Base 2*1500 = 3000. Plus one 5*200 = 1000. Total 4000.
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-09-28")
      |> fill_in("Check-out", with: "2026-10-03")
      |> check("I am bringing a plus one")
      |> assert_has("span", text: "1000 SEK")
      |> assert_has("span", text: "4000 SEK")
    end

    test "fully-covered speaker (custom days_covered) sees a zero estimate", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)
      speaker = approve!(speaker)
      _ = force_change!(speaker, days_covered: 6)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-09-28")
      |> fill_in("Check-out", with: "2026-10-03")
      |> assert_has("strong", text: "6 nights")
      |> assert_has("span", text: "0 SEK")
    end

    test "invalid date range surfaces an error message", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-10-03")
      |> fill_in("Check-out", with: "2026-09-30")
      |> assert_has("p", text: "Check-out must be after check-in.")
    end

    test "pre-fills the recommended check-in / check-out by default", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> assert_has("input[name='form[hotel_stay_start_date]'][value='2026-09-27']")
      |> assert_has("input[name='form[hotel_stay_end_date]'][value='2026-10-04']")
    end

    test "saves the hotel booking request", %{conn: conn} do
      {conn, _user, speaker} = build_speaker(conn)
      _ = approve!(speaker)

      conn
      |> visit("/my-travel")
      |> fill_in("Check-in", with: "2026-09-26")
      |> fill_in("Check-out", with: "2026-10-05")
      |> check("I am bringing a plus one")
      |> fill_in("Special note for the organizer", with: "Vegetarian please")
      |> click_button("Save Hotel Request")
      |> assert_has("p", text: "Hotel request saved")

      reloaded = Ash.get!(Gut.Conference.Speaker, speaker.id, actor: @system_actor)
      assert reloaded.hotel_stay_start_date == ~D[2026-09-26]
      assert reloaded.hotel_stay_end_date == ~D[2026-10-05]
      assert reloaded.plus_one == true
      assert reloaded.special_requests == "Vegetarian please"
    end
  end
end
