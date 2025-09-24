defmodule GutWeb.SpeakerDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    speaker =
      Gut.Conference.get_speaker!(id,
        actor: socket.assigns.current_user,
        load: [:user]
      )

    socket =
      socket
      |> assign(:page_title, "Speaker Details")
      |> assign(:speaker, speaker)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/speakers"}
            class="inline-flex items-center text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Speakers
          </.link>
        </div>

        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 rounded-xl overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 bg-gradient-to-r from-indigo-50 to-purple-50 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-gray-900">{@speaker.full_name}</h1>
                <p class="mt-2 text-lg text-gray-600">
                  {@speaker.first_name} {@speaker.last_name}
                </p>
                <%= if @speaker.user do %>
                  <p class="mt-1 text-sm text-gray-500">
                    Associated with user account
                  </p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link
                  patch={~p"/speakers/#{@speaker.id}/edit"}
                  class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                >
                  Edit Speaker
                </.link>
              </div>
            </div>
          </div>
          
    <!-- Content -->
          <div class="px-6 py-8">
            <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
              <!-- Travel Information -->
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                    <.icon name="hero-airplane-departure" class="h-5 w-5 mr-2 text-indigo-600" />
                    Travel Information
                  </h2>
                  <div class="bg-gray-50 rounded-lg p-4 space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Arrival</dt>
                        <dd class="mt-1">
                          <%= if @speaker.arrival_date do %>
                            <div class="text-sm font-medium text-gray-900">
                              {Date.to_string(@speaker.arrival_date)}
                            </div>
                            <%= if @speaker.arrival_time do %>
                              <div class="text-sm text-gray-600">
                                {Time.to_string(@speaker.arrival_time)}
                              </div>
                            <% end %>
                          <% else %>
                            <span class="text-sm text-gray-400">Not scheduled</span>
                          <% end %>
                        </dd>
                      </div>
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Departure</dt>
                        <dd class="mt-1">
                          <%= if @speaker.leaving_date do %>
                            <div class="text-sm font-medium text-gray-900">
                              {Date.to_string(@speaker.leaving_date)}
                            </div>
                            <%= if @speaker.leaving_time do %>
                              <div class="text-sm text-gray-600">
                                {Time.to_string(@speaker.leaving_time)}
                              </div>
                            <% end %>
                          <% else %>
                            <span class="text-sm text-gray-400">Not scheduled</span>
                          <% end %>
                        </dd>
                      </div>
                    </div>
                  </div>
                </div>
                
    <!-- Travel Duration -->
                <%= if @speaker.arrival_date and @speaker.leaving_date do %>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <div class="flex items-center">
                      <.icon name="hero-clock" class="h-5 w-5 text-blue-600 mr-2" />
                      <div>
                        <p class="text-sm font-medium text-blue-900">Total Stay Duration</p>
                        <p class="text-sm text-blue-700">
                          {Date.diff(@speaker.leaving_date, @speaker.arrival_date)} days
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
              
    <!-- Hotel Information -->
              <div class="space-y-6">
                <div>
                  <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                    <.icon name="hero-building-office-2" class="h-5 w-5 mr-2 text-indigo-600" />
                    Hotel Information
                  </h2>
                  <div class="bg-gray-50 rounded-lg p-4 space-y-4">
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Hotel Stay Period</dt>
                      <dd class="mt-1">
                        <%= if not is_nil(@speaker.hotel_stay_start_date) and not is_nil(@speaker.hotel_stay_end_date) do %>
                          <div class="text-sm">
                            <div class="font-medium text-gray-900">
                              {Date.to_string(@speaker.hotel_stay_start_date)} to {Date.to_string(
                                @speaker.hotel_stay_end_date
                              )}
                            </div>
                            <div class="text-gray-600 mt-1">
                              {Date.diff(@speaker.hotel_stay_end_date, @speaker.hotel_stay_start_date)} nights
                            </div>
                          </div>
                        <% else %>
                          <span class="text-sm text-gray-400">Not set</span>
                        <% end %>
                      </dd>
                    </div>

                    <div>
                      <dt class="text-sm font-medium text-gray-500">Conference Coverage</dt>
                      <dd class="mt-1">
                        <%= if not is_nil(@speaker.hotel_covered_start_date) and not is_nil(@speaker.hotel_covered_end_date) do %>
                          <div class="text-sm">
                            <div class="font-medium text-green-700">
                              {Date.to_string(@speaker.hotel_covered_start_date)} to {Date.to_string(
                                @speaker.hotel_covered_end_date
                              )}
                            </div>
                            <div class="text-green-600 mt-1">
                              {Date.diff(
                                @speaker.hotel_covered_end_date,
                                @speaker.hotel_covered_start_date
                              )} nights covered
                            </div>
                          </div>
                        <% else %>
                          <span class="text-sm text-gray-400">Not covered</span>
                        <% end %>
                      </dd>
                    </div>
                  </div>
                </div>
                
    <!-- Coverage Status -->
                <%= if not is_nil(@speaker.hotel_stay_start_date) and not is_nil(@speaker.hotel_stay_end_date) and
                       not is_nil(@speaker.hotel_covered_start_date) and not is_nil(@speaker.hotel_covered_end_date) do %>
                  <div class={[
                    "border rounded-lg p-4",
                    if(coverage_complete?(@speaker),
                      do: "bg-green-50 border-green-200",
                      else: "bg-yellow-50 border-yellow-200"
                    )
                  ]}>
                    <div class="flex items-center">
                      <%= if coverage_complete?(@speaker) do %>
                        <.icon name="hero-check-circle" class="h-5 w-5 text-green-600 mr-2" />
                        <div>
                          <p class="text-sm font-medium text-green-900">Full Coverage</p>
                          <p class="text-sm text-green-700">
                            All hotel nights are covered by the conference
                          </p>
                        </div>
                      <% else %>
                        <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-600 mr-2" />
                        <div>
                          <p class="text-sm font-medium text-yellow-900">Partial Coverage</p>
                          <p class="text-sm text-yellow-700">
                            {uncovered_nights(@speaker)} nights not covered by the conference
                          </p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Metadata -->
            <div class="mt-8 pt-8 border-t border-gray-200">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Added to system</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {Calendar.strftime(@speaker.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Last updated</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {Calendar.strftime(@speaker.updated_at, "%B %d, %Y at %I:%M %p")}
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

  # Helper functions
  defp coverage_complete?(speaker) do
    not is_nil(speaker.hotel_stay_start_date) and not is_nil(speaker.hotel_stay_end_date) and
      not is_nil(speaker.hotel_covered_start_date) and not is_nil(speaker.hotel_covered_end_date) and
      speaker.hotel_stay_start_date == speaker.hotel_covered_start_date and
      speaker.hotel_stay_end_date == speaker.hotel_covered_end_date
  end

  defp uncovered_nights(speaker) do
    if not is_nil(speaker.hotel_stay_start_date) and not is_nil(speaker.hotel_stay_end_date) and
         not is_nil(speaker.hotel_covered_start_date) and
         not is_nil(speaker.hotel_covered_end_date) do
      total_nights = Date.diff(speaker.hotel_stay_end_date, speaker.hotel_stay_start_date)
      covered_nights = Date.diff(speaker.hotel_covered_end_date, speaker.hotel_covered_start_date)
      max(0, total_nights - covered_nights)
    else
      0
    end
  end
end
