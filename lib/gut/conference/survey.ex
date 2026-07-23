defmodule Gut.Conference.Survey do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "surveys"
    repo Gut.Repo

    references do
      reference :workshop, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:title, :description, :workshop_id]

      argument :questions, {:array, :map}, default: []

      change manage_relationship(:questions, type: :direct_control, order_is_key: :position)
    end

    update :update_draft do
      require_atomic? false

      accept [:title, :description]

      argument :questions, {:array, :map}

      validate attribute_equals(:status, :draft), message: "only a draft survey can be edited"

      change manage_relationship(:questions, type: :direct_control, order_is_key: :position)
    end

    update :submit_for_review do
      require_atomic? false

      accept []

      validate attribute_equals(:status, :draft),
        message: "only a draft survey can be submitted for review"

      validate Gut.Conference.Survey.Validations.HasQuestions

      change set_attribute(:status, :in_review)
      change Gut.Conference.Survey.Changes.NotifyStaffOfReview
    end

    update :return_to_draft do
      require_atomic? false

      accept []

      validate attribute_equals(:status, :in_review),
        message: "only a survey in review can be returned to draft"

      change set_attribute(:status, :draft)
    end

    update :send do
      require_atomic? false

      accept []

      validate attribute_equals(:status, :in_review),
        message: "only a survey in review can be sent"

      validate Gut.Conference.Survey.Validations.HasQuestions

      change set_attribute(:status, :sent)
      change set_attribute(:sent_at, &DateTime.utc_now/0)
      change Gut.Conference.Survey.Changes.SendToAttendees
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      # Deleting a sent survey would cascade away collected responses.
      validate attribute_does_not_equal(:status, :sent),
        message: "a sent survey cannot be deleted"
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if expr(exists(workshop.speakers, user_id == ^actor(:id)))

      authorize_if expr(
                     status == :sent and
                       exists(workshop.participants, user_id == ^actor(:id))
                   )
    end

    policy action(:create) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if Gut.Conference.Survey.Checks.ActorOrganizesWorkshop
    end

    policy action([:update_draft, :submit_for_review]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if expr(exists(workshop.speakers, user_id == ^actor(:id)))
    end

    policy action([:return_to_draft, :send]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end

    policy action(:destroy) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor

      authorize_if expr(
                     status == :draft and
                       exists(workshop.speakers, user_id == ^actor(:id))
                   )
    end
  end

  pub_sub do
    module GutWeb.Endpoint
    prefix "surveys"
    publish :create, ["changed"]
    publish :update_draft, ["changed"]
    publish :submit_for_review, ["changed"]
    publish :return_to_draft, ["changed"]
    publish :send, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :in_review, :sent]
      allow_nil? false
      default :draft
      public? true
    end

    attribute :sent_at, :utc_datetime_usec do
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

    has_many :questions, Gut.Conference.SurveyQuestion do
      public? true
      sort position: :asc
    end

    has_many :responses, Gut.Conference.SurveyResponse do
      public? true
    end
  end

  aggregates do
    count :question_count, :questions do
      public? true
    end

    count :response_count, :responses do
      public? true
    end
  end

  identities do
    identity :unique_workshop_survey, [:workshop_id],
      pre_check_with: Gut.Repo,
      message: "this workshop already has a survey"
  end
end
