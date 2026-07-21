defmodule Gut.Conference.SurveyQuestion do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "survey_questions"
    repo Gut.Repo

    references do
      reference :survey, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:prompt, :question_type, :position, :required]

      argument :options, {:array, :map}, default: []

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey},
        before_action?: true

      change manage_relationship(:options, type: :direct_control, order_is_key: :position)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:prompt, :question_type, :position, :required]

      argument :options, {:array, :map}

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey},
        before_action?: true

      change manage_relationship(:options, type: :direct_control, order_is_key: :position)
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey},
        before_action?: true
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if accessing_from(Gut.Conference.Survey, :questions)
      authorize_if expr(exists(survey.workshop.speakers, user_id == ^actor(:id)))

      authorize_if expr(
                     survey.status == :sent and
                       exists(survey.workshop.participants, user_id == ^actor(:id))
                   )
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if accessing_from(Gut.Conference.Survey, :questions)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :prompt, :string do
      allow_nil? false
      public? true
    end

    attribute :question_type, :atom do
      constraints one_of: [:single_line, :multiline, :select]
      allow_nil? false
      default :single_line
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :required, :boolean do
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :survey, Gut.Conference.Survey do
      allow_nil? false
      public? true
    end

    has_many :options, Gut.Conference.SurveyQuestionOption do
      public? true
      sort position: :asc
    end
  end
end
