defmodule GutWeb.WorkshopRoomFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_staff_required}

  def mount(%{"id" => id}, _session, socket) do
    room = Gut.Conference.get_workshop_room!(id, actor: socket.assigns.current_user)

    form =
      AshPhoenix.Form.for_update(room, :update, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Editing #{room.name}")
      |> assign(:room, room)
      |> assign(:form, form)
      |> assign(:action, :edit)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Conference.WorkshopRoom, :create,
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new room")
      |> assign(:room, nil)
      |> assign(:form, form)
      |> assign(:action, :new)
      |> assign(:current_scope, nil)

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
            navigate={~p"/workshop-rooms"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Rooms
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-base-content">{@page_title}</h1>
          </div>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
          <.form for={@form} id="workshop-room-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <.input field={@form[:name]} type="text" label="Room Name" required />
              <.input field={@form[:limit]} type="number" label="Capacity" required />
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link navigate={~p"/workshop-rooms"} class="btn btn-ghost">
                Cancel
              </.link>
              <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
                {if @action == :new, do: "Create Room", else: "Update Room"}
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
      {:ok, _room} ->
        action_text = if socket.assigns.action == :new, do: "created", else: "updated"

        socket =
          socket
          |> put_flash(:info, "Room #{action_text} successfully")
          |> push_navigate(to: ~p"/workshop-rooms")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
