defmodule GutWeb.WorkshopParticipantsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_participants:changed")
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_participations:changed")
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
      page_title="Workshop Participants"
    >
      <Layouts.workshop_subnav active="participants" />
      <div class="mt-4">
        <div class="">
          <Cinder.Table.table
            id="workshop-participants-table"
            query={
              Gut.Conference.WorkshopParticipant
              |> Ash.Query.load(workshop_participations: [:workshop])
            }
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={
              fn participant -> JS.navigate(~p"/workshop-participants/#{participant.id}") end
            }
          >
            <:col :let={participant} field="name" filter sort label="Name">
              <div class="font-medium">{participant.name}</div>
            </:col>

            <:col :let={participant} field="phone_number" filter label="Phone">
              <%= if participant.phone_number do %>
                <span class="text-sm">{participant.phone_number}</span>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={participant} label="Workshops">
              <%= if participant.workshop_participations != [] do %>
                <table class="min-w-full text-sm">
                  <tbody>
                    <tr
                      :for={participation <- participant.workshop_participations}
                      class="border-b border-base-200 last:border-0"
                    >
                      <td class="py-1 pr-3">{participation.workshop.name}</td>
                      <td class="py-1 pr-3">
                        <span class={[
                          "inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium",
                          if(participation.status == :registered,
                            do: "bg-success/10 text-success",
                            else: "bg-warning/10 text-warning"
                          )
                        ]}>
                          {participation.status}
                        </span>
                      </td>
                      <td class="py-1">
                        <button
                          phx-click="remove_participation"
                          phx-value-id={participation.id}
                          data-confirm="Remove this workshop registration?"
                          class="text-error hover:text-error/80 text-xs font-medium"
                        >
                          Remove
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              <% else %>
                <span class="text-base-content/40 text-sm">None</span>
              <% end %>
            </:col>

            <:col :let={participant} field="inserted_at" sort label="Added">
              <div class="text-sm text-base-content/50">
                {Calendar.strftime(participant.inserted_at, "%b %d, %Y")}
              </div>
            </:col>

            <:col :let={participant} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/workshop-participants/#{participant.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={participant.id}
                  data-confirm="Are you sure you want to delete this participant and all their registrations?"
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

  def handle_info(%{topic: "workshop_participants:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "workshop-participants-table")}
  end

  def handle_info(%{topic: "workshop_participations:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "workshop-participants-table")}
  end

  def handle_event("remove_participation", %{"id" => id}, socket) do
    case Gut.Conference.destroy_workshop_participation(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Workshop registration removed")
          |> Cinder.Table.Refresh.refresh_table("workshop-participants-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to remove workshop participation #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to remove registration")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_workshop_participant(id, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Participant deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("workshop-participants-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete workshop participant #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete participant")}
    end
  end
end
