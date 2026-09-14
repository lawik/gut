defmodule Gut.Conference.Blast.Changes.SendToAttendees do
  @moduledoc """
  Enqueues a blast email job for every registered attendee of the workshop
  when the blast is created.

  Jobs are inserted in the same transaction as the blast, so the blast only
  exists together with its queued emails, and delivery failures are retried
  per recipient by Oban.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, blast ->
      participations =
        Gut.Conference.WorkshopParticipation
        |> Ash.Query.filter(workshop_id == ^blast.workshop_id and status == :registered)
        |> Ash.Query.load(workshop_participant: [:user])
        |> Ash.read!(authorize?: false)

      enqueued =
        for %{workshop_participant: %{user: %{email: email}}} <- participations,
            not is_nil(email) do
          %{"blast_id" => blast.id, "email" => to_string(email)}
          |> Gut.Workers.BlastEmail.new()
          |> Oban.insert!()
        end

      # Participants without a linked user cannot be emailed; expose the
      # counts so the organizer can see who was skipped.
      blast =
        blast
        |> Ash.Resource.put_metadata(:emails_enqueued, length(enqueued))
        |> Ash.Resource.put_metadata(:registered_count, length(participations))

      {:ok, blast}
    end)
  end
end
