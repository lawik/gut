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

    test "renders amount and likelihood fields", %{conn: conn} do
      conn
      |> visit("/sponsors/new")
      |> assert_has("label", text: "Amount (EUR)")
      |> assert_has("label", text: "Likelihood (%)")
    end

    test "creates a sponsor with valid data", %{conn: conn} do
      conn
      |> visit("/sponsors/new")
      |> fill_in("Sponsor Name", with: "NewCo")
      |> click_button("Create Sponsor")
      |> assert_has("a", text: "Sponsors")
    end

    test "creates a sponsor with amount and likelihood", %{conn: conn} do
      conn
      |> visit("/sponsors/new")
      |> fill_in("Sponsor Name", with: "BigCo")
      |> fill_in("Amount (EUR)", with: "5000")
      |> fill_in("Likelihood (%)", with: "80")
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

    test "updates a sponsor with amount and likelihood", %{conn: conn} do
      sponsor = generate(sponsor())

      conn
      |> visit("/sponsors/#{sponsor.id}/edit")
      |> fill_in("Amount (EUR)", with: "10000")
      |> fill_in("Likelihood (%)", with: "50")
      |> click_button("Update Sponsor")
      |> assert_has("a", text: "Sponsors")
    end
  end

  describe "SponsorsLive (pipeline value)" do
    test "shows pipeline value on sponsors list", %{conn: conn} do
      conn
      |> visit("/sponsors")
      |> assert_has("div", text: "Pipeline value:")
    end

    test "calculates pipeline value from sponsors", %{conn: conn} do
      # 10000 * 80 / 100 = 8000
      generate(sponsor(name: "Sponsor A", amount_eur: 10_000, likelihood: 80))
      # 5000 * 60 / 100 = 3000
      generate(sponsor(name: "Sponsor B", amount_eur: 5_000, likelihood: 60))
      # Total: 11000

      conn
      |> visit("/sponsors")
      |> assert_has("span", text: "EUR 11 000")
    end

    test "not_happening sponsors excluded by default filter", %{conn: conn} do
      generate(sponsor(name: "Active Sponsor", amount_eur: 10_000, likelihood: 100))

      generate(
        sponsor(name: "Dead Sponsor", amount_eur: 20_000, likelihood: 100, not_happening: true)
      )

      # Default filter is not_happening=false, so only Active Sponsor counts
      # 10000 * 100 / 100 = 10000
      conn
      |> visit("/sponsors")
      |> assert_has("span", text: "EUR 10 000")
    end

    test "sponsors with nil amount or likelihood contribute zero", %{conn: conn} do
      generate(sponsor(name: "No Amount", amount_eur: nil, likelihood: 50))
      generate(sponsor(name: "No Likelihood", amount_eur: 5_000, likelihood: nil))
      generate(sponsor(name: "Has Both", amount_eur: 10_000, likelihood: 100))

      # Only "Has Both" contributes: 10000 * 100 / 100 = 10000
      conn
      |> visit("/sponsors")
      |> assert_has("span", text: "EUR 10 000")
    end
  end
end
