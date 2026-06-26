defmodule GutWeb.CinderTheme do
  @moduledoc """
  Cinder table theme: daisyUI base with a couple of filter overrides.

  Defined directly rather than via `use Cinder.Theme` + `extends :daisy_ui`.
  That macro generates `base_theme || Cinder.Theme.default()` where `base_theme`
  is a literal map, so Elixir 1.20's type checker flags the dead `||` branch and
  `mix compile --warnings-as-errors` fails. Building the map here is equivalent
  to what the macro produces (cinder applies overrides via `Map.put`) and keeps
  cinder pinned where it is. Revisit if cinder is upgraded past 0.9.
  """
  @behaviour Cinder.Theme.Behaviour

  @impl true
  def resolve_theme, do: __theme_config()

  def __theme_config do
    Cinder.Themes.DaisyUI.resolve_theme()
    |> Map.merge(%{
      filter_container_class: "card bg-base-100",
      filter_header_class: "hidden"
    })
  end
end
