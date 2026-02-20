defmodule GutWeb.UserDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    user = Gut.Accounts.get_user!(id, actor: socket.assigns.current_user)
    actor = socket.assigns.current_user
    is_staff = actor.role == :staff

    api_keys =
      if is_staff and user.role == :staff do
        Gut.Accounts.list_api_keys_for_user!(user.id, actor: actor)
      else
        []
      end

    socket =
      socket
      |> assign(:page_title, "User: #{user.email}")
      |> assign(:user, user)
      |> assign(:is_staff, is_staff)
      |> assign(:api_keys, api_keys)
      |> assign(:new_api_key, nil)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/users"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Users
          </.link>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
          <div class="px-6 py-8 bg-base-200 border-b border-base-300">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-base-content">{@user.email}</h1>
                <p class="mt-2 text-sm text-base-content/60">
                  Role: <span class="font-medium">{@user.role}</span>
                </p>
              </div>
              <div class="flex space-x-3">
                <.link
                  navigate={~p"/users/#{@user.id}/edit"}
                  class="btn btn-primary"
                >
                  Edit User
                </.link>
              </div>
            </div>
          </div>

          <div class="px-6 py-8"></div>
        </div>

        <div :if={@is_staff and @user.role == :staff} class="mt-8">
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-base-300 flex items-center justify-between">
              <h2 class="text-xl font-semibold text-base-content flex items-center">
                <.icon name="hero-key" class="h-5 w-5 mr-2 text-primary" /> API Keys
              </h2>
              <button
                phx-click="create_api_key"
                class="btn btn-primary btn-sm"
              >
                Generate Key
              </button>
            </div>

            <div :if={@new_api_key} class="px-6 py-4 bg-success/10 border-b border-success/30">
              <p class="text-sm font-medium text-success mb-2">
                New API key created. Copy it now — it won't be shown again.
              </p>
              <input
                type="text"
                readonly
                value={@new_api_key}
                onclick="this.select()"
                class="block w-full p-3 bg-base-100 rounded border border-success/30 text-sm font-mono"
              />
            </div>

            <div class="px-6 py-4">
              <div :if={@api_keys == []} class="text-sm text-base-content/50 py-4 text-center">
                No API keys yet.
              </div>

              <table :if={@api_keys != []} class="min-w-full divide-y divide-base-300">
                <thead>
                  <tr>
                    <th class="py-3 text-left text-xs font-medium text-base-content/50 uppercase">
                      ID
                    </th>
                    <th class="py-3 text-left text-xs font-medium text-base-content/50 uppercase">
                      Created
                    </th>
                    <th class="py-3 text-left text-xs font-medium text-base-content/50 uppercase">
                      Expires
                    </th>
                    <th class="py-3 text-right text-xs font-medium text-base-content/50 uppercase">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base-300">
                  <tr :for={key <- @api_keys}>
                    <td class="py-3 text-sm text-base-content/50 font-mono">
                      {String.slice(key.id, 0..7)}...
                    </td>
                    <td class="py-3 text-sm text-base-content">
                      {Calendar.strftime(key.inserted_at, "%B %d, %Y")}
                    </td>
                    <td class="py-3 text-sm text-base-content">
                      {Calendar.strftime(key.expires_at, "%B %d, %Y")}
                    </td>
                    <td class="py-3 text-right">
                      <button
                        phx-click="revoke_api_key"
                        phx-value-id={key.id}
                        data-confirm="Are you sure you want to revoke this API key?"
                        class="text-sm text-error hover:text-error/80 font-medium"
                      >
                        Revoke
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("create_api_key", _params, socket) do
    actor = socket.assigns.current_user
    user = socket.assigns.user
    expires_at = DateTime.add(DateTime.utc_now(), 365, :day)

    case Gut.Accounts.create_api_key(%{user_id: user.id, expires_at: expires_at}, actor: actor) do
      {:ok, api_key} ->
        api_keys = Gut.Accounts.list_api_keys_for_user!(user.id, actor: actor)

        socket =
          socket
          |> assign(:api_keys, api_keys)
          |> assign(:new_api_key, api_key.__metadata__.plaintext_api_key)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create API key")}
    end
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    user = socket.assigns.user

    api_key =
      socket.assigns.api_keys
      |> Enum.find(&(&1.id == id))

    if api_key do
      Gut.Accounts.destroy_api_key!(api_key, actor: actor)

      api_keys = Gut.Accounts.list_api_keys_for_user!(user.id, actor: actor)

      socket =
        socket
        |> assign(:api_keys, api_keys)
        |> assign(:new_api_key, nil)
        |> put_flash(:info, "API key revoked")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "API key not found")}
    end
  end
end
