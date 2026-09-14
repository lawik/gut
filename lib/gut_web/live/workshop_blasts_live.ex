defmodule GutWeb.WorkshopBlastsLive do
  @moduledoc """
  Lets workshop organizers (speakers on the workshop, and staff) send an
  email blast to everyone registered for the workshop.

  The form takes a title and a Markdown body with a live preview rendered
  the same way as the email and the attendee-facing page. Sending is
  immediate; previously sent blasts are listed below the form.
  """
  use GutWeb, :live_view

  import GutWeb.SurveyComponents, only: [markdown: 1]

  require Ash.Query

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @public_actor Gut.public_actor()

  def mount(%{"id" => workshop_id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, workshop} <-
           Gut.Conference.get_workshop(workshop_id,
             load: [:speakers, :registration_count],
             actor: @public_actor
           ),
         true <- organizer?(workshop, user) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Gut.PubSub, "blasts:changed")
      end

      socket =
        socket
        |> assign(:page_title, "Updates for #{workshop.name}")
        |> assign(:workshop, workshop)
        |> assign(:current_scope, nil)
        |> assign_form()
        |> load_blasts()

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

  defp assign_form(socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.Blast, :send, actor: socket.assigns.current_user)
      |> to_form()

    socket
    |> assign(:form, form)
    |> assign(:preview, %{title: "", body: nil})
  end

  defp load_blasts(socket) do
    blasts =
      Gut.Conference.Blast
      |> Ash.Query.filter(workshop_id == ^socket.assigns.workshop.id)
      |> Ash.Query.sort(sent_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)

    assign(socket, :blasts, blasts)
  end

  defp with_workshop(params, socket) do
    Map.put(params, "workshop_id", socket.assigns.workshop.id)
  end

  defp preview_from(params) do
    %{title: String.trim(params["title"] || ""), body: params["body"]}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-6xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/my-workshops"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80 mb-3"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to my workshops
          </.link>
          <h1 class="text-2xl font-semibold text-base-content">
            Send an update to attendees of {@workshop.name}
          </h1>
          <p class="text-base-content/60 mt-1">
            Everyone registered for your workshop gets it by email right away, with a link
            back to this update. Attendees can also find all updates for their workshops on
            the workshop registration page.
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
            <.form for={@form} id="blast-form" phx-change="validate" phx-submit="send">
              <div class="space-y-6">
                <.input field={@form[:title]} type="text" label="Subject" required />
                <div>
                  <.input
                    field={@form[:body]}
                    type="textarea"
                    label="Message"
                    rows="14"
                    required
                  />
                  <p class="text-xs text-base-content/50 mt-1">
                    Markdown. Line breaks are kept. **bold**, _italics_, lists, links and
                    headings all work; the preview shows exactly what attendees will get.
                  </p>
                </div>
              </div>

              <div class="mt-8 flex justify-end items-center gap-3">
                <span class="text-sm text-base-content/50">
                  Goes to {@workshop.registration_count || 0} registered {if @workshop.registration_count ==
                                                                               1,
                                                                             do: "attendee",
                                                                             else: "attendees"}.
                </span>
                <.button
                  type="submit"
                  phx-disable-with="Sending..."
                  class="btn btn-primary"
                  data-confirm="Send this update by email to everyone registered for the workshop? This cannot be undone."
                >
                  <.icon name="hero-paper-airplane" class="size-4" /> Send Blast
                </.button>
              </div>
            </.form>
          </div>

          <div
            class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6"
            id="blast-preview"
          >
            <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/50 mb-4">
              Preview
            </h2>
            <div class="rounded-lg border border-base-300 p-5">
              <p class="text-sm text-base-content/60">
                An update from the organizer of
                <span class="font-medium text-base-content">{@workshop.name}</span>
              </p>
              <h3 class="text-xl font-semibold text-base-content mt-1">
                <%= if @preview.title == "" do %>
                  <span class="text-base-content/30">Subject</span>
                <% else %>
                  {@preview.title}
                <% end %>
              </h3>
              <%= if @preview.body in [nil, ""] do %>
                <p class="text-base-content/30 mt-4">Your message will appear here as you type.</p>
              <% else %>
                <.markdown text={@preview.body} class="text-base-content/80 mt-4" />
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-10" id="sent-blasts">
          <h2 class="text-lg font-semibold text-base-content mb-3">Sent updates</h2>
          <p :if={@blasts == []} class="text-base-content/60">
            No updates have been sent for this workshop yet.
          </p>
          <div
            :if={@blasts != []}
            class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden"
          >
            <table class="table">
              <thead>
                <tr>
                  <th>Subject</th>
                  <th>Sent</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={blast <- @blasts}>
                  <td class="font-medium">{blast.title}</td>
                  <td class="text-base-content/70">
                    {Calendar.strftime(blast.sent_at, "%B %d, %Y at %H:%M")} UTC
                  </td>
                  <td class="text-right">
                    <.link navigate={~p"/blasts/#{blast.id}"} class="btn btn-sm">
                      View
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, with_workshop(params, socket))

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:preview, preview_from(params))}
  end

  def handle_event("send", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: with_workshop(params, socket)) do
      {:ok, blast} ->
        enqueued = blast.__metadata__[:emails_enqueued] || 0

        {:noreply,
         socket
         |> put_flash(:info, sent_message(enqueued))
         |> assign_form()
         |> load_blasts()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp sent_message(0), do: "Update saved, but no registered attendee had an email to send to."
  defp sent_message(1), do: "Update sent to 1 attendee."
  defp sent_message(n), do: "Update sent to #{n} attendees."

  def handle_info(%{topic: "blasts:changed"}, socket) do
    {:noreply, load_blasts(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
