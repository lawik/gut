defmodule GutWeb.SpeakerLiveTest do
  use GutWeb.FeatureCase

  describe "SpeakersLive (index)" do
    test "renders speakers page", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("button", text: "Sync from Sessionize")
      |> assert_has("a", text: "Add Speaker")
    end

    test "renders table structure", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("div", text: "Full Name")
      |> assert_has("div", text: "First Name")
    end

    test "navigates to new speaker form", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> click_link("Add Speaker")
      |> assert_has("h1", text: "Adding new speaker")
    end
  end

  describe "SpeakerDetailLive (show)" do
    test "renders speaker details", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h1", text: "Ada Lovelace")
      |> assert_has("a", text: "Edit Speaker")
      |> assert_has("a", text: "Back to Speakers")
    end

    test "shows travel information when set", %{conn: conn} do
      speaker =
        generate(
          speaker(
            arrival_date: ~D[2026-06-15],
            leaving_date: ~D[2026-06-18]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h2", text: "Travel Information")
      |> assert_has("dt", text: "Arrival")
      |> assert_has("dt", text: "Departure")
      |> assert_has("div", text: "2026-06-15")
      |> assert_has("div", text: "2026-06-18")
    end

    test "shows hotel information when set", %{conn: conn} do
      speaker =
        generate(
          speaker(
            hotel_stay_start_date: ~D[2026-06-14],
            hotel_stay_end_date: ~D[2026-06-18],
            hotel_covered_start_date: ~D[2026-06-14],
            hotel_covered_end_date: ~D[2026-06-18]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h2", text: "Hotel Information")
      |> assert_has("p", text: "Full Coverage")
    end

    test "navigates to edit form", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> assert_has("h1", text: "Editing Ada Lovelace")
    end
  end

  describe "SpeakerFormLive (create)" do
    test "renders the new speaker form", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> assert_has("h1", text: "Adding new speaker")
      |> assert_has("label", text: "Full Name")
      |> assert_has("label", text: "First Name")
      |> assert_has("label", text: "Last Name")
    end

    test "creates a speaker with valid data", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> fill_in("Full Name", with: "Grace Hopper")
      |> fill_in("First Name", with: "Grace")
      |> fill_in("Last Name", with: "Hopper")
      |> click_button("Create Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end
  end

  describe "SpeakerFormLive (edit)" do
    test "renders the edit form with existing data", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> assert_has("h1", text: "Editing Ada Lovelace")
    end

    test "updates a speaker", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> fill_in("Full Name", with: "Ada Updated")
      |> click_button("Update Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end
  end
end
