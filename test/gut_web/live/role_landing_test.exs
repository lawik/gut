defmodule GutWeb.RoleLandingTest do
  use GutWeb.FeatureCase

  defp create_speaker_for_user(user) do
    Gut.Conference.create_speaker!(
      %{first_name: "Ada", last_name: "Lovelace", full_name: "Ada Lovelace", user_id: user.id},
      authorize?: false
    )
  end

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
    test "speaker landing on / redirects to travel form" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker sees travel form with fields" do
      user = Gut.Accounts.create_user!("speaker-form@test.com", :speaker, authorize?: false)
      _speaker = create_speaker_for_user(user)
      conn = log_in_user(Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{}), user)

      conn
      |> visit("/my-travel")
      |> assert_has("h1", text: "My Travel Details")
      |> assert_has("label", text: "Arrival Date")
      |> assert_has("label", text: "Arrival Time")
      |> assert_has("label", text: "Departure Date")
      |> assert_has("label", text: "Departure Time")
      |> assert_has("button", text: "Save Travel Details")
    end

    test "speaker without profile sees friendly message" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/my-travel")
      |> assert_has("p", text: "No speaker profile is associated with your account")
    end

    test "speaker can submit travel details" do
      user = Gut.Accounts.create_user!("speaker-save@test.com", :speaker, authorize?: false)
      _speaker = create_speaker_for_user(user)
      conn = log_in_user(Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{}), user)

      conn
      |> visit("/my-travel")
      |> fill_in("Arrival Date", with: "2026-06-15")
      |> fill_in("Departure Date", with: "2026-06-18")
      |> click_button("Save Travel Details")
      |> assert_has("p", text: "Travel details saved successfully")
    end

    test "speaker navigating to /speakers is redirected to travel form" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker navigating to /sponsors is redirected to travel form" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/sponsors")
      |> assert_has("h1", text: "My Travel Details")
    end

    test "speaker navigating to /users is redirected to travel form" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/users")
      |> assert_has("h1", text: "My Travel Details")
    end
  end

  describe "sponsor landing" do
    test "sponsor landing on / redirects to sponsor portal" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor sees placeholder page" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/my-sponsor")
      |> assert_has("h1", text: "Sponsor Portal")
      |> assert_has("p", text: "More information coming soon")
    end

    test "sponsor navigating to /speakers is redirected to sponsor portal" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor navigating to /sponsors is redirected to sponsor portal" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/sponsors")
      |> assert_has("h1", text: "Sponsor Portal")
    end

    test "sponsor navigating to /users is redirected to sponsor portal" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/users")
      |> assert_has("h1", text: "Sponsor Portal")
    end
  end
end
