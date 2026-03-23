defmodule GutWeb.WorkshopDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshops:changed")
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_participations:changed")
    end

    workshop = load_workshop(id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, workshop.name)
      |> assign(:workshop, workshop)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  defp load_workshop(id, actor) do
    Gut.Conference.get_workshop!(id,
      actor: actor,
      load: [
        :workshop_room,
        :workshop_timeslot,
        :speakers,
        workshop_participations: [:workshop_participant]
      ]
    )
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/workshops"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Workshops
          </.link>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
          <div class="px-6 py-8 bg-base-200 border-b border-base-300">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-base-content">{@workshop.name}</h1>
                <%= if @workshop.description do %>
                  <p class="mt-2 text-base-content/60">{@workshop.description}</p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link patch={~p"/workshops/#{@workshop.id}/edit"} class="btn btn-primary">
                  Edit Workshop
                </.link>
              </div>
            </div>
          </div>

          <div class="px-6 py-8">
            <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-base-content mb-4">Details</h2>
                  <div class="bg-base-200 rounded-lg p-4 space-y-4">
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Participant Limit</dt>
                      <dd class="mt-1 text-sm font-medium text-base-content">{@workshop.limit}</dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Room</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <%= if @workshop.workshop_room do %>
                          {@workshop.workshop_room.name} (capacity: {@workshop.workshop_room.limit})
                        <% else %>
                          <span class="text-base-content/40">Not assigned</span>
                        <% end %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Timeslot</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <%= if @workshop.workshop_timeslot do %>
                          {@workshop.workshop_timeslot.name}
                          <span class="text-base-content/50">
                            ({Calendar.strftime(@workshop.workshop_timeslot.start, "%b %d %H:%M")} - {Calendar.strftime(
                              @workshop.workshop_timeslot.end,
                              "%H:%M"
                            )})
                          </span>
                        <% else %>
                          <span class="text-base-content/40">Not assigned</span>
                        <% end %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Registrations</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <% registered =
                          Enum.count(@workshop.workshop_participations, &(&1.status == :registered)) %>
                        <% waitlisted =
                          Enum.count(@workshop.workshop_participations, &(&1.status == :waitlisted)) %>
                        <% effective_limit = effective_limit(@workshop) %>
                        <span class="font-medium">{registered}/{effective_limit}</span>
                        registered
                        <%= if waitlisted > 0 do %>
                          , <span class="text-warning font-medium">{waitlisted}</span> waitlisted
                        <% end %>
                        <%= if waitlisted > 0 and registered < effective_limit do %>
                          <button
                            phx-click="promote_waitlist"
                            class="ml-2 btn btn-sm btn-warning"
                          >
                            Promote from waitlist
                          </button>
                        <% end %>
                      </dd>
                    </div>
                  </div>
                </div>

                <div>
                  <h2 class="text-xl font-semibold text-base-content mb-4">Speakers</h2>
                  <div class="bg-base-200 rounded-lg p-4">
                    <%= if @workshop.speakers != [] do %>
                      <ul class="space-y-2">
                        <li :for={speaker <- @workshop.speakers} class="text-sm text-base-content">
                          {speaker.full_name}
                        </li>
                      </ul>
                    <% else %>
                      <p class="text-sm text-base-content/40">No speakers assigned</p>
                    <% end %>
                  </div>
                </div>
              </div>

              <div>
                <h2 class="text-xl font-semibold text-base-content mb-4">Participants</h2>
                <div class="bg-base-200 rounded-lg p-4">
                  <%= if @workshop.workshop_participations != [] do %>
                    <ul class="space-y-2">
                      <li
                        :for={participation <- @workshop.workshop_participations}
                        class="flex items-center justify-between text-sm"
                      >
                        <span class="text-base-content">
                          {participation.workshop_participant.name}
                        </span>
                        <span class={[
                          "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
                          if(participation.status == :registered,
                            do: "bg-success/10 text-success",
                            else: "bg-warning/10 text-warning"
                          )
                        ]}>
                          {participation.status}
                        </span>
                      </li>
                    </ul>
                  <% else %>
                    <p class="text-sm text-base-content/40">No participants yet</p>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="mt-8 pt-8 border-t border-base-300">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Added to system</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@workshop.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Last updated</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@workshop.updated_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp effective_limit(workshop) do
    if workshop.workshop_room do
      min(workshop.limit, workshop.workshop_room.limit)
    else
      workshop.limit
    end
  end

  def handle_event("promote_waitlist", _params, socket) do
    case Gut.Conference.promote_waitlist(socket.assigns.workshop.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, 0} ->
        {:noreply, put_flash(socket, :info, "No participants to promote.")}

      {:ok, count} ->
        workshop = load_workshop(socket.assigns.workshop.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:workshop, workshop)
         |> put_flash(:info, "Promoted #{count} participant(s) from waitlist.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to promote waitlisted participants.")}
    end
  end

  def handle_info(%{topic: "workshops:changed"}, socket) do
    workshop = load_workshop(socket.assigns.workshop.id, socket.assigns.current_user)
    {:noreply, assign(socket, :workshop, workshop)}
  end

  def handle_info(%{topic: "workshop_participations:changed"}, socket) do
    workshop = load_workshop(socket.assigns.workshop.id, socket.assigns.current_user)
    {:noreply, assign(socket, :workshop, workshop)}
  end
end
