defmodule GutWeb.SponsorFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    sponsor = Gut.Conference.get_sponsor!(id, actor: socket.assigns.current_user)

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

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form = AshPhoenix.Form.for_create(Gut.Conference.Sponsor, :create) |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new sponsor")
      |> assign(:sponsor, nil)
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
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/sponsors"}
            class="inline-flex items-center text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Sponsors
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-gray-900">{@page_title}</h1>
            <p class="mt-2 text-sm text-gray-700">
              <%= if @action == :new do %>
                Add a new sponsor and track their progress through the pipeline.
              <% else %>
                Update sponsor information and pipeline status.
              <% end %>
            </p>
          </div>
        </div>

        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 rounded-xl p-6">
          <.form for={@form} id="sponsor-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h3>
              </div>

              <.input field={@form[:name]} type="text" label="Sponsor Name" required />
              <.input field={@form[:sponsorship_level]} type="text" label="Sponsorship Level" />

              <div class="sm:col-span-2 mt-8">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Outreach</h3>
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
                <h3 class="text-lg font-medium text-gray-900 mb-4">Pipeline Checkpoints</h3>
              </div>

              <.input field={@form[:responded]} type="checkbox" label="Responded" />
              <.input field={@form[:interested]} type="checkbox" label="Interested" />
              <.input field={@form[:confirmed]} type="checkbox" label="Confirmed (said yes)" />
              <.input field={@form[:logos_received]} type="checkbox" label="Logos received" />
              <.input field={@form[:announced]} type="checkbox" label="Announced" />
            </div>

            <div :if={@form.errors != []} class="mt-8 flex space-x-3">
              <p :for={{_key, {error, _}} <- @form.errors} class="text-red-500">
                {error}
              </p>
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link
                navigate={~p"/sponsors"}
                class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Cancel
              </.link>
              <.button
                type="submit"
                phx-disable-with="Saving..."
                class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
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

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params
         ) do
      {:ok, _sponsor} ->
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
end
