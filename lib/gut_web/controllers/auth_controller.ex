defmodule GutWeb.AuthController do
  use GutWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    process_pending_invites(user)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:gut)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp process_pending_invites(user) do
    case Gut.Accounts.list_pending_invites_for_email(user.email, actor: user) do
      {:ok, invites} ->
        Enum.each(invites, fn invite ->
          case invite.resource_type do
            :speaker ->
              with {:ok, speaker} <-
                     Gut.Conference.get_speaker(invite.resource_id, actor: user) do
                Gut.Conference.update_speaker!(speaker, %{user_id: user.id}, actor: user)
                Gut.Accounts.update_user!(user, %{role: :speaker}, actor: user)
              end

            :sponsor ->
              with {:ok, sponsor} <-
                     Gut.Conference.get_sponsor(invite.resource_id, actor: user) do
                Gut.Conference.update_sponsor!(sponsor, %{user_id: user.id}, actor: user)
                Gut.Accounts.update_user!(user, %{role: :sponsor}, actor: user)
              end
          end

          Gut.Accounts.accept_invite!(invite, actor: user)
        end)

      _ ->
        :ok
    end
  end
end
