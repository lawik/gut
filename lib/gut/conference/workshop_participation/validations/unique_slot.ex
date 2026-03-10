defmodule Gut.Conference.WorkshopParticipation.Validations.UniqueSlot do
  use Ash.Resource.Validation

  require Ash.Query

  @system_actor Gut.system_actor("unique_slot_validation")

  @impl true
  def validate(changeset, _opts, _context) do
    workshop_id = Ash.Changeset.get_attribute(changeset, :workshop_id)
    participant_id = Ash.Changeset.get_attribute(changeset, :workshop_participant_id)

    workshop = Ash.get!(Gut.Conference.Workshop, workshop_id, actor: @system_actor)

    if workshop.workshop_timeslot_id do
      same_slot_workshop_ids =
        Gut.Conference.Workshop
        |> Ash.Query.filter(
          workshop_timeslot_id == ^workshop.workshop_timeslot_id and id != ^workshop_id
        )
        |> Ash.read!(actor: @system_actor)
        |> Enum.map(& &1.id)

      if same_slot_workshop_ids != [] do
        existing =
          Gut.Conference.WorkshopParticipation
          |> Ash.Query.filter(
            workshop_participant_id == ^participant_id and
              workshop_id in ^same_slot_workshop_ids
          )
          |> Ash.read!(actor: @system_actor)

        if existing != [] do
          {:error,
           field: :workshop_id, message: "participant already has a registration in this timeslot"}
        else
          :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end
end
