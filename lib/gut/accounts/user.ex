defmodule Gut.Accounts.User do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module GutWeb.Endpoint
    prefix "users"
    publish :create, ["changed"]
    publish :update, ["changed"]
    publish :destroy, ["changed"]
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Gut.Accounts.Token
      signing_secret Gut.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? false
        require_interaction? true

        sender Gut.Accounts.User.Senders.SendMagicLinkEmail
      end

      api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end
  end

  postgres do
    table "users"
    repo Gut.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:email, :role]
      primary? true
    end

    update :update do
      accept [:email, :role]
    end

    destroy :destroy

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    read :sign_in_with_magic_link do
      description "Sign in an existing user with magic link."
      get? true

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      prepare AshAuthentication.Strategy.MagicLink.SignInPreparation

      metadata :token, :string do
        allow_nil? false
      end
    end

    read :sign_in_with_api_key do
      argument :api_key, :string, allow_nil?: false
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      constraints one_of: [:staff, :speaker, :sponsor]
      allow_nil? false
      public? true
      default :staff
    end
  end

  relationships do
    has_many :valid_api_keys, Gut.Accounts.ApiKey do
      filter expr(valid)
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
