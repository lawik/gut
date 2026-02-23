defmodule GutWeb.UsersLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "users:changed")
    end

    socket =
      socket
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title="Users"
    >
      <div class="">
        <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-4">
          <div></div>
          <.link
            navigate={~p"/users/new"}
            class="btn btn-primary"
          >
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Add User
          </.link>
        </div>
        <div class="">
          <Cinder.Table.table
            id="users-table"
            resource={Gut.Accounts.User}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={fn user -> JS.navigate(~p"/users/#{user.id}") end}
          >
            <:col :let={user} field="email" filter sort label="Email">
              <div class="font-medium">{user.email}</div>
            </:col>

            <:col :let={user} field="role" filter sort label="Role">
              <span class={[
                "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
                role_badge_class(user.role)
              ]}>
                {user.role}
              </span>
            </:col>

            <:col :let={user} field="id" sort label="ID">
              <div class="text-sm text-base-content/50 font-mono">
                {String.slice(user.id, 0, 8)}...
              </div>
            </:col>

            <:col :let={user} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/users/#{user.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={user.id}
                  data-confirm="Are you sure you want to delete this user?"
                  class="text-error hover:text-error/80 text-sm font-medium"
                >
                  Delete
                </button>
              </div>
            </:col>
          </Cinder.Table.table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_badge_class(:staff), do: "bg-info/10 text-info"
  defp role_badge_class(:speaker), do: "bg-secondary/10 text-secondary"
  defp role_badge_class(:sponsor), do: "bg-warning/10 text-warning"
  defp role_badge_class(_), do: "bg-base-200 text-base-content/70"

  def handle_info(%{topic: "users:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "users-table")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Accounts.destroy_user(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "User deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("users-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete user #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end
end
