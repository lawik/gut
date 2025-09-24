defmodule Gut.Accounts do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Gut.Accounts.Token

    resource Gut.Accounts.User do
      define :create_user, action: :create, args: [:email]
      define :sign_in_with_magic_link, action: :sign_in_with_magic_link, args: [:token]
      define :request_magic_link, action: :request_magic_link, args: [:email]
      define :get_user_by_email, action: :get_by_email, args: [:email]
      define :get_user_by_subject, action: :get_by_subject, args: [:subject]
      define :list_users, action: :read
    end
  end
end
