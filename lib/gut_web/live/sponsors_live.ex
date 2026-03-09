defmodule GutWeb.SponsorsLive do
  use GutWeb, :live_view
  use Cinder.Table.UrlSync

  require Ash.Query
  require Logger

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gut.PubSub, "sponsors:changed")

    socket =
      socket
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def handle_params(params, uri, socket) do
    params =
      params
      |> Map.put_new("sort", "-updated_at")
      |> Map.put_new("not_happening", "false")

    socket =
      Cinder.Table.UrlSync.handle_params(params, uri, socket)
      |> assign(:filter_params, params)
      |> assign(:pipeline_value, compute_pipeline_value(params, socket.assigns.current_user))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title="Sponsors"
    >
      <div class="">
        <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-4">
          <div class="text-sm text-base-content/70">
            Pipeline value:
            <span class="font-semibold text-base-content">
              EUR {format_number(@pipeline_value)}
            </span>
          </div>
          <.link
            navigate={~p"/sponsors/new"}
            class="btn btn-primary"
          >
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Add Sponsor
          </.link>
        </div>
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
                <span class="text-base-content/40">-</span>
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
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={sponsor} field="amount_eur" sort label="Amount (EUR)">
              <%= if sponsor.amount_eur do %>
                <span class="text-sm font-medium">EUR {format_number(sponsor.amount_eur)}</span>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={sponsor} field="likelihood" sort label="Likelihood">
              <%= if sponsor.likelihood do %>
                <span class="text-sm font-medium">{sponsor.likelihood}%</span>
              <% else %>
                <span class="text-base-content/40">-</span>
              <% end %>
            </:col>

            <:col :let={sponsor} field="logos_received" filter sort label="Logos">
              <.checkpoint_badge value={sponsor.logos_received} />
            </:col>

            <:col :let={sponsor} field="announced" filter sort label="Announced">
              <.checkpoint_badge value={sponsor.announced} />
            </:col>

            <:col :let={sponsor} field="not_happening" filter sort label="Not Happening">
              <.checkpoint_badge value={sponsor.not_happening} />
            </:col>

            <:col :let={sponsor} field="inserted_at" sort label="Added">
              <div class="text-sm text-base-content/50">
                {Calendar.strftime(sponsor.inserted_at, "%b %d, %Y")}
              </div>
            </:col>

            <:col :let={sponsor} field="updated_at" sort label="Updated">
              <div class="text-sm text-base-content/50">
                {Calendar.strftime(sponsor.updated_at, "%b %d, %Y")}
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

  defp status_badge_class(:cold), do: "bg-info/10 text-info"
  defp status_badge_class(:warm), do: "bg-warning/10 text-warning"
  defp status_badge_class(:ok), do: "bg-success/10 text-success"
  defp status_badge_class(:dismissed), do: "bg-base-200 text-base-content/50"
  defp status_badge_class(_), do: "bg-base-200 text-base-content/70"

  defp checkpoint_badge(assigns) do
    ~H"""
    <%= if @value do %>
      <span class="inline-flex items-center rounded-full bg-success/10 px-2 py-1 text-xs font-medium text-success">
        <.icon name="hero-check-mini" class="h-3 w-3 mr-0.5" /> Yes
      </span>
    <% else %>
      <span class="inline-flex items-center rounded-full bg-base-200 px-2 py-1 text-xs font-medium text-base-content/50">
        No
      </span>
    <% end %>
    """
  end

  def handle_info(%{topic: "sponsors:changed"}, socket) do
    pipeline_value =
      compute_pipeline_value(socket.assigns.filter_params, socket.assigns.current_user)

    socket =
      socket
      |> assign(:pipeline_value, pipeline_value)
      |> Cinder.Table.Refresh.refresh_table("sponsors-table")

    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Gut.Conference.destroy_sponsor(id, actor: socket.assigns.current_user) do
      :ok ->
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

  @boolean_filters ~w(responded interested confirmed logos_received announced not_happening)
  @status_values ~w(cold warm ok dismissed)

  defp compute_pipeline_value(params, actor) do
    query =
      Enum.reduce(params, Ash.Query.for_read(Gut.Conference.Sponsor, :read), fn
        {key, "true"}, query when key in @boolean_filters ->
          Ash.Query.filter(query, ^ref(key) == true)

        {key, "false"}, query when key in @boolean_filters ->
          Ash.Query.filter(query, ^ref(key) == false)

        {"status", value}, query when value in @status_values ->
          Ash.Query.filter(query, status == ^String.to_existing_atom(value))

        _, query ->
          query
      end)

    case Ash.read(query, actor: actor) do
      {:ok, sponsors} ->
        Enum.reduce(sponsors, 0, fn sponsor, acc ->
          amount = sponsor.amount_eur || 0
          likelihood = sponsor.likelihood || 0
          acc + div(amount * likelihood, 100)
        end)

      _ ->
        0
    end
  end

  defp ref(field_name) do
    Ash.Expr.ref(String.to_existing_atom(field_name))
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}/, "\\0 ")
    |> String.trim()
    |> String.reverse()
  end

  defp format_number(_), do: "0"
end
