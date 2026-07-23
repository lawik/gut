defmodule GutWeb.SurveyRespondLive do
  @moduledoc """
  Lets a logged-in workshop attendee answer a survey that was sent out for
  a workshop they signed up for.
  """
  use GutWeb, :live_view

  import GutWeb.SurveyComponents

  require Ash.Query

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_scope, nil)
      |> assign(:answers, %{})
      |> assign(:missing_ids, [])

    case Gut.Conference.get_survey(id,
           actor: user,
           load: [questions: [:options]]
         ) do
      # Organizers and staff can read unsent surveys, but only a sent survey
      # accepts responses; anything else shows the unavailable panel.
      {:ok, %{status: :sent} = survey} ->
        # Workshops are public data but only readable via the public actor.
        workshop = Gut.Conference.get_workshop!(survey.workshop_id, actor: @public_actor)

        existing_response =
          Gut.Conference.SurveyResponse
          |> Ash.Query.filter(survey_id == ^survey.id and user_id == ^user.id)
          |> Ash.read_one!(actor: user)

        socket =
          socket
          |> assign(:page_title, survey.title)
          |> assign(:survey, survey)
          |> assign(:workshop, workshop)
          |> assign(:existing_response, existing_response)

        {:ok, socket}

      _not_available ->
        socket =
          socket
          |> assign(:page_title, "Survey")
          |> assign(:survey, nil)
          |> assign(:workshop, nil)
          |> assign(:existing_response, nil)

        {:ok, socket}
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
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-3xl mx-auto">
        <%= cond do %>
          <% @survey == nil -> %>
            <div class="bg-base-200 rounded-xl p-8 text-center">
              <h1 class="text-xl font-semibold text-base-content mb-2">Survey not available</h1>
              <p class="text-base-content/60">
                This survey does not exist, has not been sent out yet, or is not addressed to you.
              </p>
            </div>
          <% @existing_response != nil -> %>
            <div class="bg-base-200 rounded-xl p-8 text-center">
              <h1 class="text-xl font-semibold text-base-content mb-2">Already answered</h1>
              <p class="text-base-content/60">
                You have already responded to this survey. Thank you!
              </p>
            </div>
          <% true -> %>
            <div class="mb-8">
              <h1 class="text-2xl font-semibold text-base-content">{@survey.title}</h1>
              <p class="text-base-content/60 mt-1">
                A survey for attendees of <span class="font-medium">{@workshop.name}</span>
              </p>
              <p :if={@survey.description} class="text-base-content/70 mt-4">
                {@survey.description}
              </p>
              <p class="text-sm text-base-content/50 mt-4">
                Please note that your answers are not anonymous: your name is shared with
                the workshop organizer.
              </p>
            </div>

            <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
              <form phx-submit="submit" phx-change="validate" class="space-y-6">
                <.question_fields
                  questions={@survey.questions}
                  answers={@answers}
                  missing_ids={@missing_ids}
                />

                <div class="pt-2">
                  <button type="submit" class="btn btn-primary" phx-disable-with="Submitting...">
                    Submit answers
                  </button>
                </div>
              </form>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", params, socket) do
    answers = sanitize_answers(params["answers"])

    missing_ids =
      Enum.filter(socket.assigns.missing_ids, fn id ->
        String.trim(answers[id] || "") == ""
      end)

    {:noreply,
     socket
     |> assign(:answers, answers)
     |> assign(:missing_ids, missing_ids)}
  end

  def handle_event("submit", params, socket) do
    answer_params = sanitize_answers(params["answers"])
    missing_ids = missing_required_ids(socket.assigns.survey.questions, answer_params)

    answers =
      for {question_id, value} <- answer_params,
          is_binary(value),
          String.trim(value) != "" do
        %{survey_question_id: question_id, value: value}
      end

    cond do
      missing_ids != [] ->
        {:noreply,
         socket
         |> assign(:answers, answer_params)
         |> assign(:missing_ids, missing_ids)}

      answers == [] ->
        {:noreply,
         socket
         |> assign(:answers, answer_params)
         |> put_flash(:error, "Please answer at least one question.")}

      true ->
        case Gut.Conference.respond_to_survey(
               %{survey_id: socket.assigns.survey.id, answers: answers},
               actor: socket.assigns.current_user
             ) do
          {:ok, _response} ->
            {:noreply,
             socket
             |> put_flash(:info, "Thank you! Your answers have been recorded.")
             |> push_navigate(to: ~p"/workshops/browse")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, submit_error_message(error))}
        end
    end
  end

  defp submit_error_message(%Ash.Error.Invalid{errors: errors}) do
    Enum.find_value(errors, "Could not submit your answers.", fn error ->
      case error do
        %{message: message} when is_binary(message) -> message
        _ -> nil
      end
    end)
  end

  defp submit_error_message(_error), do: "Could not submit your answers."
end
