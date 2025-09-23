defmodule GutWeb.PageController do
  use GutWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
