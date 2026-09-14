defmodule Gut.Conference.StatusMailing.Changes.SendToParticipants do
  @moduledoc """
  Enqueues one status email job per reachable workshop participant when a
  status mailing is created.

  Reachable means the participant is linked to a user with an email address
  and has at least one workshop participation (registered or waitlisted).
  The recipient count is stored on the mailing; jobs are inserted in the
  same transaction so the record and its queue agree.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      recipients = Gut.Emails.WorkshopStatus.recipients()

      changeset
      |> Ash.Changeset.force_change_attribute(:recipient_count, length(recipients))
      |> Ash.Changeset.put_context(:status_mailing_recipients, recipients)
    end)
    |> Ash.Changeset.after_action(fn changeset, mailing ->
      for participant <- changeset.context[:status_mailing_recipients] || [] do
        %{"mailing_id" => mailing.id, "participant_id" => participant.id}
        |> Gut.Workers.StatusEmail.new()
        |> Oban.insert!()
      end

      {:ok, mailing}
    end)
  end
end
