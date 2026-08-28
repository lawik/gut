defmodule GutWeb.BadgeLoginControllerTest do
  use GutWeb.ConnCase, async: true

  # These tests exercise the app's global BadgeAuth + TitoEmailCache
  # instances, so each test uses its own unique email address.
  defp unique_email, do: "holder-#{System.unique_integer([:positive])}@example.com"

  defp seed_holder(role) do
    email = unique_email()
    :ok = Gut.TitoEmailCache.put_email(email, role)
    email
  end

  defp auth_token_from_email(to) do
    assert_receive {:email, %Swoosh.Email{to: [{_, ^to}]} = email}
    [_, token] = Regex.run(~r{/badge_login/verify/([\w-]+)}, email.html_body)
    token
  end

  describe "POST /api/badge_login" do
    test "issues a request token and emails a ticket holder", %{conn: conn} do
      email = seed_holder(:presenter)

      conn = post(conn, ~p"/api/badge_login", %{"email" => email})

      assert %{"request_token" => request_token, "message" => _} = json_response(conn, 200)
      assert is_binary(request_token) and byte_size(request_token) >= 40
      assert auth_token_from_email(email)
    end

    test "issues a request token but sends no email for unknown emails", %{conn: conn} do
      conn = post(conn, ~p"/api/badge_login", %{"email" => unique_email()})

      assert %{"request_token" => _} = json_response(conn, 200)
      refute_receive {:email, _}, 50
    end

    test "rejects requests without a usable email", %{conn: conn} do
      assert post(conn, ~p"/api/badge_login", %{}) |> json_response(400)
      assert post(conn, ~p"/api/badge_login", %{"email" => "  "}) |> json_response(400)
    end
  end

  describe "GET /api/badge_login/:token" do
    test "full flow: pending, then verified after the email link is opened", %{conn: conn} do
      email = seed_holder(:attendee)

      %{"request_token" => request_token} =
        post(conn, ~p"/api/badge_login", %{"email" => email}) |> json_response(200)

      assert %{"status" => "pending"} =
               get(conn, ~p"/api/badge_login/#{request_token}") |> json_response(200)

      auth_token = auth_token_from_email(email)

      verify_conn = get(build_conn(), ~p"/badge_login/verify/#{auth_token}")
      assert html_response(verify_conn, 200) =~ "Check your device"

      assert %{"status" => "verified", "email" => ^email, "role" => "attendee"} =
               get(conn, ~p"/api/badge_login/#{request_token}") |> json_response(200)
    end

    test "long-polling returns once the login is verified", %{conn: conn} do
      email = seed_holder(:staff)

      %{"request_token" => request_token} =
        post(conn, ~p"/api/badge_login", %{"email" => email}) |> json_response(200)

      auth_token = auth_token_from_email(email)

      task =
        Task.async(fn ->
          get(build_conn(), ~p"/api/badge_login/#{request_token}?long=10")
        end)

      Process.sleep(100)
      get(build_conn(), ~p"/badge_login/verify/#{auth_token}")

      assert %{"status" => "verified", "role" => "staff"} =
               Task.await(task, 2_000) |> json_response(200)
    end

    test "?long with a bogus or zero value answers immediately", %{conn: conn} do
      email = seed_holder(:attendee)

      %{"request_token" => request_token} =
        post(conn, ~p"/api/badge_login", %{"email" => email}) |> json_response(200)

      assert %{"status" => "pending"} =
               get(conn, ~p"/api/badge_login/#{request_token}?long=nope") |> json_response(200)
    end

    test "unknown tokens return 404", %{conn: conn} do
      assert %{"status" => "unknown"} =
               get(conn, ~p"/api/badge_login/no-such-token") |> json_response(404)
    end
  end

  describe "GET /badge_login/verify/:token" do
    test "an invalid link renders the error page", %{conn: conn} do
      conn = get(conn, ~p"/badge_login/verify/bogus")
      assert html_response(conn, 404) =~ "invalid or has expired"
    end

    test "clicking the link twice still shows the success page", %{conn: conn} do
      email = seed_holder(:attendee)
      post(conn, ~p"/api/badge_login", %{"email" => email})
      auth_token = auth_token_from_email(email)

      assert get(build_conn(), ~p"/badge_login/verify/#{auth_token}")
             |> html_response(200) =~ "logged in"

      assert get(build_conn(), ~p"/badge_login/verify/#{auth_token}")
             |> html_response(200) =~ "logged in"
    end
  end
end
