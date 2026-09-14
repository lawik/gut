defmodule GutWeb.BlastLive do
  @moduledoc """
  Shows one workshop blast to a logged-in attendee of that workshop (or its
  organizers and staff). This is the page the blast email links to.
  """
  use GutWeb, :live_view

  import GutWeb.SurveyComponents, only: [markdown: 1]

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    socket = assign(socket, :current_scope, nil)

    case Gut.Conference.get_blast(id, actor: user) do
      {:ok, blast} ->
        # Workshops are public data but only readable via the public actor.
        workshop = Gut.Conference.get_workshop!(blast.workshop_id, actor: @public_actor)

        {:ok,
         socket
         |> assign(:page_title, blast.title)
         |> assign(:blast, blast)
         |> assign(:workshop, workshop)}

      _not_available ->
        {:ok,
         socket
         |> assign(:page_title, "Workshop update")
         |> assign(:blast, nil)
         |> assign(:workshop, nil)}
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
        <div class="mb-6">
          <.link
            navigate={~p"/workshops/browse"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to your workshops
          </.link>
        </div>

        <%= if @blast do %>
          <article class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6 sm:p-8">
            <p class="text-sm text-base-content/60">
              An update from the organizer of
              <span class="font-medium text-base-content">{@workshop.name}</span>
            </p>
            <h1 class="text-2xl font-semibold text-base-content mt-1">{@blast.title}</h1>
            <p class="text-xs text-base-content/50 mt-1">
              Sent {Calendar.strftime(@blast.sent_at, "%B %d, %Y at %H:%M")} UTC
            </p>
            <.markdown text={@blast.body} class="text-base-content/80 mt-6" />
          </article>
        <% else %>
          <div class="bg-base-200 rounded-xl p-8 text-center">
            <h1 class="text-xl font-semibold text-base-content mb-2">Update not available</h1>
            <p class="text-base-content/60">
              This update does not exist or is not addressed to you.
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
