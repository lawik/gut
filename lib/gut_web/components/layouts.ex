defmodule GutWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GutWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil, doc: "the current user"
  attr :page_title, :string, default: ""

  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:git_sha, git_sha())
      |> assign(:staff?, assigns[:current_user] && assigns[:current_user].role == :staff)

    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <div class="flex-1 flex w-fit items-center gap-2">
          <a href="/">
            {Application.get_env(:gut, :page_name)}
          </a>
          <a href="#" class="font-bold">{assigns[:page_title]}</a>
          <span :if={@git_sha != ""} class="text-xs font-mono text-gray-400">{@git_sha}</span>
        </div>
      </div>
      <div class="flex-none flex items-center gap-2">
        <%!-- Mobile hamburger menu --%>
        <div :if={@staff?} class="dropdown dropdown-end sm:hidden">
          <div tabindex="0" role="button" class="btn btn-ghost btn-circle">
            <.icon name="hero-bars-3" class="size-5" />
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box z-10 w-52 p-2 shadow"
          >
            <li><.link navigate={~p"/speakers"}>Speakers</.link></li>
            <li><.link navigate={~p"/sponsors"}>Sponsors</.link></li>
            <li><.link navigate={~p"/workshops"}>Workshops</.link></li>
            <li><.link navigate={~p"/users"}>Users</.link></li>
            <li class="menu-title">Create</li>
            <li>
              <.link navigate={~p"/speakers/new"}>
                <.icon name="hero-microphone" class="size-4" /> New Speaker
              </.link>
            </li>
            <li>
              <.link navigate={~p"/sponsors/new"}>
                <.icon name="hero-currency-dollar" class="size-4" /> New Sponsor
              </.link>
            </li>
            <li>
              <.link navigate={~p"/users/new"}>
                <.icon name="hero-user-plus" class="size-4" /> Invite User
              </.link>
            </li>
          </ul>
        </div>
        <%!-- Desktop nav --%>
        <ul :if={@staff?} class="hidden sm:flex px-1 space-x-4 items-center">
          <li>
            <.link navigate={~p"/speakers"} class="btn btn-ghost">Speakers</.link>
          </li>
          <li>
            <.link navigate={~p"/sponsors"} class="btn btn-ghost">Sponsors</.link>
          </li>
          <li>
            <.link navigate={~p"/workshops"} class="btn btn-ghost">Workshops</.link>
          </li>
          <li>
            <.link navigate={~p"/users"} class="btn btn-ghost">Users</.link>
          </li>
          <li>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-circle">
                <.icon name="hero-plus" class="size-5" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-100 rounded-box z-10 w-48 p-2 shadow"
              >
                <li>
                  <.link navigate={~p"/speakers/new"}>
                    <.icon name="hero-microphone" class="size-4" /> New Speaker
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/sponsors/new"}>
                    <.icon name="hero-currency-dollar" class="size-4" /> New Sponsor
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/users/new"}>
                    <.icon name="hero-user-plus" class="size-4" /> Invite User
                  </.link>
                </li>
              </ul>
            </div>
          </li>
        </ul>
        <.theme_toggle />
      </div>
    </header>

    <main class="">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  attr :active, :string, required: true, doc: "the active tab"

  def workshop_subnav(assigns) do
    ~H"""
    <div class="border-b border-base-300 px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
        <nav class="flex overflow-x-auto overflow-y-hidden -mb-px" aria-label="Workshop navigation">
          <.subnav_tab label="Workshops" href={~p"/workshops"} active={@active == "workshops"} />
          <.subnav_tab label="Rooms" href={~p"/workshop-rooms"} active={@active == "rooms"} />
          <.subnav_tab
            label="Timeslots"
            href={~p"/workshop-timeslots"}
            active={@active == "timeslots"}
          />
          <.subnav_tab
            label="Participants"
            href={~p"/workshop-participants"}
            active={@active == "participants"}
          />
        </nav>
        <div class="flex flex-wrap gap-2 py-2">
          <.link navigate={~p"/workshops/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="h-3 w-3 mr-1" /> Workshop
          </.link>
          <.link navigate={~p"/workshop-rooms/new"} class="btn btn-ghost btn-sm">
            <.icon name="hero-plus" class="h-3 w-3 mr-1" /> Room
          </.link>
          <.link navigate={~p"/workshop-timeslots/new"} class="btn btn-ghost btn-sm">
            <.icon name="hero-plus" class="h-3 w-3 mr-1" /> Timeslot
          </.link>
          <.link navigate={~p"/workshop-participants/new"} class="btn btn-ghost btn-sm">
            <.icon name="hero-plus" class="h-3 w-3 mr-1" /> Participant
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp subnav_tab(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "px-3 py-3 text-sm font-medium border-b-2 -mb-px",
        if(@active,
          do: "border-primary text-primary",
          else:
            "border-transparent text-base-content/60 hover:text-base-content hover:border-base-300"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  defp git_sha do
    System.get_env("GIT_SHA", "")
  end
end
