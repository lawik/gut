defmodule Gut.Conference.Sponsor do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "sponsors"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :outreach,
        :responded,
        :interested,
        :confirmed,
        :sponsorship_level,
        :logos_received,
        :announced,
        :user_id
      ]
    end

    update :update do
      accept [
        :name,
        :outreach,
        :responded,
        :interested,
        :confirmed,
        :sponsorship_level,
        :logos_received,
        :announced,
        :user_id
      ]
    end
  end

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "sponsors"
    publish :create, ["changed"]
    publish :update, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :outreach, :string do
      public? true
    end

    attribute :responded, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :interested, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :confirmed, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :sponsorship_level, :string do
      public? true
    end

    attribute :logos_received, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :announced, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Gut.Accounts.User do
      public? true
    end
  end
end
