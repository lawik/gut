defmodule GutWeb.SponsorDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    sponsor = Gut.Conference.get_sponsor!(id, actor: socket.assigns.current_user, load: [:user])

    invites =
      Gut.Accounts.list_invites_for_resource!(:sponsor, sponsor.id,
        actor: socket.assigns.current_user
      )

    socket =
      socket
      |> assign(:page_title, "Sponsor Details")
      |> assign(:sponsor, sponsor)
      |> assign(:invites, invites)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/sponsors"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Sponsors
          </.link>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 bg-base-200 border-b border-base-300">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-base-content">{@sponsor.name}</h1>
                <%= if @sponsor.sponsorship_level do %>
                  <p class="mt-2 text-lg text-base-content/60">
                    {@sponsor.sponsorship_level} Sponsor
                  </p>
                <% end %>
                <%= if @sponsor.user do %>
                  <p class="mt-1 text-sm text-base-content/50">
                    Associated with user account ({@sponsor.user.email})
                  </p>
                <% end %>
                <%= for invite <- @invites, not invite.accepted do %>
                  <p class="mt-1 text-sm text-base-content/50">
                    Pending invite sent to {invite.email}
                  </p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link
                  patch={~p"/sponsors/#{@sponsor.id}/edit"}
                  class="btn btn-primary"
                >
                  Edit Sponsor
                </.link>
              </div>
            </div>
          </div>
          
    <!-- Content -->
          <div class="px-6 py-8">
            <!-- Pipeline Progress -->
            <div class="mb-8">
              <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                <.icon name="hero-flag" class="h-5 w-5 mr-2 text-primary" /> Pipeline Progress
              </h2>
              <div class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
                <.pipeline_step label="Responded" value={@sponsor.responded} />
                <.pipeline_step label="Interested" value={@sponsor.interested} />
                <.pipeline_step label="Confirmed" value={@sponsor.confirmed} />
                <.pipeline_step label="Logos Received" value={@sponsor.logos_received} />
                <.pipeline_step label="Announced" value={@sponsor.announced} />
              </div>
            </div>

            <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
              <!-- Outreach Information -->
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                    <.icon name="hero-megaphone" class="h-5 w-5 mr-2 text-primary" /> Outreach
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4">
                    <%= if @sponsor.outreach do %>
                      <p class="text-sm text-base-content whitespace-pre-wrap">{@sponsor.outreach}</p>
                    <% else %>
                      <p class="text-sm text-base-content/40">No outreach information recorded</p>
                    <% end %>
                  </div>
                </div>
              </div>
              
    <!-- Sponsorship Details -->
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                    <.icon name="hero-currency-dollar" class="h-5 w-5 mr-2 text-primary" />
                    Sponsorship Details
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4 space-y-4">
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Sponsorship Level</dt>
                      <dd class="mt-1">
                        <%= if @sponsor.sponsorship_level do %>
                          <span class="text-sm font-medium text-base-content">
                            {@sponsor.sponsorship_level}
                          </span>
                        <% else %>
                          <span class="text-sm text-base-content/40">Not set</span>
                        <% end %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Status</dt>
                      <dd class="mt-1">
                        <%= cond do %>
                          <% @sponsor.confirmed -> %>
                            <span class="inline-flex items-center rounded-full bg-success/10 px-2.5 py-0.5 text-xs font-medium text-success">
                              Confirmed
                            </span>
                          <% @sponsor.interested -> %>
                            <span class="inline-flex items-center rounded-full bg-info/10 px-2.5 py-0.5 text-xs font-medium text-info">
                              Interested
                            </span>
                          <% @sponsor.responded -> %>
                            <span class="inline-flex items-center rounded-full bg-warning/10 px-2.5 py-0.5 text-xs font-medium text-warning">
                              In Contact
                            </span>
                          <% true -> %>
                            <span class="inline-flex items-center rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium text-base-content/70">
                              Outreach Pending
                            </span>
                        <% end %>
                      </dd>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Metadata -->
            <div class="mt-8 pt-8 border-t border-base-300">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Added to system</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@sponsor.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Last updated</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@sponsor.updated_at, "%B %d, %Y at %I:%M %p")}
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

  defp pipeline_step(assigns) do
    ~H"""
    <div class={[
      "rounded-lg p-3 text-center border",
      if(@value, do: "bg-success/10 border-success/30", else: "bg-base-200 border-base-300")
    ]}>
      <%= if @value do %>
        <.icon name="hero-check-circle" class="h-6 w-6 text-success mx-auto" />
      <% else %>
        <.icon name="hero-x-circle" class="h-6 w-6 text-base-content/30 mx-auto" />
      <% end %>
      <p class={[
        "text-xs font-medium mt-1",
        if(@value, do: "text-success", else: "text-base-content/50")
      ]}>
        {@label}
      </p>
    </div>
    """
  end
end
