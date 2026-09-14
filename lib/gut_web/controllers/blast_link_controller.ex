defmodule GutWeb.BlastLinkController do
  @moduledoc """
  Entry point for workshop blast emails.

  Stores the blast page as the post-sign-in destination and forwards to the
  magic-link confirmation page, so the emailed auth link drops the attendee
  straight onto the blast after signing in.
  """
  use GutWeb, :controller

  def show(conn, %{"id" => id} = params) do
    return_to = ~p"/blasts/#{id}"

    cond do
      conn.assigns[:current_user] ->
        redirect(conn, to: return_to)

      token = params["token"] ->
        conn
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/magic_link/#{token}")

      true ->
        conn
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/sign-in")
    end
  end
end
