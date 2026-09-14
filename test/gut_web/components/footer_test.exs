defmodule GutWeb.FooterTest do
  @moduledoc "The footer offers a Log out link to signed-in users only."
  use GutWeb.FeatureCase

  import Phoenix.ConnTest, only: [delete: 2, redirected_to: 1]

  test "signed-in users get a Log out link in the footer", %{conn: conn} do
    conn
    |> visit("/workshops/browse")
    |> assert_has("footer #footer-log-out", text: "Log out")
    |> assert_has("footer", text: "staff@test.com")
  end

  test "signed-out visitors get no footer", %{pid: pid} do
    build_unauthenticated_conn(pid)
    |> visit("/workshops/browse")
    |> refute_has("footer")
  end

  test "following the link signs the user out", %{conn: conn} do
    conn = delete(conn, "/sign-out")

    assert redirected_to(conn) == "/"
    refute Plug.Conn.get_session(conn, "user_token")
  end
end
