defmodule GutWeb.WorkshopTimeslotsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_timeslots:changed")

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
      page_title="Workshop Timeslots"
    >
      <Layouts.workshop_subnav active="timeslots" />
      <div class="mt-4">
        <div class="">
          <Cinder.Table.table
            id="workshop-timeslots-table"
            resource={Gut.Conference.WorkshopTimeslot}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
          >
            <:col :let={slot} field="name" filter sort label="Name">
              <div class="font-medium">{slot.name}</div>
            </:col>

            <:col :let={slot} field="start" sort label="Start">
              <span class="text-sm">{Calendar.strftime(slot.start, "%b %d, %Y %H:%M")}</span>
            </:col>

            <:col :let={slot} field="end" sort label="End">
              <span class="text-sm">{Calendar.strftime(slot.end, "%b %d, %Y %H:%M")}</span>
            </:col>

            <:col :let={slot} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/workshop-timeslots/#{slot.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={slot.id}
                  data-confirm="Are you sure you want to delete this timeslot?"
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

  def handle_info(%{topic: "workshop_timeslots:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "workshop-timeslots-table")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_workshop_timeslot(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Timeslot deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("workshop-timeslots-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete workshop timeslot #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete timeslot")}
    end
  end
end
