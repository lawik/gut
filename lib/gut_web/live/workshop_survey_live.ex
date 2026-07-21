defmodule GutWeb.WorkshopSurveyLive do
  @moduledoc """
  Survey builder for workshop organizers.

  Speakers attached to a workshop (and staff) can draft a survey with
  questions, save the draft and submit it for staff review.
  """
  use GutWeb, :live_view

  require Ash.Query

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  @question_type_options [
    {"Single line answer", "single_line"},
    {"Multiline answer", "multiline"},
    {"Select from dropdown", "select"}
  ]

  def mount(%{"id" => workshop_id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, workshop} <-
           Gut.Conference.get_workshop(workshop_id, load: [:speakers], actor: @public_actor),
         true <- organizer?(workshop, user) do
      socket =
        socket
        |> assign(:page_title, "Survey for #{workshop.name}")
        |> assign(:workshop, workshop)
        |> assign(:current_scope, nil)
        |> load_survey()

      {:ok, socket}
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

  defp load_survey(socket) do
    workshop = socket.assigns.workshop

    survey =
      Gut.Conference.Survey
      |> Ash.Query.filter(workshop_id == ^workshop.id)
      |> Ash.Query.load(questions: [:options])
      |> Ash.read_one!(actor: socket.assigns.current_user)

    socket
    |> assign(:survey, survey)
    |> assign_form(survey)
  end

  defp assign_form(socket, nil) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.Survey, :create,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(socket, %{status: :draft} = survey) do
    form =
      AshPhoenix.Form.for_update(survey, :update_draft,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(socket, _survey), do: assign(socket, :form, nil)

  defp with_workshop(params, socket) do
    if socket.assigns.survey do
      params
    else
      Map.put(params, "workshop_id", socket.assigns.workshop.id)
    end
  end

  defp question_type(question_form) do
    case question_form[:question_type].value do
      value when value in [:single_line, :multiline, :select] -> value
      value when value in ["single_line", "multiline", "select"] -> String.to_atom(value)
      _ -> :single_line
    end
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
    assigns = assign(assigns, :question_type_options, @question_type_options)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">
              Attendee survey for {@workshop.name}
            </h1>
            <p class="text-base-content/60 mt-1">
              Draft a survey for your workshop attendees. Once you submit it for review,
              staff will check it and send it out to everyone signed up.
            </p>
          </div>
          <div :if={@survey} class="flex items-center gap-3">
            <.link
              :if={@survey.status == :sent}
              navigate={~p"/workshops/#{@workshop.id}/survey/results"}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-chart-bar" class="size-4" /> Results
            </.link>
            <.link
              navigate={~p"/workshops/#{@workshop.id}/survey/preview"}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-eye" class="size-4" /> Preview
            </.link>
            <span class={["badge badge-lg", status_class(@survey.status)]}>
              {status_label(@survey.status)}
            </span>
          </div>
        </div>

        <%= if @form do %>
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
            <.form for={@form} id="survey-form" phx-change="validate" phx-submit="save">
              <div class="space-y-6">
                <.input field={@form[:title]} type="text" label="Survey title" required />
                <.input field={@form[:description]} type="textarea" label="Description" />

                <h2 class="text-lg font-semibold text-base-content pt-2">Questions</h2>

                <.inputs_for :let={qf} field={@form[:questions]}>
                  <div
                    class="border border-base-300 rounded-lg p-4 space-y-4"
                    id={"question-form-#{qf.index}"}
                  >
                    <div class="flex items-start gap-4">
                      <div class="flex-1">
                        <.input field={qf[:prompt]} type="text" label="Question" />
                      </div>
                      <div>
                        <.input
                          field={qf[:question_type]}
                          type="select"
                          label="Answer type"
                          options={@question_type_options}
                        />
                      </div>
                      <div class="mt-8">
                        <.input field={qf[:required]} type="checkbox" label="Required" />
                      </div>
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm mt-8"
                        phx-click="remove-question"
                        phx-value-path={qf.name}
                        aria-label="Remove question"
                      >
                        <.icon name="hero-trash" class="size-4" /> Remove question
                      </button>
                    </div>

                    <%= if question_type(qf) == :select do %>
                      <div class="ml-4 space-y-2">
                        <.inputs_for :let={of} field={qf[:options]}>
                          <div
                            class="flex items-center gap-2"
                            id={"question-form-#{qf.index}-option-#{of.index}"}
                          >
                            <div class="flex-1">
                              <.input field={of[:label]} type="text" label="Option" />
                            </div>
                            <button
                              type="button"
                              class="btn btn-ghost btn-sm mt-6"
                              phx-click="remove-option"
                              phx-value-path={of.name}
                              aria-label="Remove option"
                            >
                              <.icon name="hero-x-mark" class="size-4" />
                            </button>
                          </div>
                        </.inputs_for>
                        <button
                          type="button"
                          class="btn btn-ghost btn-sm"
                          phx-click="add-option"
                          phx-value-path={qf.name <> "[options]"}
                        >
                          <.icon name="hero-plus" class="size-4" /> Add option
                        </button>
                      </div>
                    <% end %>
                  </div>
                </.inputs_for>

                <button type="button" class="btn btn-secondary btn-sm" phx-click="add-question">
                  <.icon name="hero-plus" class="size-4" /> Add question
                </button>
              </div>

              <div class="mt-8 flex justify-end items-center gap-3">
                <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
                  Save draft
                </.button>
              </div>
            </.form>

            <div :if={@survey} class="mt-4 flex justify-end items-center gap-3">
              <span class="text-sm text-base-content/50">
                Save your draft before submitting. Once submitted, staff will review and send it.
              </span>
              <button class="btn btn-accent" phx-click="submit_for_review">
                Submit to Review
              </button>
            </div>
          </div>
        <% else %>
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
            <p :if={@survey.status == :in_review} class="text-base-content/70 mb-6">
              This survey has been submitted and is waiting for staff review.
              Staff will send it out to all workshop attendees.
            </p>
            <p :if={@survey.status == :sent} class="text-base-content/70 mb-6">
              This survey has been sent to all workshop attendees.
            </p>

            <h2 class="text-lg font-semibold text-base-content mb-2">{@survey.title}</h2>
            <p :if={@survey.description} class="text-base-content/60 mb-4">
              {@survey.description}
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, with_workshop(params, socket))
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: with_workshop(params, socket)) do
      {:ok, _survey} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft saved")
         |> load_survey()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("add-question", _params, socket) do
    form =
      AshPhoenix.Form.add_form(socket.assigns.form, "form[questions]",
        params: %{"question_type" => "single_line"}
      )

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("remove-question", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("add-option", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.add_form(socket.assigns.form, path))}
  end

  def handle_event("remove-option", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("submit_for_review", _params, socket) do
    case Gut.Conference.submit_survey_for_review(socket.assigns.survey,
           actor: socket.assigns.current_user
         ) do
      {:ok, _survey} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey submitted for review")
         |> load_survey()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not submit the survey for review.")}
    end
  end
end
