defmodule Gut.Conference.WorkshopSpeaker do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "workshop_speakers"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:workshop_id, :speaker_id]
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.PublicActor
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end

    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :workshop, Gut.Conference.Workshop do
      allow_nil? false
      public? true
    end

    belongs_to :speaker, Gut.Conference.Speaker do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_workshop_speaker, [:workshop_id, :speaker_id]
  end
end
