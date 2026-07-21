defmodule Gut.Conference.SurveyAnswer do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "survey_answers"
    repo Gut.Repo

    references do
      reference :survey_response, on_delete: :delete
      reference :survey_question, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:survey_question_id, :value]

      validate Gut.Conference.SurveyAnswer.Validations.AnswerMatchesSurvey,
        before_action?: true
    end
  end

  policies do
    policy action(:read) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if accessing_from(Gut.Conference.SurveyResponse, :answers)
      authorize_if expr(survey_response.user_id == ^actor(:id))

      authorize_if expr(exists(survey_response.survey.workshop.speakers, user_id == ^actor(:id)))
    end

    policy action(:create) do
      authorize_if Gut.Checks.SystemActor
      authorize_if accessing_from(Gut.Conference.SurveyResponse, :answers)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :value, :string do
      allow_nil? false
      public? true
      constraints max_length: 10_000
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :survey_response, Gut.Conference.SurveyResponse do
      allow_nil? false
      public? true
    end

    belongs_to :survey_question, Gut.Conference.SurveyQuestion do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_answer_per_question, [:survey_response_id, :survey_question_id],
      pre_check_with: Gut.Repo,
      message: "this question has already been answered"
  end
end
