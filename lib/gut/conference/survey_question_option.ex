defmodule Gut.Conference.SurveyQuestionOption do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "survey_question_options"
    repo Gut.Repo

    references do
      reference :survey_question, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:label, :position]

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey_question},
        before_action?: true
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:label, :position]

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey_question},
        before_action?: true
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate {Gut.Conference.Survey.Validations.SurveyIsDraft, via: :survey_question},
        before_action?: true
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if accessing_from(Gut.Conference.SurveyQuestion, :options)

      authorize_if expr(exists(survey_question.survey.workshop.speakers, user_id == ^actor(:id)))

      authorize_if expr(
                     survey_question.survey.status == :sent and
                       exists(
                         survey_question.survey.workshop.participants,
                         user_id == ^actor(:id)
                       )
                   )
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if accessing_from(Gut.Conference.SurveyQuestion, :options)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      allow_nil? false
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :survey_question, Gut.Conference.SurveyQuestion do
      allow_nil? false
      public? true
    end
  end
end
