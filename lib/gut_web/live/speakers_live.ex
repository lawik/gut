defmodule GutWeb.SpeakersLive do
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
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title="Speakers">
      <div class="py-8">
        <div class="sm:flex sm:items-center">
          <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
            <.link
              patch={~p"/speakers/new"}
              class="block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              Add Speaker
            </.link>
          </div>
        </div>

        <div class="mt-8">
          <Cinder.Table.table
            id="speakers-table"
            resource={Gut.Conference.Speaker}
            actor={@current_user}
            url_state={@url_state}
            theme="daisy_ui"
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={fn speaker -> JS.navigate(~p"/speakers/#{speaker.id}") end}
          >
            <:col :let={speaker} field="full_name" filter sort label="Full Name">
              <div class="font-medium">{speaker.full_name}</div>
            </:col>

            <:col :let={speaker} field="first_name" filter sort label="First Name">
              {speaker.first_name}
            </:col>

            <:col :let={speaker} field="last_name" filter sort label="Last Name">
              {speaker.last_name}
            </:col>

            <:col :let={speaker} field="arrival_date" filter sort label="Arrival">
              <%= if speaker.arrival_date do %>
                <div class="text-sm">
                  <div class="font-medium">{Date.to_string(speaker.arrival_date)}</div>
                  <%= if speaker.arrival_time do %>
                    <div class="text-gray-500">{Time.to_string(speaker.arrival_time)}</div>
                  <% end %>
                </div>
              <% else %>
                <span class="text-gray-400">Not set</span>
              <% end %>
            </:col>

            <:col :let={speaker} field="leaving_date" filter sort label="Departure">
              <%= if speaker.leaving_date do %>
                <div class="text-sm">
                  <div class="font-medium">{Date.to_string(speaker.leaving_date)}</div>
                  <%= if speaker.leaving_time do %>
                    <div class="text-gray-500">{Time.to_string(speaker.leaving_time)}</div>
                  <% end %>
                </div>
              <% else %>
                <span class="text-gray-400">Not set</span>
              <% end %>
            </:col>

            <:col :let={speaker} field="hotel_stay_start_date" filter label="Hotel Stay">
              <%= if not is_nil(speaker.hotel_stay_start_date) and not is_nil(speaker.hotel_stay_end_date) do %>
                <div class="text-sm">
                  <div>{Date.to_string(speaker.hotel_stay_start_date)}</div>
                  <div class="text-gray-500">to {Date.to_string(speaker.hotel_stay_end_date)}</div>
                </div>
              <% else %>
                <span class="text-gray-400">Not set</span>
              <% end %>
            </:col>

            <:col :let={speaker} field="hotel_covered_start_date" filter label="Hotel Coverage">
              <%= if not is_nil(speaker.hotel_covered_start_date) and not is_nil(speaker.hotel_covered_end_date) do %>
                <div class="text-sm">
                  <div class="text-green-600">{Date.to_string(speaker.hotel_covered_start_date)}</div>
                  <div class="text-green-500">
                    to {Date.to_string(speaker.hotel_covered_end_date)}
                  </div>
                </div>
              <% else %>
                <span class="text-gray-400">Not covered</span>
              <% end %>
            </:col>

            <:col :let={speaker} field="inserted_at" sort label="Added">
              <div class="text-sm text-gray-500">
                {Calendar.strftime(speaker.inserted_at, "%b %d, %Y")}
              </div>
            </:col>

            <:col :let={speaker} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/speakers/#{speaker.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={speaker.id}
                  data-confirm="Are you sure you want to delete this speaker?"
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
    case Gut.Conference.destroy_speaker(id, actor: socket.assigns.current_user) do
      {:ok, _speaker} ->
        socket =
          socket
          |> put_flash(:info, "Speaker deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("speakers-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete speaker #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete speaker")}
    end
  end
end
