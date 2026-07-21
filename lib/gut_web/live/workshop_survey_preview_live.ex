defmodule GutWeb.WorkshopSurveyPreviewLive do
  @moduledoc """
  Interactive preview of a workshop's survey for its organizer (and staff).

  Renders the survey exactly as an attendee would see it, using the same
  components as the real respond page. Answers can be filled in and
  submitted, but nothing is ever saved.
  """
  use GutWeb, :live_view

  import GutWeb.SurveyComponents

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
        |> Ash.Query.load(questions: [:options])
        |> Ash.read_one!(actor: user)

      if survey do
        socket =
          socket
          |> assign(:page_title, "Preview: #{survey.title}")
          |> assign(:workshop, workshop)
          |> assign(:survey, survey)
          |> assign(:current_scope, nil)
          |> assign(:answers, %{})
          |> assign(:missing_ids, [])
          |> assign(:submitted, false)

        {:ok, socket}
      else
        {:ok,
         socket
         |> put_flash(:error, "There is no survey to preview yet.")
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

  defp organizer?(workshop, user) do
    user.role == :staff or Enum.any?(workshop.speakers, &(&1.user_id == user.id))
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
        <div class="mb-6 flex items-center justify-between gap-4">
          <.link
            navigate={~p"/workshops/#{@workshop.id}/survey"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to survey
          </.link>
        </div>

        <div class="bg-info/10 border border-info/20 rounded-xl p-4 mb-8" id="preview-banner">
          <p class="text-sm text-base-content/70">
            <span class="font-semibold">Preview.</span>
            This is what attendees will see. You can try it out; nothing you enter here is saved.
          </p>
        </div>

        <%= if @submitted do %>
          <div class="bg-success/10 border border-success/20 rounded-xl p-8 text-center">
            <h1 class="text-2xl font-bold text-success mb-2">Thank you!</h1>
            <p class="text-base-content/60">Your answers have been recorded.</p>
            <p class="text-sm text-base-content/50 mt-4">
              (Preview: no answers were actually saved.)
            </p>
            <button class="btn btn-ghost mt-4" phx-click="reset">
              Restart preview
            </button>
          </div>
        <% else %>
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
                <button type="submit" class="btn btn-primary">
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
    answers = params["answers"] || %{}

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
    answers = params["answers"] || %{}
    missing_ids = missing_required_ids(socket.assigns.survey.questions, answers)

    socket =
      socket
      |> assign(:answers, answers)
      |> assign(:missing_ids, missing_ids)
      |> assign(:submitted, missing_ids == [])

    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign(:answers, %{})
      |> assign(:missing_ids, [])
      |> assign(:submitted, false)

    {:noreply, socket}
  end
end
