defmodule GutWeb.PageController do
  use GutWeb, :controller

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      %{role: :speaker} -> redirect(conn, to: ~p"/my-travel")
      %{role: :sponsor} -> redirect(conn, to: ~p"/my-sponsor")
      %{role: _} -> redirect(conn, to: ~p"/speakers")
      nil -> render(conn, :home)
    end
  end
end
