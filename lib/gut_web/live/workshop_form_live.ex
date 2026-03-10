defmodule GutWeb.WorkshopFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    workshop =
      Gut.Conference.get_workshop!(id,
        actor: socket.assigns.current_user,
        load: [:workshop_room, :workshop_timeslot]
      )

    form =
      AshPhoenix.Form.for_update(workshop, :update, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Editing #{workshop.name}")
      |> assign(:workshop, workshop)
      |> assign(:form, form)
      |> assign(:action, :edit)
      |> assign(:current_scope, nil)
      |> load_options()

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.Workshop, :create,
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new workshop")
      |> assign(:workshop, nil)
      |> assign(:form, form)
      |> assign(:action, :new)
      |> assign(:current_scope, nil)
      |> load_options()

    {:ok, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp load_options(socket) do
    actor = socket.assigns.current_user

    rooms = Gut.Conference.list_workshop_rooms!(actor: actor)
    timeslots = Gut.Conference.list_workshop_timeslots!(actor: actor)

    socket
    |> assign(:rooms, rooms)
    |> assign(:timeslots, timeslots)
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
            navigate={~p"/workshops"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Workshops
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-base-content">{@page_title}</h1>
          </div>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
          <.form for={@form} id="workshop-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <.input field={@form[:name]} type="text" label="Workshop Name" required />
              </div>

              <div class="sm:col-span-2">
                <.input
                  field={@form[:description]}
                  type="textarea"
                  label="Description"
                />
              </div>

              <.input field={@form[:limit]} type="number" label="Participant Limit" required />

              <.input
                field={@form[:workshop_room_id]}
                type="select"
                label="Room"
                options={[{"-- Select Room --", ""} | Enum.map(@rooms, &{&1.name, &1.id})]}
              />

              <.input
                field={@form[:workshop_timeslot_id]}
                type="select"
                label="Timeslot"
                options={[{"-- Select Timeslot --", ""} | Enum.map(@timeslots, &{&1.name, &1.id})]}
              />
            </div>

            <div :if={@form.errors != []} class="mt-8 flex space-x-3">
              <p :for={{_key, {error, _}} <- @form.errors} class="text-error">
                {error}
              </p>
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link navigate={~p"/workshops"} class="btn btn-ghost">
                Cancel
              </.link>
              <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
                {if @action == :new, do: "Create Workshop", else: "Update Workshop"}
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _workshop} ->
        action_text = if socket.assigns.action == :new, do: "created", else: "updated"

        socket =
          socket
          |> put_flash(:info, "Workshop #{action_text} successfully")
          |> push_navigate(to: ~p"/workshops")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
