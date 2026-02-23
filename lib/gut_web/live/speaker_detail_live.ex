defmodule GutWeb.SpeakerDetailLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

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
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/speakers"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Speakers
          </.link>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 bg-base-200 border-b border-base-300">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-base-content">{@speaker.full_name}</h1>
                <p class="mt-2 text-lg text-base-content/60">
                  {@speaker.first_name} {@speaker.last_name}
                </p>
                <%= if @speaker.user do %>
                  <p class="mt-1 text-sm text-base-content/50">
                    Associated with user account ({@speaker.user.email})
                  </p>
                <% end %>
              </div>
              <div class="flex space-x-3">
                <.link
                  patch={~p"/speakers/#{@speaker.id}/edit"}
                  class="btn btn-primary"
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
                  <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                    <.icon name="hero-airplane-departure" class="h-5 w-5 mr-2 text-primary" />
                    Travel Information
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4 space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                      <div>
                        <dt class="text-sm font-medium text-base-content/50">Arrival</dt>
                        <dd class="mt-1">
                          <%= if @speaker.arrival_date do %>
                            <div class="text-sm font-medium text-base-content">
                              {Date.to_string(@speaker.arrival_date)}
                            </div>
                            <%= if @speaker.arrival_time do %>
                              <div class="text-sm text-base-content/60">
                                {Time.to_string(@speaker.arrival_time)}
                              </div>
                            <% end %>
                          <% else %>
                            <span class="text-sm text-base-content/40">Not scheduled</span>
                          <% end %>
                        </dd>
                      </div>
                      <div>
                        <dt class="text-sm font-medium text-base-content/50">Departure</dt>
                        <dd class="mt-1">
                          <%= if @speaker.leaving_date do %>
                            <div class="text-sm font-medium text-base-content">
                              {Date.to_string(@speaker.leaving_date)}
                            </div>
                            <%= if @speaker.leaving_time do %>
                              <div class="text-sm text-base-content/60">
                                {Time.to_string(@speaker.leaving_time)}
                              </div>
                            <% end %>
                          <% else %>
                            <span class="text-sm text-base-content/40">Not scheduled</span>
                          <% end %>
                        </dd>
                      </div>
                    </div>
                  </div>
                </div>
                
    <!-- Travel Duration -->
                <%= if @speaker.arrival_date && @speaker.leaving_date do %>
                  <div class="bg-info/10 border border-info/30 rounded-lg p-4">
                    <div class="flex items-center">
                      <.icon name="hero-clock" class="h-5 w-5 text-info mr-2" />
                      <div>
                        <p class="text-sm font-medium text-info">Total Stay Duration</p>
                        <p class="text-sm text-info/70">
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
                  <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                    <.icon name="hero-building-office-2" class="h-5 w-5 mr-2 text-primary" />
                    Hotel Information
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4 space-y-4">
                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Hotel Stay Period</dt>
                      <dd class="mt-1">
                        <%= if not is_nil(@speaker.hotel_stay_start_date) and not is_nil(@speaker.hotel_stay_end_date) do %>
                          <div class="text-sm">
                            <div class="font-medium text-base-content">
                              {Date.to_string(@speaker.hotel_stay_start_date)} to {Date.to_string(
                                @speaker.hotel_stay_end_date
                              )}
                            </div>
                            <div class="text-base-content/60 mt-1">
                              {Date.diff(@speaker.hotel_stay_end_date, @speaker.hotel_stay_start_date)} nights
                            </div>
                          </div>
                        <% else %>
                          <span class="text-sm text-base-content/40">Not set</span>
                        <% end %>
                      </dd>
                    </div>

                    <div>
                      <dt class="text-sm font-medium text-base-content/50">Conference Coverage</dt>
                      <dd class="mt-1">
                        <%= if not is_nil(@speaker.hotel_covered_start_date) and not is_nil(@speaker.hotel_covered_end_date) do %>
                          <div class="text-sm">
                            <div class="font-medium text-success">
                              {Date.to_string(@speaker.hotel_covered_start_date)} to {Date.to_string(
                                @speaker.hotel_covered_end_date
                              )}
                            </div>
                            <div class="text-success mt-1">
                              {Date.diff(
                                @speaker.hotel_covered_end_date,
                                @speaker.hotel_covered_start_date
                              )} nights covered
                            </div>
                          </div>
                        <% else %>
                          <span class="text-sm text-base-content/40">Not covered</span>
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
                      do: "bg-success/10 border-success/30",
                      else: "bg-warning/10 border-warning/30"
                    )
                  ]}>
                    <div class="flex items-center">
                      <%= if coverage_complete?(@speaker) do %>
                        <.icon name="hero-check-circle" class="h-5 w-5 text-success mr-2" />
                        <div>
                          <p class="text-sm font-medium text-success">Full Coverage</p>
                          <p class="text-sm text-success/70">
                            All hotel nights are covered by the conference
                          </p>
                        </div>
                      <% else %>
                        <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-warning mr-2" />
                        <div>
                          <p class="text-sm font-medium text-warning">Partial Coverage</p>
                          <p class="text-sm text-warning/70">
                            {uncovered_nights(@speaker)} nights not covered by the conference
                          </p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Sessionize Data -->
            <%= if @speaker.sessionize_data && @speaker.sessionize_data != %{} do %>
              <div class="mt-8 pt-8 border-t border-base-300">
                <h2 class="text-xl font-semibold text-base-content mb-4 flex items-center">
                  <.icon name="hero-cloud-arrow-down" class="h-5 w-5 mr-2 text-primary" />
                  Sessionize Data
                </h2>
                <div class="bg-base-200 rounded-lg p-4">
                  <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <%= for {key, value} <- @speaker.sessionize_data do %>
                      <div>
                        <dt class="text-sm font-medium text-base-content/50">{humanize_key(key)}</dt>
                        <dd class="mt-1 text-sm text-base-content">
                          {format_sessionize_value(value)}
                        </dd>
                      </div>
                    <% end %>
                  </dl>
                </div>
              </div>
            <% end %>
            
    <!-- Metadata -->
            <div class="mt-8 pt-8 border-t border-base-300">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Added to system</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {Calendar.strftime(@speaker.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-base-content/50">Last updated</dt>
                  <dd class="mt-1 text-sm text-base-content">
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

  defp humanize_key(key) when is_binary(key) do
    key
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_sessionize_value(value) when is_binary(value), do: value
  defp format_sessionize_value(value) when is_number(value), do: to_string(value)
  defp format_sessionize_value(value) when is_boolean(value), do: to_string(value)
  defp format_sessionize_value(nil), do: "-"

  defp format_sessionize_value(value) when is_list(value) do
    value
    |> Enum.map_join(", ", &format_sessionize_value/1)
  end

  defp format_sessionize_value(value) when is_map(value) do
    Jason.encode!(value, pretty: true)
  end

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
