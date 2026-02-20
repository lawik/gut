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

        <div class="mt-12">
          <h2 class="text-xl font-semibold text-base-content mb-4 px-4 sm:px-6 lg:px-8 flex items-center">
            <.icon name="hero-envelope" class="h-5 w-5 mr-2 text-primary" /> Invites
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
                <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-success/10 text-success">
                  Accepted
                </span>
              <% else %>
                <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-warning/10 text-warning">
                  Pending
                </span>
              <% end %>
            </:col>

            <:col :let={invite} field="inserted_at" sort label="Sent">
              <span class="text-sm text-base-content/50">
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
                  class="text-primary hover:text-primary/80 text-sm font-medium"
                >
                  Get link
                </button>
                <button
                  phx-click="delete_invite"
                  phx-value-id={invite.id}
                  data-confirm="Delete this invite?"
                  class="text-error hover:text-error/80 text-sm font-medium"
                >
                  Delete
                </button>
              </div>
            </:col>
          </Cinder.Table.table>

          <div
            :if={@shown_link}
            class="mt-4 mx-4 sm:mx-6 lg:mx-8 p-4 bg-primary/10 border border-primary/30 rounded-lg"
          >
            <p class="text-sm font-medium text-primary mb-2">
              Magic link (valid for a few minutes):
            </p>
            <div class="flex items-center gap-2">
              <input
                type="text"
                readonly
                value={@shown_link}
                class="flex-1 text-xs font-mono bg-base-100 border border-primary/30 rounded px-3 py-2 text-base-content"
              />
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_badge_class(:staff), do: "bg-info/10 text-info"
  defp role_badge_class(:speaker), do: "bg-secondary/10 text-secondary"
  defp role_badge_class(:sponsor), do: "bg-warning/10 text-warning"
  defp role_badge_class(_), do: "bg-base-200 text-base-content/70"

  defp invite_type_class(:speaker), do: "bg-secondary/10 text-secondary"
  defp invite_type_class(:sponsor), do: "bg-warning/10 text-warning"
  defp invite_type_class(_), do: "bg-base-200 text-base-content/70"

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
