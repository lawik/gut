defmodule GutWeb.SurveyReviewLive do
  @moduledoc """
  Staff review of a survey. From here staff can send a submitted survey to
  all workshop attendees or return it to the organizer for changes.
  """
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign(:current_scope, nil)
      |> load_survey(id)

    {:ok, socket}
  end

  defp load_survey(socket, id) do
    survey =
      Gut.Conference.get_survey!(id,
        actor: socket.assigns.current_user,
        load: [:workshop, :response_count, questions: [:options]]
      )

    socket
    |> assign(:survey, survey)
    |> assign(:page_title, "Review: #{survey.title}")
  end

  defp question_type_label(:single_line), do: "Single line answer"
  defp question_type_label(:multiline), do: "Multiline answer"
  defp question_type_label(:select), do: "Select from dropdown"

  defp status_label(:draft), do: "Draft"
  defp status_label(:in_review), do: "In review"
  defp status_label(:sent), do: "Sent"

  defp status_class(:draft), do: "badge-neutral"
  defp status_class(:in_review), do: "badge-warning"
  defp status_class(:sent), do: "badge-success"

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/surveys"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Surveys
          </.link>
        </div>

        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">{@survey.title}</h1>
            <p class="text-base-content/60 mt-1">
              Survey for <span class="font-medium">{@survey.workshop.name}</span>
            </p>
          </div>
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/workshops/#{@survey.workshop_id}/survey/preview"}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-eye" class="size-4" /> Preview
            </.link>
            <span class={["badge badge-lg", status_class(@survey.status)]}>
              {status_label(@survey.status)}
            </span>
          </div>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6 mb-8">
          <p :if={@survey.description} class="text-base-content/70 mb-4">
            {@survey.description}
          </p>

          <h2 class="text-lg font-semibold text-base-content mb-2">Questions</h2>
          <p :if={@survey.questions == []} class="text-base-content/50">
            This survey has no questions.
          </p>
          <ol class="space-y-3 list-decimal list-inside">
            <li :for={question <- @survey.questions}>
              <span class="font-medium">{question.prompt}</span>
              <span :if={question.required} class="text-error">*</span>
              <span class="text-sm text-base-content/50 ml-2">
                ({question_type_label(question.question_type)}{if question.required,
                  do: ", required"})
              </span>
              <ul
                :if={question.question_type == :select}
                class="list-disc list-inside ml-6 text-sm text-base-content/70"
              >
                <li :for={option <- question.options}>{option.label}</li>
              </ul>
            </li>
          </ol>
        </div>

        <div class="bg-base-200 rounded-xl p-6">
          <%= case @survey.status do %>
            <% :draft -> %>
              <p class="text-base-content/70">
                The organizer is still drafting this survey. It has not been submitted for review.
              </p>
            <% :in_review -> %>
              <p class="text-base-content/70 mb-4">
                Sending the survey emails every registered attendee of the workshop a link
                that signs them in and takes them to the survey.
              </p>
              <div class="flex gap-3">
                <button
                  class="btn btn-primary"
                  phx-click="send"
                  data-confirm="Send this survey to all registered attendees of the workshop?"
                >
                  Send to attendees
                </button>
                <button class="btn btn-ghost" phx-click="return_to_draft">
                  Return to draft
                </button>
              </div>
            <% :sent -> %>
              <p class="text-base-content/70">
                Sent {Calendar.strftime(@survey.sent_at, "%Y-%m-%d %H:%M UTC")}. {@survey.response_count} response(s) so far.
              </p>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("send", _params, socket) do
    case Gut.Conference.send_survey(socket.assigns.survey, actor: socket.assigns.current_user) do
      {:ok, survey} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey sent to attendees")
         |> load_survey(survey.id)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not send the survey.")}
    end
  end

  def handle_event("return_to_draft", _params, socket) do
    case Gut.Conference.return_survey_to_draft(socket.assigns.survey,
           actor: socket.assigns.current_user
         ) do
      {:ok, survey} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey returned to draft")
         |> load_survey(survey.id)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not return the survey to draft.")}
    end
  end
end
