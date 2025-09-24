defmodule GutWeb.PageController do
  use GutWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/speakers")
    else
      render(conn, :home)
    end
  end
end
