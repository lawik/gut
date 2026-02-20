defmodule GutWeb.NavigationTest do
  use GutWeb.FeatureCase

  describe "staff user sees all navigation" do
    test "sees nav links on speakers page", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("a.btn-ghost", text: "Speakers")
      |> assert_has("a.btn-ghost", text: "Sponsors")
      |> assert_has("a.btn-ghost", text: "Users")
    end
  end

  describe "speaker-role user navigation" do
    test "does not see nav links" do
      conn = log_in_as(:speaker)

      conn
      |> visit("/speakers")
      |> refute_has("a.btn-ghost", text: "Speakers")
      |> refute_has("a.btn-ghost", text: "Sponsors")
      |> refute_has("a.btn-ghost", text: "Users")
    end
  end

  describe "sponsor-role user navigation" do
    test "does not see nav links" do
      conn = log_in_as(:sponsor)

      conn
      |> visit("/speakers")
      |> refute_has("a.btn-ghost", text: "Speakers")
      |> refute_has("a.btn-ghost", text: "Sponsors")
      |> refute_has("a.btn-ghost", text: "Users")
    end
  end
end
