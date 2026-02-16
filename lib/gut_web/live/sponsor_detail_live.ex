defmodule GutWeb.SponsorDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    sponsor = Gut.Conference.get_sponsor!(id, actor: socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Sponsor Details")
      |> assign(:sponsor, sponsor)
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
            class="inline-flex items-center text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Sponsors
          </.link>
        </div>

        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 rounded-xl overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 bg-gradient-to-r from-indigo-50 to-purple-50 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-gray-900">{@sponsor.name}</h1>
                <%= if @sponsor.sponsorship_level do %>
                  <p class="mt-2 text-lg text-gray-600">
                    {@sponsor.sponsorship_level} Sponsor
                  </p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link
                  patch={~p"/sponsors/#{@sponsor.id}/edit"}
                  class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
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
              <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                <.icon name="hero-flag" class="h-5 w-5 mr-2 text-indigo-600" />
                Pipeline Progress
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
                  <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                    <.icon name="hero-megaphone" class="h-5 w-5 mr-2 text-indigo-600" />
                    Outreach
                  </h2>
                  <div class="bg-gray-50 rounded-lg p-4">
                    <%= if @sponsor.outreach do %>
                      <p class="text-sm text-gray-900 whitespace-pre-wrap">{@sponsor.outreach}</p>
                    <% else %>
                      <p class="text-sm text-gray-400">No outreach information recorded</p>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Sponsorship Details -->
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                    <.icon name="hero-currency-dollar" class="h-5 w-5 mr-2 text-indigo-600" />
                    Sponsorship Details
                  </h2>
                  <div class="bg-gray-50 rounded-lg p-4 space-y-4">
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Sponsorship Level</dt>
                      <dd class="mt-1">
                        <%= if @sponsor.sponsorship_level do %>
                          <span class="text-sm font-medium text-gray-900">
                            {@sponsor.sponsorship_level}
                          </span>
                        <% else %>
                          <span class="text-sm text-gray-400">Not set</span>
                        <% end %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Status</dt>
                      <dd class="mt-1">
                        <%= cond do %>
                          <% @sponsor.confirmed -> %>
                            <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                              Confirmed
                            </span>
                          <% @sponsor.interested -> %>
                            <span class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800">
                              Interested
                            </span>
                          <% @sponsor.responded -> %>
                            <span class="inline-flex items-center rounded-full bg-yellow-100 px-2.5 py-0.5 text-xs font-medium text-yellow-800">
                              In Contact
                            </span>
                          <% true -> %>
                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
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
            <div class="mt-8 pt-8 border-t border-gray-200">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Added to system</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {Calendar.strftime(@sponsor.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Last updated</dt>
                  <dd class="mt-1 text-sm text-gray-900">
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
      if(@value, do: "bg-green-50 border-green-200", else: "bg-gray-50 border-gray-200")
    ]}>
      <%= if @value do %>
        <.icon name="hero-check-circle" class="h-6 w-6 text-green-600 mx-auto" />
      <% else %>
        <.icon name="hero-x-circle" class="h-6 w-6 text-gray-300 mx-auto" />
      <% end %>
      <p class={[
        "text-xs font-medium mt-1",
        if(@value, do: "text-green-700", else: "text-gray-500")
      ]}>
        {@label}
      </p>
    </div>
    """
  end
end
