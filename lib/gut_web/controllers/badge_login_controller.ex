defmodule GutWeb.BadgeLoginController do
  @moduledoc """
  JSON API for badge hardware devices to authenticate via ticket-holder
  email. This never signs a user into Gut — it only logs in the device.

  POST /api/badge_login             {"email": "..."} -> {"request_token": ...}
  GET  /api/badge_login/:token      poll the login status
  GET  /api/badge_login/:token?long=30  long-poll up to 30 (max 60) seconds
  """

  use GutWeb, :controller

  def create(conn, %{"email" => email}) when is_binary(email) do
    if String.trim(email) == "" do
      bad_request(conn)
    else
      {:ok, request_token} = Gut.BadgeAuth.start_login(email)

      json(conn, %{
        request_token: request_token,
        message: "Check your email for a confirmation link."
      })
    end
  end

  def create(conn, _params), do: bad_request(conn)

  def status(conn, %{"token" => token} = params) do
    result =
      case long_seconds(params) do
        0 -> Gut.BadgeAuth.status(token)
        seconds -> Gut.BadgeAuth.await(token, seconds * 1000)
      end

    case result do
      :unknown ->
        conn |> put_status(:not_found) |> json(%{status: "unknown"})

      :pending ->
        json(conn, %{status: "pending"})

      {:verified, %{email: email, role: role}} ->
        json(conn, %{status: "verified", email: email, role: role})
    end
  end

  defp long_seconds(params) do
    case Integer.parse(to_string(params["long"] || "")) do
      {n, ""} when n > 0 -> min(n, 60)
      _ -> 0
    end
  end

  defp bad_request(conn) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "a JSON body with an \"email\" field is required"})
  end
end
