defmodule GutWeb.RoleLandingTest do
  use GutWeb.FeatureCase

  describe "staff landing" do
    test "staff user landing on / redirects to speakers list", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("button", text: "Sync from Sessionize")
    end

    test "staff can access /speakers directly", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("button", text: "Sync from Sessionize")
    end
  end

  describe "speaker landing" do
    test "speaker landing on / redirects to travel form", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker sees travel form with fields", %{conn: conn} do
      user = generate(user(email: "speaker-form@test.com", role: :speaker))
      _speaker = generate(speaker(user_id: user.id))
      conn = log_in_user(conn, user)

      conn
      |> visit("/my-travel")
      |> assert_has("h1", text: "My Travel Details")
      |> assert_has("label", text: "Arrival Date")
      |> assert_has("label", text: "Arrival Time")
      |> assert_has("label", text: "Departure Date")
      |> assert_has("label", text: "Departure Time")
      |> assert_has("button", text: "Save Travel Details")
    end

    test "speaker without profile sees friendly message", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/my-travel")
      |> assert_has("p", text: "No speaker profile is associated with your account")
    end

    test "speaker can submit travel details", %{conn: conn} do
      user = generate(user(email: "speaker-save@test.com", role: :speaker))
      _speaker = generate(speaker(user_id: user.id))
      conn = log_in_user(conn, user)

      conn
      |> visit("/my-travel")
      |> fill_in("Arrival Date", with: "2026-06-15")
      |> fill_in("Departure Date", with: "2026-06-18")
      |> click_button("Save Travel Details")
      |> assert_has("p", text: "Travel details saved successfully")
    end

    test "speaker navigating to /speakers is redirected to travel form", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker navigating to /sponsors is redirected to travel form", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/sponsors")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker navigating to /users is redirected to travel form", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/users")
      |> assert_has("h1", text: "My Travel Details")
    end
  end

  describe "sponsor landing" do
    test "sponsor landing on / redirects to sponsor portal", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor sees placeholder page", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/my-sponsor")
      |> assert_has("h1", text: "Sponsor Portal")
      |> assert_has("p", text: "More information coming soon")
    end

    test "sponsor navigating to /speakers is redirected to sponsor portal", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor navigating to /sponsors is redirected to sponsor portal", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/sponsors")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor navigating to /users is redirected to sponsor portal", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/users")
      |> assert_has("h1", text: "Sponsor Portal")
    end
  end
end
