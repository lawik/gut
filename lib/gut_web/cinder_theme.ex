defmodule GutWeb.CinderTheme do
  use Cinder.Theme
  extends :daisy_ui

  component Cinder.Components.Filters do
    set :filter_container_class, "card bg-base-100"
    set :filter_header_class, "hidden"
  end
end
