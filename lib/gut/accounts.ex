defmodule Gut.Accounts do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Gut.Accounts.Token
    resource Gut.Accounts.User
    resource Gut.Accounts.Speaker
  end
end
