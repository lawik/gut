defmodule Gut.Conference.Speaker do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshOban]

  postgres do
    table "speakers"
    repo Gut.Repo
  end

  oban do
    domain Gut.Conference

    scheduled_actions do
      schedule :sync_from_sessionize, "0 * * * *" do
        action :sync_from_sessionize
        queue :default
        worker_module_name Gut.Workers.SessionizeSync
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :full_name,
        :first_name,
        :last_name,
        :arrival_date,
        :arrival_time,
        :leaving_date,
        :leaving_time,
        :hotel_stay_start_date,
        :hotel_stay_end_date,
        :hotel_covered_start_date,
        :hotel_covered_end_date,
        :sessionize_data,
        :user_id
      ]

      argument :email, :string

      change Gut.Conference.Speaker.Changes.HandleInvite
    end

    action :sync_from_sessionize do
      run fn _input, context ->
        actor = context.actor || Gut.system_actor("sessionize_sync")
        Gut.Conference.SessionizeSync.sync(actor)
      end
    end

    update :update do
      require_atomic? false

      accept [
        :full_name,
        :first_name,
        :last_name,
        :arrival_date,
        :arrival_time,
        :leaving_date,
        :leaving_time,
        :hotel_stay_start_date,
        :hotel_stay_end_date,
        :hotel_covered_start_date,
        :hotel_covered_end_date,
        :sessionize_data,
        :user_id
      ]

      argument :email, :string

      change Gut.Conference.Speaker.Changes.HandleInvite
      change Gut.Conference.Changes.NotifyDiscord
    end

    read :read_own do
      get? true
      filter expr(user_id == ^actor(:id))
    end

    update :update_travel do
      accept [:arrival_date, :arrival_time, :leaving_date, :leaving_time]
    end
  end

  policies do
    policy action(:sync_from_sessionize) do
      authorize_if AshOban.Checks.AshObanInteraction
    end

    policy action(:read_own) do
      authorize_if actor_attribute_equals(:role, :speaker)
    end

    policy action(:update_travel) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action([:read, :create, :update, :destroy]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "speakers"
    publish :create, ["changed"]
    publish :update, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :full_name, :string do
      allow_nil? false
      public? true
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
    end

    attribute :arrival_date, :date do
      public? true
    end

    attribute :arrival_time, :time do
      public? true
    end

    attribute :leaving_date, :date do
      public? true
    end

    attribute :leaving_time, :time do
      public? true
    end

    attribute :hotel_stay_start_date, :date do
      public? true
    end

    attribute :hotel_stay_end_date, :date do
      public? true
    end

    attribute :hotel_covered_start_date, :date do
      public? true
    end

    attribute :hotel_covered_end_date, :date do
      public? true
    end

    attribute :sessionize_data, :map do
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
