defmodule Gut.Accounts do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Gut.Accounts.Token
    resource Gut.Accounts.User

    resource Gut.Accounts.Speaker do
      define :list_speakers, action: :read
      define :get_speaker, action: :read, get_by: [:id]
      define :create_speaker, action: :create
      define :update_speaker, action: :update
      define :destroy_speaker, action: :destroy
    end
  end
end
