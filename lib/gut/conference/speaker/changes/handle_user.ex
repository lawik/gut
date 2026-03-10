defmodule Gut.Conference.Speaker.Changes.HandleUser do
  @moduledoc """
  When a speaker is created or updated with an `email` argument,
  links an existing user or creates a new one with the `:speaker` role.

  Sets user_id directly on the changeset to avoid nested action calls.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :email) do
      nil -> changeset
      "" -> changeset
      email -> set_user(changeset, email)
    end
  end

  @system_actor Gut.system_actor("speaker_handle_user")

  defp set_user(changeset, email) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      user =
        case Gut.Accounts.get_user_by_email(email, actor: @system_actor) do
          {:ok, user} ->
            Gut.Accounts.update_user!(user, %{role: :speaker}, actor: @system_actor)

          {:error, _} ->
            Gut.Accounts.create_user!(email, :speaker, actor: @system_actor)
        end

      Ash.Changeset.force_change_attribute(changeset, :user_id, user.id)
    end)
  end
end
