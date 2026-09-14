defmodule Gut.Conference.Checks.ActorOrganizesWorkshop do
  @moduledoc """
  Policy check that passes when the actor is a user linked to a speaker of
  the workshop a record is being created for (read from the changeset's
  `workshop_id` attribute).

  Shared by surveys and blasts, which are both created per workshop by its
  organizers.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor is a speaker on the record's workshop"

  @impl true
  def match?(%{id: user_id}, %{subject: %Ash.Changeset{} = changeset}, _opts)
      when is_binary(user_id) do
    case Ash.Changeset.get_attribute(changeset, :workshop_id) do
      nil ->
        false

      workshop_id ->
        Gut.Conference.WorkshopSpeaker
        |> Ash.Query.filter(workshop_id == ^workshop_id and speaker.user_id == ^user_id)
        |> Ash.exists?(authorize?: false)
    end
  end

  def match?(_, _, _), do: false
end
