defmodule GutWeb.SpeakerFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    speaker =
      Gut.Conference.get_speaker!(id,
        actor: socket.assigns.current_user,
        load: [:user]
      )

    form =
      AshPhoenix.Form.for_update(speaker, :update, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Editing #{speaker.full_name}")
      |> assign(:speaker, speaker)
      |> assign(:form, form)
      |> assign(:action, :edit)
      |> assign(:current_scope, nil)
      |> assign(:invite_email, "")
      |> assign(:connected_user, speaker.user)

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.Speaker, :create,
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new speaker")
      |> assign(:speaker, nil)
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
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/speakers"}
            class="inline-flex items-center text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Speakers
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-gray-900">{@page_title}</h1>
            <p class="mt-2 text-sm text-gray-700">
              <%= if @action == :new do %>
                Add a new speaker with their travel and hotel information.
              <% else %>
                Update speaker information including travel and hotel details.
              <% end %>
            </p>
          </div>
        </div>

        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 rounded-xl p-6">
          <.form for={@form} id="speaker-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h3>
              </div>

              <.input field={@form[:full_name]} type="text" label="Full Name" required />
              <div></div>
              <.input field={@form[:first_name]} type="text" label="First Name" required />
              <.input field={@form[:last_name]} type="text" label="Last Name" required />

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-gray-900 mb-4">User Account</h3>
              </div>

              <div class="sm:col-span-2">
                <%= if @connected_user do %>
                  <div class="flex items-center gap-3 mb-4 p-3 bg-green-50 border border-green-200 rounded-lg">
                    <.icon name="hero-check-circle" class="h-5 w-5 text-green-600" />
                    <div>
                      <p class="text-sm font-medium text-green-900">Connected to user account</p>
                      <p class="text-sm text-green-700">{@connected_user.email}</p>
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
                <p class="mt-1 text-xs text-gray-500">
                  If the user exists, they will be linked directly. Otherwise, a magic link invite will be sent.
                </p>
              </div>

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Travel Information</h3>
              </div>

              <.input field={@form[:arrival_date]} type="date" label="Arrival Date" />
              <.input field={@form[:arrival_time]} type="time" label="Arrival Time" />
              <.input field={@form[:leaving_date]} type="date" label="Departure Date" />
              <.input field={@form[:leaving_time]} type="time" label="Departure Time" />

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Hotel Information</h3>
              </div>

              <.input field={@form[:hotel_stay_start_date]} type="date" label="Hotel Stay Start" />
              <.input field={@form[:hotel_stay_end_date]} type="date" label="Hotel Stay End" />
              <.input
                field={@form[:hotel_covered_start_date]}
                type="date"
                label="Hotel Coverage Start"
              />
              <.input
                field={@form[:hotel_covered_end_date]}
                type="date"
                label="Hotel Coverage End"
              />
            </div>

            <div :if={@form.errors != []} class="mt-8 flex space-x-3">
              <p :for={{_key, {error, _}} <- @form.errors} class="text-red-500">
                {error}
              </p>
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link
                navigate={~p"/speakers"}
                class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Cancel
              </.link>
              <.button
                type="submit"
                phx-disable-with="Saving..."
                class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                {if @action == :new, do: "Create Speaker", else: "Update Speaker"}
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
      {:ok, speaker} ->
        socket = handle_invite_email(socket, speaker, invite_email)

        action_text = if socket.assigns.action == :new, do: "created", else: "updated"

        socket =
          socket
          |> put_flash(:info, "Speaker #{action_text} successfully")
          |> push_navigate(to: ~p"/speakers")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp handle_invite_email(socket, _speaker, ""), do: socket

  defp handle_invite_email(socket, speaker, email) do
    actor = socket.assigns.current_user

    case Gut.Accounts.get_user_by_email(email, actor: actor) do
      {:ok, user} ->
        Gut.Conference.update_speaker!(speaker, %{user_id: user.id}, actor: actor)
        Gut.Accounts.update_user!(user, %{role: :speaker}, actor: actor)
        socket

      {:error, _} ->
        Gut.Accounts.request_magic_link(email)

        Gut.Accounts.create_invite!(
          %{email: email, resource_type: :speaker, resource_id: speaker.id},
          actor: actor
        )

        put_flash(socket, :info, "Invite sent to #{email}")
    end
  end
end
