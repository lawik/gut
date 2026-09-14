defmodule Gut.Conference.Blast do
  @moduledoc """
  An email blast from a workshop's organizers to its attendees.

  A blast is written in Markdown and sent the moment it is created: there is
  no draft or review step. Each registered attendee gets an email with the
  rendered content and a link back to the blast's page, and attendees can
  always find the blasts for their workshops again from the browse page.
  """
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "workshop_blasts"
    repo Gut.Repo

    references do
      reference :workshop, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :send do
      primary? true
      accept [:title, :body, :workshop_id]

      change set_attribute(:sent_at, &DateTime.utc_now/0)
      change Gut.Conference.Blast.Changes.SendToAttendees
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if expr(exists(workshop.speakers, user_id == ^actor(:id)))
      authorize_if expr(exists(workshop.participants, user_id == ^actor(:id)))
    end

    policy action(:send) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if Gut.Conference.Checks.ActorOrganizesWorkshop
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "blasts"
    publish :send, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1
    end

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1
      description "Markdown content of the blast"
    end

    attribute :sent_at, :utc_datetime_usec do
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
  end
end
