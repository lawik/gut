defmodule GutWeb.SponsorFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    sponsor =
      Gut.Conference.get_sponsor!(id,
        actor: socket.assigns.current_user,
        load: [:user]
      )

    form =
      AshPhoenix.Form.for_update(sponsor, :update, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Editing #{sponsor.name}")
      |> assign(:sponsor, sponsor)
      |> assign(:form, form)
      |> assign(:action, :edit)
      |> assign(:current_scope, nil)
      |> assign(:invite_email, "")
      |> assign(:connected_user, sponsor.user)

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.Sponsor, :create,
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new sponsor")
      |> assign(:sponsor, nil)
      |> assign(:form, form)
      |> assign(:action, :new)
      |> assign(:current_scope, nil)
      |> assign(:invite_email, "")
      |> assign(:connected_user, nil)

    {:ok, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

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
            navigate={~p"/sponsors"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Sponsors
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-base-content">{@page_title}</h1>
            <p class="mt-2 text-sm text-base-content/70">
              <%= if @action == :new do %>
                Add a new sponsor and track their progress through the pipeline.
              <% else %>
                Update sponsor information and pipeline status.
              <% end %>
            </p>
          </div>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
          <.form for={@form} id="sponsor-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <h3 class="text-lg font-medium text-base-content mb-4">Basic Information</h3>
              </div>

              <.input field={@form[:name]} type="text" label="Sponsor Name" required />
              <.input field={@form[:sponsorship_level]} type="text" label="Sponsorship Level" />

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-base-content mb-4">User Account</h3>
              </div>

              <div class="sm:col-span-2">
                <%= if @connected_user do %>
                  <div class="flex items-center gap-3 mb-4 p-3 bg-success/10 border border-success/30 rounded-lg">
                    <.icon name="hero-check-circle" class="h-5 w-5 text-success" />
                    <div>
                      <p class="text-sm font-medium text-success">Connected to user account</p>
                      <p class="text-sm text-success/70">{@connected_user.email}</p>
                    </div>
                  </div>
                <% end %>
                <.input
                  name="invite_email"
                  type="email"
                  label={if @connected_user, do: "Change user (email)", else: "Invite user (email)"}
                  value={@invite_email}
                  placeholder="Enter email to connect or invite a user"
                />
                <p class="mt-1 text-xs text-base-content/50">
                  If the user exists, they will be linked directly. Otherwise, a magic link invite will be sent.
                </p>
              </div>

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-base-content mb-4">Outreach</h3>
              </div>

              <div class="sm:col-span-2">
                <.input
                  field={@form[:outreach]}
                  type="textarea"
                  label="Outreach Details"
                  placeholder="Where and how was initial outreach done?"
                />
              </div>

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-base-content mb-4">Pipeline Checkpoints</h3>
              </div>

              <.input field={@form[:responded]} type="checkbox" label="Responded" />
              <.input field={@form[:interested]} type="checkbox" label="Interested" />
              <.input field={@form[:confirmed]} type="checkbox" label="Confirmed (said yes)" />
              <.input field={@form[:logos_received]} type="checkbox" label="Logos received" />
              <.input field={@form[:announced]} type="checkbox" label="Announced" />
            </div>

            <div :if={@form.errors != []} class="mt-8 flex space-x-3">
              <p :for={{_key, {error, _}} <- @form.errors} class="text-error">
                {error}
              </p>
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link
                navigate={~p"/sponsors"}
                class="btn btn-ghost"
              >
                Cancel
              </.link>
              <.button
                type="submit"
                phx-disable-with="Saving..."
                class="btn btn-primary"
              >
                {if @action == :new, do: "Create Sponsor", else: "Update Sponsor"}
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params} = all_params, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    invite_email = Map.get(all_params, "invite_email", socket.assigns.invite_email)
    {:noreply, socket |> assign(:form, form) |> assign(:invite_email, invite_email)}
  end

  def handle_event("save", %{"form" => params} = all_params, socket) do
    invite_email = Map.get(all_params, "invite_email", "") |> String.trim()

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, sponsor} ->
        socket = handle_invite_email(socket, sponsor, invite_email)

        action_text = if socket.assigns.action == :new, do: "created", else: "updated"

        socket =
          socket
          |> put_flash(:info, "Sponsor #{action_text} successfully")
          |> push_navigate(to: ~p"/sponsors")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp handle_invite_email(socket, _sponsor, ""), do: socket

  defp handle_invite_email(socket, sponsor, email) do
    actor = socket.assigns.current_user

    case Gut.Accounts.get_user_by_email(email, actor: actor) do
      {:ok, user} ->
        Gut.Conference.update_sponsor!(sponsor, %{user_id: user.id}, actor: actor)
        Gut.Accounts.update_user!(user, %{role: :sponsor}, actor: actor)
        socket

      {:error, _} ->
        Gut.Accounts.request_magic_link(email)

        Gut.Accounts.create_invite!(
          %{email: email, resource_type: :sponsor, resource_id: sponsor.id},
          actor: actor
        )

        put_flash(socket, :info, "Invite sent to #{email}")
    end
  end
end
