defmodule GutWeb.WorkshopParticipantDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    participant =
      Gut.Conference.get_workshop_participant!(id,
        actor: socket.assigns.current_user,
        load: [:user, workshop_participations: [:workshop]]
      )

    socket =
      socket
      |> assign(:page_title, participant.name)
      |> assign(:participant, participant)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/workshop-participants"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Participants
          </.link>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
          <div class="px-6 py-8 bg-base-200 border-b border-base-300">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-base-content">{@participant.name}</h1>
                <%= if @participant.user do %>
                  <p class="mt-1 text-sm text-base-content/50">
                    {@participant.user.email}
                  </p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link
                  patch={~p"/workshop-participants/#{@participant.id}/edit"}
                  class="btn btn-primary"
                >
                  Edit Participant
                </.link>
              </div>
            </div>
          </div>

          <div class="px-6 py-8">
            <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
              <div>
                <h2 class="text-xl font-semibold text-base-content mb-4">Details</h2>
                <div class="bg-base-200 rounded-lg p-4 space-y-4">
                  <div>
                    <dt class="text-sm font-medium text-base-content/50">Phone Number</dt>
                    <dd class="mt-1 text-sm text-base-content">
                      <%= if @participant.phone_number do %>
                        {@participant.phone_number}
                      <% else %>
                        <span class="text-base-content/40">Not provided</span>
                      <% end %>
                    </dd>
                  </div>
                </div>
              </div>

              <div>
                <h2 class="text-xl font-semibold text-base-content mb-4">Workshops</h2>
                <div class="bg-base-200 rounded-lg p-4">
                  <%= if @participant.workshop_participations != [] do %>
                    <ul class="space-y-2">
                      <li
                        :for={participation <- @participant.workshop_participations}
                        class="flex items-center justify-between text-sm"
                      >
                        <.link
                          navigate={~p"/workshops/#{participation.workshop.id}"}
                          class="text-primary hover:text-primary/80"
                        >
                          {participation.workshop.name}
                        </.link>
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
                    <p class="text-sm text-base-content/40">Not registered for any workshops</p>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="mt-8 pt-8 border-t border-base-300">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Added to system</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@participant.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Last updated</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@participant.updated_at, "%B %d, %Y at %I:%M %p")}
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
end
