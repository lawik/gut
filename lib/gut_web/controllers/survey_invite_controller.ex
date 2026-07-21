defmodule GutWeb.SurveyInviteController do
  @moduledoc """
  Entry point for survey invitation emails.

  Stores the survey as the post-sign-in destination and forwards to the
  magic-link confirmation page, so the emailed auth link drops the attendee
  straight into the survey after signing in.
  """
  use GutWeb, :controller

  def show(conn, %{"id" => id} = params) do
    return_to = ~p"/surveys/#{id}/respond"

    cond do
      conn.assigns[:current_user] ->
        redirect(conn, to: return_to)

      token = params["token"] ->
        conn
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/survey_link/#{token}")

      true ->
        conn
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/sign-in")
    end
  end
end
