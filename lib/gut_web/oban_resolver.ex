defmodule GutWeb.ObanResolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_user(conn) do
    conn.assigns[:current_user]
  end

  @impl true
  def resolve_access(user) do
    case user do
      %{role: :staff} -> :all
      _ -> {:forbidden, "/sign-in"}
    end
  end
end
