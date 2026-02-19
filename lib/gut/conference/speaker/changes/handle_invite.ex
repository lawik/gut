defmodule Gut.Conference.Speaker.Changes.HandleInvite do
  @moduledoc """
  After a speaker is created or updated, if an `email` argument is provided,
  links an existing user or creates an invite with a magic link.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, speaker ->
      case Ash.Changeset.get_argument(changeset, :email) do
        nil -> {:ok, speaker}
        "" -> {:ok, speaker}
        email -> handle_email(speaker, email)
      end
    end)
  end

  defp handle_email(speaker, email) do
    case Gut.Accounts.get_user_by_email(email, authorize?: false) do
      {:ok, user} ->
        speaker = Gut.Conference.update_speaker!(speaker, %{user_id: user.id}, authorize?: false)
        Gut.Accounts.update_user!(user, %{role: :speaker}, authorize?: false)
        {:ok, speaker}

      {:error, _} ->
        Gut.Accounts.request_magic_link(email)

        Gut.Accounts.create_invite!(
          %{email: email, resource_type: :speaker, resource_id: speaker.id},
          authorize?: false
        )

        {:ok, speaker}
    end
  end
end
