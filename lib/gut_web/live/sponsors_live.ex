defmodule GutWeb.SponsorsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gut.PubSub, "sponsors:changed")

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
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title="Sponsors">
      <div class="">
        <div class="">
          <Cinder.Table.table
            id="sponsors-table"
            resource={Gut.Conference.Sponsor}
            actor={@current_user}
            url_state={@url_state}
            theme={GutWeb.CinderTheme}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            row_click={fn sponsor -> JS.navigate(~p"/sponsors/#{sponsor.id}") end}
          >
            <:col :let={sponsor} field="name" filter sort label="Name">
              <div class="font-medium">{sponsor.name}</div>
            </:col>

            <:col :let={sponsor} field="status" filter sort label="Status">
              <span class={[
                "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
                status_badge_class(sponsor.status)
              ]}>
                {sponsor.status}
              </span>
            </:col>

            <:col :let={sponsor} field="outreach" filter label="Outreach">
              <%= if sponsor.outreach do %>
                <div class="text-sm max-w-xs truncate">{sponsor.outreach}</div>
              <% else %>
                <span class="text-gray-400">-</span>
              <% end %>
            </:col>

            <:col :let={sponsor} field="responded" filter sort label="Responded">
              <.checkpoint_badge value={sponsor.responded} />
            </:col>

            <:col :let={sponsor} field="interested" filter sort label="Interested">
              <.checkpoint_badge value={sponsor.interested} />
            </:col>

            <:col :let={sponsor} field="confirmed" filter sort label="Confirmed">
              <.checkpoint_badge value={sponsor.confirmed} />
            </:col>

            <:col :let={sponsor} field="sponsorship_level" filter sort label="Level">
              <%= if sponsor.sponsorship_level do %>
                <span class="text-sm font-medium">{sponsor.sponsorship_level}</span>
              <% else %>
                <span class="text-gray-400">-</span>
              <% end %>
            </:col>

            <:col :let={sponsor} field="logos_received" filter sort label="Logos">
              <.checkpoint_badge value={sponsor.logos_received} />
            </:col>

            <:col :let={sponsor} field="announced" filter sort label="Announced">
              <.checkpoint_badge value={sponsor.announced} />
            </:col>

            <:col :let={sponsor} field="inserted_at" sort label="Added">
              <div class="text-sm text-gray-500">
                {Calendar.strftime(sponsor.inserted_at, "%b %d, %Y")}
              </div>
            </:col>

            <:col :let={sponsor} label="Actions">
              <div class="flex space-x-2">
                <.link
                  patch={~p"/sponsors/#{sponsor.id}/edit"}
                  class="text-sm font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={sponsor.id}
                  data-confirm="Are you sure you want to delete this sponsor?"
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

  defp status_badge_class(:cold), do: "bg-blue-100 text-blue-700"
  defp status_badge_class(:warm), do: "bg-orange-100 text-orange-700"
  defp status_badge_class(:ok), do: "bg-green-100 text-green-700"
  defp status_badge_class(:dismissed), do: "bg-gray-100 text-gray-500"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-700"

  defp checkpoint_badge(assigns) do
    ~H"""
    <%= if @value do %>
      <span class="inline-flex items-center rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-700">
        <.icon name="hero-check-mini" class="h-3 w-3 mr-0.5" /> Yes
      </span>
    <% else %>
      <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-500">
        No
      </span>
    <% end %>
    """
  end

  def handle_info(%{topic: "sponsors:changed"}, socket) do
    {:noreply, Cinder.Table.Refresh.refresh_table(socket, "sponsors-table")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_sponsor(id, actor: socket.assigns.current_user) do
      {:ok, _sponsor} ->
        socket =
          socket
          |> put_flash(:info, "Sponsor deleted successfully")
          |> Cinder.Table.Refresh.refresh_table("sponsors-table")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete sponsor #{id}: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete sponsor")}
    end
  end
end
