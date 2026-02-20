defmodule GutWeb.UserFormLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(%{"id" => id}, _session, socket) do
    user = Gut.Accounts.get_user!(id, actor: socket.assigns.current_user)

    form =
      AshPhoenix.Form.for_update(user, :update, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Editing #{user.email}")
      |> assign(:user, user)
      |> assign(:form, form)
      |> assign(:action, :edit)
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Gut.Accounts.User, :create, actor: socket.assigns.current_user)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "Adding new user")
      |> assign(:user, nil)
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
            navigate={~p"/users"}
            class="inline-flex items-center text-sm font-medium text-primary hover:text-primary/80"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Users
          </.link>
        </div>

        <div class="sm:flex sm:items-center mb-8">
          <div class="sm:flex-auto">
            <h1 class="text-2xl font-semibold leading-6 text-base-content">{@page_title}</h1>
            <p class="mt-2 text-sm text-base-content/70">
              <%= if @action == :new do %>
                Add a new user to the system.
              <% else %>
                Update user information.
              <% end %>
            </p>
          </div>
        </div>

        <div class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
          <.form for={@form} id="user-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 gap-6">
              <div>
                <h3 class="text-lg font-medium text-base-content mb-4">User Information</h3>
              </div>

              <.input field={@form[:email]} type="email" label="Email Address" required />
              <.input
                field={@form[:role]}
                type="select"
                label="Role"
                options={[{"Staff", "staff"}, {"Speaker", "speaker"}, {"Sponsor", "sponsor"}]}
              />
            </div>

            <div :if={@form.errors != []} class="mt-8 flex space-x-3">
              <p :for={{_key, {error, _}} <- @form.errors} class="text-error">
                {error}
              </p>
            </div>

            <div class="mt-8 flex justify-end space-x-3">
              <.link
                navigate={~p"/users"}
                class="btn btn-ghost"
              >
                Cancel
              </.link>
              <.button
                type="submit"
                phx-disable-with="Saving..."
                class="btn btn-primary"
              >
                {if @action == :new, do: "Create User", else: "Update User"}
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
      {:ok, _user} ->
        action_text = if socket.assigns.action == :new, do: "created", else: "updated"

        socket =
          socket
          |> put_flash(:info, "User #{action_text} successfully")
          |> push_navigate(to: ~p"/users")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
