defmodule Gut.Conference.StatusMailing do
  @moduledoc """
  A one-off email to every workshop participant summarising where they
  stand: which workshops they have a seat in and which they are waitlisted
  for, with suggestions for alternatives that still have seats.

  Staff write a short Markdown intro; the rest of the email is generated per
  participant. Sending happens immediately, one Oban job per recipient.
  """
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshop_status_mailings"
    repo Gut.Repo
  end

  actions do
    defaults [:read]

    create :send do
      primary? true
      accept [:intro]

      change set_attribute(:sent_at, &DateTime.utc_now/0)
      change Gut.Conference.StatusMailing.Changes.SendToParticipants
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
    prefix "status_mailings"
    publish :send, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :intro, :string do
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1
      description "Markdown shown at the top of every email, before the per-person status"
    end

    attribute :sent_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :recipient_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
