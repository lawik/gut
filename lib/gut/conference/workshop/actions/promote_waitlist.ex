defmodule Gut.Conference.Workshop.Actions.PromoteWaitlist do
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, context) do
    wid = input.arguments.workshop_id

    workshop =
      Ash.get!(Gut.Conference.Workshop, wid,
        load: [:workshop_room],
        actor: context.actor
      )

    effective_limit =
      if workshop.workshop_room do
        min(workshop.limit, workshop.workshop_room.limit)
      else
        workshop.limit
      end

    registered_count =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_id == ^wid and status == :registered)
      |> Ash.count!(actor: context.actor)

    available_spots = max(effective_limit - registered_count, 0)

    waitlisted =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_id == ^wid and status == :waitlisted)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(available_spots)
      |> Ash.read!(actor: context.actor)

    Enum.each(waitlisted, fn participation ->
      Ash.update!(
        Ash.Changeset.for_update(participation, :update, %{status: :registered}),
        actor: context.actor
      )
    end)

    {:ok, length(waitlisted)}
  end
end
