defmodule Gut.Checks.StaffActor do
  @moduledoc """
  Policy check that passes when the actor has the staff role.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a staff user"

  @impl true
  def match?(%{role: :staff}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
