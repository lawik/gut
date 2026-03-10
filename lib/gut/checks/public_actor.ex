defmodule Gut.Checks.PublicActor do
  @moduledoc """
  Policy check that passes when the actor is a public actor.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a public actor"

  @impl true
  def match?(%{type: :public}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
