defmodule GutWeb.WorkshopSurveyResultsLive do
  @moduledoc """
  Survey results for the workshop organizer (and staff).

  A paged Cinder table with one row per respondent (attendee name, no
  contact information) and one column per question, plus a CSV export.
  """
  use GutWeb, :live_view
  use Cinder.UrlSync

  require Ash.Query

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  def mount(%{"id" => workshop_id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, workshop} <-
           Gut.Conference.get_workshop(workshop_id, load: [:speakers], actor: @public_actor),
         true <- organizer?(workshop, user) do
      survey =
        Gut.Conference.Survey
        |> Ash.Query.filter(workshop_id == ^workshop.id)
        |> Ash.Query.load([:response_count, questions: []])
        |> Ash.read_one!(actor: user)

      if survey do
        socket =
          socket
          |> assign(:page_title, "Results: #{survey.title}")
          |> assign(:workshop, workshop)
          |> assign(:survey, survey)
          |> assign(:participant_names, participant_names(workshop))
          |> assign(:current_scope, nil)

        {:ok, socket}
      else
        {:ok,
         socket
         |> put_flash(:error, "There is no survey for this workshop yet.")
         |> push_navigate(to: ~p"/workshops/#{workshop.id}/survey")}
      end
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "You are not an organizer of this workshop.")
         |> push_navigate(to: ~p"/")}
    end
  end

  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  defp organizer?(workshop, user) do
    user.role == :staff or Enum.any?(workshop.speakers, &(&1.user_id == user.id))
  end

  # Participant names are public data (read via the public actor); we map
  # them by user id to label responses. No email or phone is exposed here.
  defp participant_names(workshop) do
    Gut.Conference.WorkshopParticipation
    |> Ash.Query.filter(workshop_id == ^workshop.id)
    |> Ash.Query.load(:workshop_participant)
    |> Ash.read!(actor: @public_actor)
    |> Map.new(fn participation ->
      {participation.workshop_participant.user_id, participation.workshop_participant.name}
    end)
  end

  defp responses_query(survey) do
    Gut.Conference.SurveyResponse
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(survey_id == ^survey.id)
    |> Ash.Query.load(:answers)
    |> Ash.Query.sort(inserted_at: :asc)
  end

  defp answer_for(response, question_id) do
    case Enum.find(response.answers, &(&1.survey_question_id == question_id)) do
      nil -> nil
      answer -> answer.value
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-7xl mx-auto">
        <div class="mb-6">
          <.link
            navigate={~p"/workshops/#{@workshop.id}/survey"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to survey
          </.link>
        </div>

        <div class="mb-8 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">{@survey.title}</h1>
            <p class="text-base-content/60 mt-1">
              {@survey.response_count} response(s) from attendees of
              <span class="font-medium">{@workshop.name}</span>
            </p>
          </div>
          <a href={~p"/export/survey-responses/#{@workshop.id}"} class="btn btn-ghost">
            <.icon name="hero-arrow-down-tray" class="h-4 w-4 mr-2" /> Export CSV
          </a>
        </div>

        <Cinder.Table.table
          id="survey-results-table"
          query={responses_query(@survey)}
          actor={@current_user}
          url_state={@url_state}
          theme={GutWeb.CinderTheme}
          page_size={[default: 10, options: [10, 25, 50]]}
        >
          <:col :let={response} label="Attendee">
            <span class="font-medium">
              {@participant_names[response.user_id] || "Unknown"}
            </span>
          </:col>

          <:col :let={response} :for={question <- @survey.questions} label={question.prompt}>
            <%= if value = answer_for(response, question.id) do %>
              <div class="text-sm max-w-xs whitespace-pre-line">{value}</div>
            <% else %>
              <span class="text-base-content/40">-</span>
            <% end %>
          </:col>

          <:col :let={response} field="inserted_at" sort label="Submitted">
            <div class="text-sm text-base-content/50">
              {Calendar.strftime(response.inserted_at, "%b %d, %Y %H:%M")}
            </div>
          </:col>
        </Cinder.Table.table>
      </div>
    </Layouts.app>
    """
  end
end
