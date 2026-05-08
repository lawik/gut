defmodule Gut.Conference.Speaker.Validations.ContractApproved do
  @moduledoc """
  Ensures the speaker has approved the contract before allowing
  travel or hotel-request updates.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_data(changeset, :contract_approved_at) do
      nil ->
        {:error, field: :contract_approved_at, message: "Speaker contract must be approved first"}

      _ ->
        :ok
    end
  end
end
