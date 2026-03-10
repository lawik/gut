defmodule Gut.Conference.WorkshopParticipant.Changes.HandleUser do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :email) do
      nil -> changeset
      "" -> changeset
      email -> set_user(changeset, email)
    end
  end

  defp set_user(changeset, email) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      user =
        case Gut.Accounts.get_user_by_email(email, authorize?: false) do
          {:ok, user} ->
            user

          {:error, _} ->
            Gut.Accounts.create_user!(email, :staff, authorize?: false)
        end

      Ash.Changeset.force_change_attribute(changeset, :user_id, user.id)
    end)
  end
end
