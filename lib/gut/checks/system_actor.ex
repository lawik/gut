defmodule Gut.Checks.SystemActor do
  @moduledoc """
  Policy check that passes when the actor is a system actor.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a system actor"

  @impl true
  def match?(%{type: :system}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
