defmodule GutWeb.MyWorkshopsLive do
  @moduledoc """
  Shows the workshops the current user organizes (is a speaker on) as cards
  with the attendee names and the state of each workshop's attendee survey.

  Attendee names only: no email addresses or other contact information.
  """
  use GutWeb, :live_view

  require Ash.Query

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    workshops =
      Gut.Conference.Workshop
      |> Ash.Query.filter(speakers.user_id == ^user.id)
      |> Ash.Query.load([:workshop_timeslot])
      |> Ash.read!(actor: @public_actor)

    workshop_ids = Enum.map(workshops, & &1.id)

    surveys =
      Gut.Conference.Survey
      |> Ash.Query.filter(workshop_id in ^workshop_ids)
      |> Ash.read!(actor: user)
      |> Map.new(&{&1.workshop_id, &1})

    blast_counts =
      Gut.Conference.Blast
      |> Ash.Query.filter(workshop_id in ^workshop_ids)
      |> Ash.read!(actor: user)
      |> Enum.frequencies_by(& &1.workshop_id)

    participations =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_id in ^workshop_ids)
      |> Ash.Query.load(:workshop_participant)
      |> Ash.read!(actor: @public_actor)
      |> Enum.group_by(& &1.workshop_id)

    socket =
      socket
      |> assign(:page_title, "My Workshops")
      |> assign(:current_scope, nil)
      |> assign(:workshops, workshops)
      |> assign(:surveys, surveys)
      |> assign(:blast_counts, blast_counts)
      |> assign(:participations, participations)

    {:ok, socket}
  end

  defp attendee_names(participations) do
    participations
    |> Enum.filter(&(&1.status == :registered))
    |> Enum.map(& &1.workshop_participant.name)
    |> Enum.sort()
  end

  defp waitlist_count(participations) do
    Enum.count(participations, &(&1.status == :waitlisted))
  end

  defp survey_status_label(nil), do: "No survey yet"
  defp survey_status_label(%{status: :draft}), do: "Survey: Draft"
  defp survey_status_label(%{status: :in_review}), do: "Survey: In review"
  defp survey_status_label(%{status: :sent}), do: "Survey: Sent"

  defp survey_status_class(nil), do: "badge-ghost"
  defp survey_status_class(%{status: :draft}), do: "badge-neutral"
  defp survey_status_class(%{status: :in_review}), do: "badge-warning"
  defp survey_status_class(%{status: :sent}), do: "badge-success"

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-5xl mx-auto">
        <div class="mb-8">
          <h1 class="text-2xl font-semibold text-base-content">My Workshops</h1>
          <p class="text-base-content/60 mt-1">
            Workshops you organize. For each one you can email an update to your attendees
            or create a survey for them.
          </p>
        </div>

        <%= if @workshops == [] do %>
          <p class="text-base-content/60">No workshops are associated with your account.</p>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div
              :for={workshop <- @workshops}
              class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6 flex flex-col"
            >
              <div class="flex items-start justify-between gap-3">
                <div>
                  <h2 class="text-lg font-semibold text-base-content">{workshop.name}</h2>
                  <p :if={workshop.workshop_timeslot} class="text-sm text-base-content/50">
                    {workshop.workshop_timeslot.name}
                  </p>
                </div>
                <span class={["badge whitespace-nowrap", survey_status_class(@surveys[workshop.id])]}>
                  {survey_status_label(@surveys[workshop.id])}
                </span>
              </div>

              <div class="mt-4 flex-1">
                <% participations = Map.get(@participations, workshop.id, []) %>
                <% names = attendee_names(participations) %>
                <% waitlisted = waitlist_count(participations) %>

                <h3 class="text-sm font-medium text-base-content/70 mb-2">
                  Attendees ({length(names)})
                </h3>
                <p :if={names == []} class="text-sm text-base-content/50">
                  No attendees yet.
                </p>
                <ul class="text-sm text-base-content/80 columns-2 gap-4 space-y-1">
                  <li :for={name <- names}>{name}</li>
                </ul>
                <p :if={waitlisted > 0} class="text-sm text-base-content/50 mt-2">
                  +{waitlisted} on the waitlist
                </p>
              </div>

              <div class="mt-6 flex justify-end items-center gap-2">
                <span :if={@blast_counts[workshop.id]} class="text-xs text-base-content/50 mr-auto">
                  {@blast_counts[workshop.id]} {if @blast_counts[workshop.id] == 1,
                    do: "update",
                    else: "updates"} sent
                </span>
                <.link
                  navigate={~p"/workshops/#{workshop.id}/blasts"}
                  class="btn btn-sm btn-secondary"
                >
                  Send update
                </.link>
                <.link
                  navigate={~p"/workshops/#{workshop.id}/survey"}
                  class="btn btn-sm btn-primary"
                >
                  Manage survey
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
