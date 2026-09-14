defmodule GutWeb.WorkshopStatusMailingLive do
  @moduledoc """
  Staff page for sending the workshop status email to every participant.

  Staff edit the Markdown intro; the rest of each email is generated per
  participant (their seats, their waitlists and alternatives with seats).
  The preview renders the real email for an example participant.
  """
  use GutWeb, :live_view

  require Ash.Query

  alias Gut.Emails.WorkshopStatus

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "status_mailings:changed")
    end

    recipients = WorkshopStatus.recipients()

    socket =
      socket
      |> assign(:page_title, "Workshop status emails")
      |> assign(:current_scope, nil)
      |> assign(:recipients, recipients)
      |> assign(:example, pick_example(recipients))
      |> assign_form(WorkshopStatus.default_intro())
      |> load_mailings()

    {:ok, socket}
  end

  # Prefer someone on a waitlist so the preview shows the richest email.
  defp pick_example([]), do: nil

  defp pick_example(recipients) do
    ids = Enum.map(recipients, & &1.id)

    waitlisted_ids =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_participant_id in ^ids and status == :waitlisted)
      |> Ash.read!(actor: socket_actor())
      |> MapSet.new(& &1.workshop_participant_id)

    Enum.find(recipients, hd(recipients), &MapSet.member?(waitlisted_ids, &1.id))
  end

  defp socket_actor, do: Gut.system_actor("status_mailing_preview")

  defp assign_form(socket, intro) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.StatusMailing, :send,
        actor: socket.assigns.current_user
      )
      |> AshPhoenix.Form.validate(%{"intro" => intro})
      |> to_form()

    socket
    |> assign(:form, form)
    |> assign(:intro, intro)
    |> assign_preview(intro)
  end

  defp assign_preview(%{assigns: %{example: nil}} = socket, _intro) do
    assign(socket, :preview_html, nil)
  end

  defp assign_preview(socket, intro) do
    data = WorkshopStatus.build(socket.assigns.example, intro)
    assign(socket, :preview_html, WorkshopStatus.html(data, url(~p"/workshops/browse")))
  end

  defp load_mailings(socket) do
    mailings =
      Gut.Conference.StatusMailing
      |> Ash.Query.sort(sent_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)

    assign(socket, :mailings, mailings)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <Layouts.workshop_subnav active="status-mailing" />
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-6xl mx-auto">
        <div class="mb-8">
          <h1 class="text-2xl font-semibold text-base-content">Workshop status emails</h1>
          <p class="text-base-content/60 mt-1">
            Email every workshop participant a summary of where they stand: the workshops they
            have a seat in, the ones they are waitlisted for, and alternatives in those timeslots
            that still have seats. Everyone gets a signed link back to the registration page.
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
            <.form for={@form} id="status-mailing-form" phx-change="validate" phx-submit="send">
              <div>
                <.input field={@form[:intro]} type="textarea" label="Intro" rows="12" required />
                <p class="text-xs text-base-content/50 mt-1">
                  Markdown. Shown at the top of every email; the per-person workshop list is
                  added automatically below it.
                </p>
              </div>

              <div class="mt-8 flex justify-end items-center gap-3">
                <span class="text-sm text-base-content/50" id="recipient-count">
                  Goes to {length(@recipients)}
                  {if length(@recipients) == 1, do: "participant", else: "participants"} with an
                  email address.
                </span>
                <.button
                  type="submit"
                  phx-disable-with="Sending..."
                  class="btn btn-primary"
                  disabled={@recipients == []}
                  data-confirm={"Email #{length(@recipients)} participants their workshop status now? This cannot be undone."}
                >
                  <.icon name="hero-paper-airplane" class="size-4" /> Send status emails
                </.button>
              </div>
            </.form>
          </div>

          <div
            class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6"
            id="status-preview"
          >
            <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/50 mb-1">
              Preview
            </h2>
            <%= if @example do %>
              <p class="text-xs text-base-content/50 mb-4">
                As it will be sent to {@example.name} ({@example.user.email}). Each recipient gets
                their own workshops.
              </p>
              <div class="rounded-lg border border-base-300 p-5 survey-markdown text-base-content/80">
                <p class="text-sm text-base-content/50 mb-3">
                  Subject:
                  <span class="font-medium text-base-content">{WorkshopStatus.subject()}</span>
                </p>
                {Phoenix.HTML.raw(@preview_html)}
              </div>
            <% else %>
              <p class="text-base-content/60">
                No participant with an email address is signed up for a workshop yet, so there is
                nobody to preview or send to.
              </p>
            <% end %>
          </div>
        </div>

        <div class="mt-10" id="sent-mailings">
          <h2 class="text-lg font-semibold text-base-content mb-3">Sent mailings</h2>
          <p :if={@mailings == []} class="text-base-content/60">
            No status emails have been sent yet.
          </p>
          <div
            :if={@mailings != []}
            class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl overflow-hidden"
          >
            <table class="table">
              <thead>
                <tr>
                  <th>Sent</th>
                  <th>Recipients</th>
                  <th>Intro</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={mailing <- @mailings}>
                  <td class="whitespace-nowrap">
                    {Calendar.strftime(mailing.sent_at, "%B %d, %Y at %H:%M")} UTC
                  </td>
                  <td>{mailing.recipient_count}</td>
                  <td class="text-base-content/70 text-sm whitespace-pre-line max-w-xl">
                    {mailing.intro}
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
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    intro = params["intro"] || ""

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:intro, intro)
     |> assign_preview(intro)}
  end

  def handle_event("send", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, mailing} ->
        {:noreply,
         socket
         |> put_flash(:info, sent_message(mailing.recipient_count))
         |> assign_form(WorkshopStatus.default_intro())
         |> load_mailings()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp sent_message(1), do: "Status email sent to 1 participant."
  defp sent_message(n), do: "Status emails sent to #{n} participants."

  def handle_info(%{topic: "status_mailings:changed"}, socket) do
    {:noreply, load_mailings(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
