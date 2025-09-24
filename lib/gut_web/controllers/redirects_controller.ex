defmodule GutWeb.Redirects do
  use GutWeb, :controller

  def to_sign_in(conn, _params) do
    redirect(conn, to: ~p"/sign-in")
  end
end
