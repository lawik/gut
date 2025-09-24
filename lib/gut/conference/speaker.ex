defmodule Gut.Conference.Speaker do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "speakers"
    repo Gut.Repo
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
        :user_id
      ]
    end

    update :update do
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
        :user_id
      ]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Gut.Accounts.User do
      public? true
    end
  end
end
