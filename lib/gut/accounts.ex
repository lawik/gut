defmodule Gut.Accounts do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain, AshAi]

  admin do
    show? true
  end

  resources do
    resource Gut.Accounts.Token

    resource Gut.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :destroy_api_key, action: :destroy
      define :list_api_keys_for_user, action: :for_user, args: [:user_id]
    end

    resource Gut.Accounts.User do
      define :create_user, action: :create, args: [:email, :role]
      define :update_user, action: :update
      define :destroy_user, action: :destroy
      define :get_user, action: :read, get_by: [:id]
      define :sign_in_with_magic_link, action: :sign_in_with_magic_link, args: [:token]
      define :request_magic_link, action: :request_magic_link, args: [:email]
      define :get_user_by_email, action: :get_by_email, args: [:email]
      define :get_user_by_subject, action: :get_by_subject, args: [:subject]
      define :list_users, action: :read
    end
  end

  def magic_link_url(email) do
    strategy = AshAuthentication.Info.strategy!(Gut.Accounts.User, :magic_link)

    case AshAuthentication.Strategy.MagicLink.request_token_for_identity(
           strategy,
           to_string(email)
         ) do
      {:ok, token} -> {:ok, GutWeb.Endpoint.url() <> "/magic_link/#{token}"}
      error -> error
    end
  end
end
