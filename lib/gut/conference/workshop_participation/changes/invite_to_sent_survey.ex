defmodule Gut.Conference.WorkshopParticipation.Changes.InviteToSentSurvey do
  @moduledoc """
  Enqueues a survey invitation when someone becomes a registered attendee
  of a workshop whose survey has already been sent.

  Covers registrations made after the send (browse flow or staff-created)
  and waitlist promotions. The invite worker's uniqueness on survey and
  email prevents double invitations.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, participation ->
      if became_registered?(changeset, participation) do
        maybe_enqueue_invite(participation)
      end

      {:ok, participation}
    end)
  end

  defp became_registered?(changeset, participation) do
    participation.status == :registered and
      (changeset.action_type == :create or changeset.data.status != :registered)
  end

  defp maybe_enqueue_invite(participation) do
    survey =
      Gut.Conference.Survey
      |> Ash.Query.filter(workshop_id == ^participation.workshop_id and status == :sent)
      |> Ash.read_one!(authorize?: false)

    with %{} <- survey,
         {:ok, %{user: %{email: email}}} when not is_nil(email) <-
           Ash.get(Gut.Conference.WorkshopParticipant, participation.workshop_participant_id,
             load: [:user],
             authorize?: false
           ) do
      %{"survey_id" => survey.id, "email" => to_string(email)}
      |> Gut.Workers.SurveyInvite.new()
      |> Oban.insert!()
    end

    :ok
  end
end
