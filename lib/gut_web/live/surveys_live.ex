defmodule GutWeb.SurveysLive do
  @moduledoc """
  Staff overview of all workshop surveys and their review states.
  """
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "surveys:changed")
    end

    socket =
      socket
      |> assign(:page_title, "Surveys")
      |> assign(:current_scope, nil)
      |> load_surveys()

    {:ok, socket}
  end

  def handle_info(%{topic: "surveys:changed"}, socket) do
    {:noreply, load_surveys(socket)}
  end

  defp load_surveys(socket) do
    surveys =
      Gut.Conference.list_surveys!(
        actor: socket.assigns.current_user,
        load: [:workshop, :question_count, :response_count]
      )
      |> Enum.sort_by(&status_order(&1.status))

    assign(socket, :surveys, surveys)
  end

  defp status_order(:in_review), do: 0
  defp status_order(:draft), do: 1
  defp status_order(:sent), do: 2

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
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-5xl mx-auto">
        <div class="mb-8">
          <h1 class="text-2xl font-semibold text-base-content">Surveys</h1>
          <p class="text-base-content/60 mt-1">
            Workshop surveys submitted by organizers. Review and send them to attendees.
          </p>
        </div>

        <%= if @surveys == [] do %>
          <p class="text-base-content/60">No surveys have been created yet.</p>
        <% else %>
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden">
            <table class="table">
              <thead>
                <tr>
                  <th>Survey</th>
                  <th>Workshop</th>
                  <th>Status</th>
                  <th>Questions</th>
                  <th>Responses</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={survey <- @surveys}>
                  <td class="font-medium">{survey.title}</td>
                  <td>{survey.workshop.name}</td>
                  <td>
                    <span class={["badge", status_class(survey.status)]}>
                      {status_label(survey.status)}
                    </span>
                  </td>
                  <td>{survey.question_count}</td>
                  <td>{survey.response_count}</td>
                  <td class="text-right">
                    <.link navigate={~p"/surveys/#{survey.id}/review"} class="btn btn-sm">
                      Review
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
