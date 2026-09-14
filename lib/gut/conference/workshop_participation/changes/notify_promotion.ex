defmodule Gut.Conference.WorkshopParticipation.Changes.NotifyPromotion do
  @moduledoc """
  Enqueues a promotion email when a participation moves from the waitlist
  to registered, so the attendee learns they now have a seat.

  Only fires on the waitlisted -> registered transition of an existing
  participation. Participants without a linked user email are skipped.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, participation ->
      if changeset.data.status == :waitlisted and participation.status == :registered do
        %{"participation_id" => participation.id}
        |> Gut.Workers.PromotionEmail.new()
        |> Oban.insert!()
      end

      {:ok, participation}
    end)
  end
end
