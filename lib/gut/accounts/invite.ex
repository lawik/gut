defmodule Gut.Accounts.Invite do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "invites"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:email, :resource_type, :resource_id]
    end

    update :accept do
      accept []
      change set_attribute(:accepted, true)
    end

    read :pending_for_email do
      argument :email, :ci_string, allow_nil?: false

      filter expr(email == ^arg(:email) and accepted == false)
    end

    read :for_resource do
      argument :resource_type, :atom, allow_nil?: false
      argument :resource_id, :uuid, allow_nil?: false

      filter expr(resource_type == ^arg(:resource_type) and resource_id == ^arg(:resource_id))
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

  pub_sub do
    module GutWeb.Endpoint
    prefix "invites"
    publish :create, ["changed"]
    publish :accept, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :resource_type, :atom do
      constraints one_of: [:speaker, :sponsor]
      allow_nil? false
      public? true
    end

    attribute :resource_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :accepted, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
