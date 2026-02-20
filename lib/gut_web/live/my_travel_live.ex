defmodule GutWeb.MyTravelLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    case Gut.Conference.get_own_speaker(actor: user) do
      {:ok, speaker} ->
        form =
          AshPhoenix.Form.for_update(speaker, :update_travel, actor: user)
          |> to_form()

        socket =
          socket
          |> assign(:page_title, "My Travel Details")
          |> assign(:speaker, speaker)
          |> assign(:form, form)
          |> assign(:current_scope, nil)

        {:ok, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "No speaker profile found for your account.")
          |> assign(:page_title, "My Travel Details")
          |> assign(:speaker, nil)
          |> assign(:form, nil)
          |> assign(:current_scope, nil)

        {:ok, socket}
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
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-2xl mx-auto">
        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-base-content">My Travel Details</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Please provide your arrival and departure information.
            </p>
          </div>
        </div>

        <%= if @speaker do %>
          <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
            <.form for={@form} id="travel-form" phx-change="validate" phx-submit="save">
              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                <.input field={@form[:arrival_date]} type="date" label="Arrival Date" />
                <.input field={@form[:arrival_time]} type="time" label="Arrival Time" />
                <.input field={@form[:leaving_date]} type="date" label="Departure Date" />
                <.input field={@form[:leaving_time]} type="time" label="Departure Time" />
              </div>

              <div class="mt-8 flex justify-end">
                <.button
                  type="submit"
                  phx-disable-with="Saving..."
                  class="btn btn-primary"
                >
                  Save Travel Details
                </.button>
              </div>
            </.form>
          </div>
        <% else %>
          <div class="bg-warning/10 border border-warning/30 rounded-xl p-6 text-center">
            <p class="text-warning">
              No speaker profile is associated with your account. Please contact the organizers.
            </p>
          </div>
        <% end %>
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
      {:ok, speaker} ->
        form =
          AshPhoenix.Form.for_update(speaker, :update_travel, actor: socket.assigns.current_user)
          |> to_form()

        socket =
          socket
          |> assign(:speaker, speaker)
          |> assign(:form, form)
          |> put_flash(:info, "Travel details saved successfully")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
