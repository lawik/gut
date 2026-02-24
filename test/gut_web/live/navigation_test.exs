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
    test "does not see nav links on their landing page", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/my-travel")
      |> refute_has("a.btn-ghost", text: "Speakers")
      |> refute_has("a.btn-ghost", text: "Sponsors")
      |> refute_has("a.btn-ghost", text: "Users")
    end

    test "is redirected away from staff pages", %{conn: conn} do
      conn = log_in_as(conn, :speaker)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "My Travel Details")
    end
  end

  describe "sponsor-role user navigation" do
    test "does not see nav links on their landing page", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/my-sponsor")
      |> refute_has("a.btn-ghost", text: "Speakers")
      |> refute_has("a.btn-ghost", text: "Sponsors")
      |> refute_has("a.btn-ghost", text: "Users")
    end

    test "is redirected away from staff pages", %{conn: conn} do
      conn = log_in_as(conn, :sponsor)

      conn
      |> visit("/speakers")
      |> assert_has("h1", text: "Sponsor Portal")
    end
  end
end
