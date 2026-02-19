defmodule GutWeb.UsersLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "users:changed")
      Phoenix.PubSub.subscribe(Gut.PubSub, "invites:changed")
    end

    socket =
      socket
      |> assign(:current_scope, nil)
      |> assign(:shown_link, nil)

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

        <div class="mt-12">
          <h2 class="text-xl font-semibold text-gray-900 mb-4 px-4 sm:px-6 lg:px-8 flex items-center">
            <.icon name="hero-envelope" class="h-5 w-5 mr-2 text-indigo-600" /> Invites
          </h2>
          <Cinder.Table.table
            id="invites-table"
            resource={Gut.Accounts.Invite}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50]]}
          >
            <:col :let={invite} field="email" filter sort label="Email">
              <div class="font-medium">{invite.email}</div>
            </:col>

            <:col :let={invite} field="resource_type" filter sort label="Type">
              <span class={[
                "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
                invite_type_class(invite.resource_type)
              ]}>
                {invite.resource_type}
              </span>
            </:col>

            <:col :let={invite} field="accepted" filter sort label="Status">
              <%= if invite.accepted do %>
                <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-green-100 text-green-700">
                  Accepted
                </span>
              <% else %>
                <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700">
                  Pending
                </span>
              <% end %>
            </:col>

            <:col :let={invite} field="inserted_at" sort label="Sent">
              <span class="text-sm text-gray-500">
                {Calendar.strftime(invite.inserted_at, "%b %d, %Y")}
              </span>
            </:col>

            <:col :let={invite} label="Actions">
              <div class="flex items-center gap-2">
                <button
                  :if={not invite.accepted}
                  phx-click="get_link"
                  phx-value-id={invite.id}
                  phx-value-email={invite.email}
                  class="text-indigo-600 hover:text-indigo-900 text-sm font-medium"
                >
                  Get link
                </button>
                <button
                  phx-click="delete_invite"
                  phx-value-id={invite.id}
                  data-confirm="Delete this invite?"
                  class="text-red-600 hover:text-red-900 text-sm font-medium"
                >
                  Delete
                </button>
              </div>
            </:col>
          </Cinder.Table.table>

          <div
            :if={@shown_link}
            class="mt-4 mx-4 sm:mx-6 lg:mx-8 p-4 bg-indigo-50 border border-indigo-200 rounded-lg"
          >
            <p class="text-sm font-medium text-indigo-900 mb-2">
              Magic link (valid for a few minutes):
            </p>
            <div class="flex items-center gap-2">
              <input
                type="text"
                readonly
                value={@shown_link}
                class="flex-1 text-xs font-mono bg-white border border-indigo-300 rounded px-3 py-2 text-gray-700"
              />
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_badge_class(:staff), do: "bg-blue-100 text-blue-700"
  defp role_badge_class(:speaker), do: "bg-purple-100 text-purple-700"
  defp role_badge_class(:sponsor), do: "bg-amber-100 text-amber-700"
  defp role_badge_class(_), do: "bg-gray-100 text-gray-700"

  defp invite_type_class(:speaker), do: "bg-purple-100 text-purple-700"
  defp invite_type_class(:sponsor), do: "bg-amber-100 text-amber-700"
  defp invite_type_class(_), do: "bg-gray-100 text-gray-700"

  def handle_info(%{topic: "users:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "users-table")}
  end

  def handle_info(%{topic: "invites:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "invites-table")}
  end

  def handle_event("get_link", %{"email" => email}, socket) do
    case Gut.Accounts.magic_link_url(email) do
      {:ok, url} ->
        {:noreply, assign(socket, :shown_link, url)}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not generate link")}
    end
  end

  def handle_event("delete_invite", %{"id" => id}, socket) do
    invite =
      Gut.Accounts.Invite
      |> Ash.get!(id, actor: socket.assigns.current_user)

    Gut.Accounts.destroy_invite!(invite, actor: socket.assigns.current_user)

    socket =
      socket
      |> assign(:shown_link, nil)
      |> Cinder.Table.Refresh.refresh_table("invites-table")

    {:noreply, socket}
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
