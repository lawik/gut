defmodule GutWeb.WorkshopsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gut.PubSub, "workshops:changed")

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
      page_title="Workshops"
    >
      <Layouts.workshop_subnav active="workshops" />
      <div class="mt-4">
        <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-4">
          <button
            phx-click="sync_sessionize"
            phx-disable-with="Syncing..."
            class="btn btn-ghost"
          >
            <.icon name="hero-arrow-path" class="h-4 w-4 mr-2" /> Sync from Sessionize
          </button>
        </div>
        <div class="">
          <Cinder.Table.table
            id="workshops-table"
            query={Ash.Query.for_read(Gut.Conference.Workshop, :list)}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={fn workshop -> JS.navigate(~p"/workshops/#{workshop.id}") end}
          >
            <:col :let={workshop} field="name" filter sort label="Name">
              <div class="font-medium">{workshop.name}</div>
            </:col>

            <:col :let={workshop} field="description" label="Description">
              <%= if workshop.description do %>
                <div class="text-sm max-w-xs truncate">{workshop.description}</div>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={workshop} field="limit" sort label="Limit">
              <span class="text-sm">{workshop.limit}</span>
            </:col>

            <:col :let={workshop} field="workshop_room_id" label="Room">
              <%= if Ash.Resource.loaded?(workshop, :workshop_room) && workshop.workshop_room do %>
                <span class="text-sm">{workshop.workshop_room.name}</span>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={workshop} field="workshop_timeslot_id" label="Timeslot">
              <%= if Ash.Resource.loaded?(workshop, :workshop_timeslot) && workshop.workshop_timeslot do %>
                <span class="text-sm">{workshop.workshop_timeslot.name}</span>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={workshop} field="inserted_at" sort label="Added">
              <div class="text-sm text-base-content/50">
                {Calendar.strftime(workshop.inserted_at, "%b %d, %Y")}
              </div>
            </:col>

            <:col :let={workshop} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/workshops/#{workshop.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={workshop.id}
                  data-confirm="Are you sure you want to delete this workshop?"
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

  def handle_info(%{topic: "workshops:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "workshops-table")}
  end

  def handle_event("sync_sessionize", _params, socket) do
    case Gut.Conference.SessionizeSync.sync(socket.assigns.current_user) do
      {:ok, %{workshops_synced: workshops_synced}} ->
        socket =
          socket
          |> put_flash(:info, "Sessionize sync complete: #{workshops_synced} workshops synced")
          |> Cinder.Table.Refresh.refresh_table("workshops-table")

        {:noreply, socket}

      {:error, :not_configured} ->
        {:noreply, put_flash(socket, :error, "Sessionize URLs not configured")}

      {:error, reason} ->
        Logger.error("Sessionize sync failed: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Sessionize sync failed")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_workshop(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Workshop deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("workshops-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete workshop #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete workshop")}
    end
  end
end
