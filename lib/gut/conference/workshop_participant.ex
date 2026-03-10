defmodule Gut.Conference.WorkshopParticipant do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshop_participants"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :phone_number, :user_id]

      argument :email, :string

      change Gut.Conference.WorkshopParticipant.Changes.HandleUser
    end

    update :update do
      accept [:name, :phone_number, :user_id]
    end
  end

  policies do
    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "workshop_participants"
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

    attribute :phone_number, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Gut.Accounts.User do
      public? true
    end

    has_many :workshop_participations, Gut.Conference.WorkshopParticipation

    many_to_many :workshops, Gut.Conference.Workshop do
      through Gut.Conference.WorkshopParticipation
      source_attribute_on_join_resource :workshop_participant_id
      destination_attribute_on_join_resource :workshop_id
    end
  end
end
