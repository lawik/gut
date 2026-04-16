defmodule Gut.Conference.WorkshopParticipation do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshop_participations"
    repo Gut.Repo

    references do
      reference :workshop, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:workshop_id, :workshop_participant_id]

      validate Gut.Conference.WorkshopParticipation.Validations.UniqueSlot
      change Gut.Conference.WorkshopParticipation.Changes.DetermineStatus
    end

    update :update do
      accept [:status]
    end
  end

  policies do
    bypass action([:read, :register, :destroy]) do
      authorize_if Gut.Checks.PublicActor
    end

    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "workshop_participations"
    publish :register, ["changed"]
    publish :update, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:registered, :waitlisted]
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workshop, Gut.Conference.Workshop do
      allow_nil? false
      public? true
    end

    belongs_to :workshop_participant, Gut.Conference.WorkshopParticipant do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_participation, [:workshop_id, :workshop_participant_id]
  end
end
