defmodule Gut.Conference.WorkshopParticipation.Changes.DetermineStatus do
  @moduledoc """
  Decides whether a new registration gets a seat or joins the waitlist.

  A seat is given only when the workshop (capped by its room) has room and
  nobody is already waiting; otherwise the registration is waitlisted so
  freed seats are handed out in waitlist order by `promote_waitlist`.
  """
  use Ash.Resource.Change

  require Ash.Query

  @system_actor Gut.system_actor("determine_status")

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      workshop_id = Ash.Changeset.get_attribute(changeset, :workshop_id)

      workshop =
        Ash.get!(Gut.Conference.Workshop, workshop_id,
          actor: @system_actor,
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
        |> Ash.count!(actor: @system_actor)

      # A free seat belongs to whoever is first on the waitlist, not to a
      # newcomer, so while anyone is waitlisted new registrations queue up
      # behind them until staff promote from the waitlist.
      anyone_waiting? =
        Gut.Conference.WorkshopParticipation
        |> Ash.Query.filter(workshop_id == ^workshop_id and status == :waitlisted)
        |> Ash.exists?(actor: @system_actor)

      status =
        if current_registrations < effective_limit and not anyone_waiting? do
          :registered
        else
          :waitlisted
        end

      Ash.Changeset.force_change_attribute(changeset, :status, status)
    end)
  end
end
