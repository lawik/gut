defmodule Gut.Conference.WorkshopParticipation.Changes.DetermineStatus do
  use Ash.Resource.Change

  require Ash.Query

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      workshop_id = Ash.Changeset.get_attribute(changeset, :workshop_id)

      workshop =
        Ash.get!(Gut.Conference.Workshop, workshop_id,
          authorize?: false,
          load: [:workshop_room]
        )

      effective_limit =
        if workshop.workshop_room do
          min(workshop.limit, workshop.workshop_room.limit)
        else
          workshop.limit
        end

      current_registrations =
        Gut.Conference.WorkshopParticipation
        |> Ash.Query.filter(workshop_id == ^workshop_id and status == :registered)
        |> Ash.count!(authorize?: false)

      status =
        if current_registrations < effective_limit do
          :registered
        else
          :waitlisted
        end

      Ash.Changeset.force_change_attribute(changeset, :status, status)
    end)
  end
end
