defmodule GutWeb.EmailLinkController do
  @moduledoc """
  Entry points for links in the emails we send (survey invites, workshop
  blasts, status mailings).

  Each action stores its page as the post-sign-in destination and forwards
  to the magic-link confirmation page, so the emailed auth link drops the
  recipient straight onto that page after signing in. Recipients who are
  already signed in go there directly.
  """
  use GutWeb, :controller

  def survey(conn, %{"id" => id} = params) do
    forward_to(conn, ~p"/surveys/#{id}/respond", params)
  end

  def blast(conn, %{"id" => id} = params) do
    forward_to(conn, ~p"/blasts/#{id}", params)
  end

  def browse(conn, params) do
    forward_to(conn, ~p"/workshops/browse", params)
  end

  defp forward_to(conn, return_to, params) do
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
