defmodule GutWeb.UsersLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
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
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title="Users">
      <div class="py-8">
        <div class="">
          <Cinder.Table.table
            id="users-table"
            resource={Gut.Accounts.User}
            actor={@current_user}
            url_state={@url_state}
            theme="daisy_ui"
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={fn user -> JS.navigate(~p"/users/#{user.id}") end}
          >
            <:col :let={user} field="email" filter sort label="Email">
              <div class="font-medium">{user.email}</div>
            </:col>

            <:col :let={user} field="id" sort label="ID">
              <div class="text-sm text-gray-500 font-mono">
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
                  class="text-red-600 hover:text-red-900 text-sm font-medium"
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

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Accounts.destroy_user!(id, actor: socket.assigns.current_user) do
      {:ok, _user} ->
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
