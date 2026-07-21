defmodule Gut.Conference.Survey.Changes.SendToAttendees do
  @moduledoc """
  Enqueues a survey invitation email job for every registered attendee of
  the workshop when the survey is marked as sent.

  Jobs are inserted in the same transaction as the status change, so the
  survey only becomes :sent together with its queued invitations, and
  delivery failures are retried per recipient by Oban.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, survey ->
      participations =
        Gut.Conference.WorkshopParticipation
        |> Ash.Query.filter(workshop_id == ^survey.workshop_id and status == :registered)
        |> Ash.Query.load(workshop_participant: [:user])
        |> Ash.read!(authorize?: false)

      for %{workshop_participant: %{user: %{email: email}}} <- participations,
          not is_nil(email) do
        %{"survey_id" => survey.id, "email" => to_string(email)}
        |> Gut.Workers.SurveyInvite.new()
        |> Oban.insert!()
      end

      {:ok, survey}
    end)
  end
end
