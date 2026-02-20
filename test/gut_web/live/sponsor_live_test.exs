defmodule GutWeb.SponsorLiveTest do
  use GutWeb.FeatureCase

  describe "SponsorsLive (index)" do
    test "renders sponsors page", %{conn: conn} do
      conn
      |> visit("/sponsors")
      |> assert_has("a", text: "Sponsors")
    end

    test "renders table structure", %{conn: conn} do
      conn
      |> visit("/sponsors")
      |> assert_has("div", text: "Name")
      |> assert_has("div", text: "Status")
    end
  end

  describe "SponsorDetailLive (show)" do
    test "renders sponsor details", %{conn: conn} do
      sponsor = generate(sponsor(sponsorship_level: "Gold"))

      conn
      |> visit("/sponsors/#{sponsor.id}")
      |> assert_has("h1", text: "Acme Corp")
      |> assert_has("p", text: "Gold Sponsor")
      |> assert_has("h2", text: "Pipeline Progress")
      |> assert_has("a", text: "Edit Sponsor")
    end

    test "displays pipeline steps", %{conn: conn} do
      sponsor = generate(sponsor(responded: true, interested: true, confirmed: false))

      conn
      |> visit("/sponsors/#{sponsor.id}")
      |> assert_has("p", text: "Responded")
      |> assert_has("p", text: "Interested")
      |> assert_has("p", text: "Confirmed")
    end

    test "shows outreach section", %{conn: conn} do
      sponsor = generate(sponsor(outreach: "Contacted via email"))

      conn
      |> visit("/sponsors/#{sponsor.id}")
      |> assert_has("h2", text: "Outreach")
      |> assert_has("p", text: "Contacted via email")
    end

    test "navigates to edit form", %{conn: conn} do
      sponsor = generate(sponsor())

      conn
      |> visit("/sponsors/#{sponsor.id}/edit")
      |> assert_has("h1", text: "Editing Acme Corp")
    end
  end

  describe "SponsorFormLive (create)" do
    test "renders the new sponsor form", %{conn: conn} do
      conn
      |> visit("/sponsors/new")
      |> assert_has("h1", text: "Adding new sponsor")
      |> assert_has("label", text: "Sponsor Name")
      |> assert_has("label", text: "Sponsorship Level")
    end

    test "creates a sponsor with valid data", %{conn: conn} do
      conn
      |> visit("/sponsors/new")
      |> fill_in("Sponsor Name", with: "NewCo")
      |> click_button("Create Sponsor")
      |> assert_has("a", text: "Sponsors")
    end
  end

  describe "SponsorFormLive (edit)" do
    test "renders the edit form with existing data", %{conn: conn} do
      sponsor = generate(sponsor())

      conn
      |> visit("/sponsors/#{sponsor.id}/edit")
      |> assert_has("h1", text: "Editing Acme Corp")
    end

    test "updates a sponsor", %{conn: conn} do
      sponsor = generate(sponsor())

      conn
      |> visit("/sponsors/#{sponsor.id}/edit")
      |> fill_in("Sponsor Name", with: "Updated Corp")
      |> click_button("Update Sponsor")
      |> assert_has("a", text: "Sponsors")
    end
  end
end
