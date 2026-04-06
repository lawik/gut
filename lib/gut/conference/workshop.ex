defmodule Gut.Conference.Workshop do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshops"
    repo Gut.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      pagination offset?: true, default_limit: 25, countable: :by_default

      prepare build(
                load: [:workshop_room, :workshop_timeslot, :registration_count, :waitlist_count]
              )
    end

    read :browse do
      prepare build(load: [:workshop_room, :workshop_timeslot, :speakers, :registration_count])
    end

    create :create do
      accept [
        :name,
        :description,
        :limit,
        :workshop_room_id,
        :workshop_timeslot_id,
        :sessionize_id
      ]
    end

    update :update do
      require_atomic? false

      accept [
        :name,
        :description,
        :limit,
        :workshop_room_id,
        :workshop_timeslot_id,
        :sessionize_id
      ]
    end

    action :promote_waitlist, :integer do
      argument :workshop_id, :uuid, allow_nil?: false

      run Gut.Conference.Workshop.Actions.PromoteWaitlist
    end
  end

  policies do
    bypass action([:read, :list, :browse]) do
      authorize_if Gut.Checks.PublicActor
    end

    policy always() do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "workshops"
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

    attribute :description, :string do
      public? true
    end

    attribute :limit, :integer do
      allow_nil? false
      public? true
    end

    attribute :sessionize_id, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workshop_room, Gut.Conference.WorkshopRoom do
      public? true
    end

    belongs_to :workshop_timeslot, Gut.Conference.WorkshopTimeslot do
      public? true
    end

    many_to_many :speakers, Gut.Conference.Speaker do
      through Gut.Conference.WorkshopSpeaker
      source_attribute_on_join_resource :workshop_id
      destination_attribute_on_join_resource :speaker_id
    end

    has_many :workshop_participations, Gut.Conference.WorkshopParticipation

    many_to_many :participants, Gut.Conference.WorkshopParticipant do
      through Gut.Conference.WorkshopParticipation
      source_attribute_on_join_resource :workshop_id
      destination_attribute_on_join_resource :workshop_participant_id
    end
  end

  aggregates do
    count :registration_count, :workshop_participations do
      filter expr(status == :registered)
    end

    count :waitlist_count, :workshop_participations do
      filter expr(status == :waitlisted)
    end
  end

  identities do
    identity :unique_room_timeslot, [:workshop_room_id, :workshop_timeslot_id],
      pre_check_with: Gut.Repo,
      nils_distinct?: true,
      message: "a workshop already exists in this room and timeslot"
  end
end
