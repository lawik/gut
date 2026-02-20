defmodule GutWeb.MySponsorLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Sponsor Portal")
      |> assign(:current_scope, nil)

    {:ok, socket}
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
        <div class="text-center py-16">
          <h1 class="text-2xl font-semibold leading-6 text-base-content">Sponsor Portal</h1>
          <p class="mt-4 text-sm text-base-content/70">
            More information coming soon.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
