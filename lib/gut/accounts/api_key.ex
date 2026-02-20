defmodule Gut.Accounts.ApiKey do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :expires_at]

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey, prefix: :gut, hash: :api_key_hash}
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Gut.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
