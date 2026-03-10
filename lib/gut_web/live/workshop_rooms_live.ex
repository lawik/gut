defmodule GutWeb.WorkshopRoomsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_rooms:changed")

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
      page_title="Workshop Rooms"
    >
      <Layouts.workshop_subnav active="rooms" />
      <div class="mt-4">
        <div class="">
          <Cinder.Table.table
            id="workshop-rooms-table"
            resource={Gut.Conference.WorkshopRoom}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
          >
            <:col :let={room} field="name" filter sort label="Name">
              <div class="font-medium">{room.name}</div>
            </:col>

            <:col :let={room} field="limit" sort label="Capacity">
              <span class="text-sm">{room.limit}</span>
            </:col>

            <:col :let={room} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/workshop-rooms/#{room.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={room.id}
                  data-confirm="Are you sure you want to delete this room?"
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

  def handle_info(%{topic: "workshop_rooms:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "workshop-rooms-table")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_workshop_room(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Room deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("workshop-rooms-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete workshop room #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete room")}
    end
  end
end
