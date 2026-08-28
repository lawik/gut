defmodule GutWeb.BadgeVerifyController do
  @moduledoc """
  Landing page for the badge-login confirmation link sent over email.

  Deliberately requires no login and never signs the visitor into Gut —
  it only marks the badge *device* login as verified.
  """

  use GutWeb, :controller

  def show(conn, %{"token" => token}) do
    case Gut.BadgeAuth.verify(token) do
      {:ok, _info} ->
        render(conn, :show, verified?: true)

      :error ->
        conn
        |> put_status(:not_found)
        |> render(:show, verified?: false)
    end
  end
end
