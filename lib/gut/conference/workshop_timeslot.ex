defmodule Gut.Conference.WorkshopTimeslot do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshop_timeslots"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :start, :end]
    end

    update :update do
      accept [:name, :start, :end]
    end
  end

  policies do
    bypass action(:read) do
      authorize_if Gut.Checks.PublicActor
    end

    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "workshop_timeslots"
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

    attribute :start, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :end, :utc_datetime do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :workshops, Gut.Conference.Workshop
  end
end
