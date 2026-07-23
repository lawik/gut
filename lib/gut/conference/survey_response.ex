defmodule Gut.Conference.SurveyResponse do
  use Ash.Resource,
    otp_app: :gut,
    domain: Gut.Conference,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "survey_responses"
    repo Gut.Repo

    references do
      reference :survey, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      pagination offset?: true, default_limit: 25, countable: :by_default
    end

    action :clear_for_survey, :integer do
      argument :survey_id, :uuid, allow_nil?: false

      run fn input, context ->
        require Ash.Query

        result =
          __MODULE__
          |> Ash.Query.filter(survey_id == ^input.arguments.survey_id)
          |> Ash.bulk_destroy!(
            :destroy,
            %{},
            Ash.Context.to_opts(context, return_records?: true, return_errors?: true)
          )

        {:ok, length(result.records || [])}
      end
    end

    create :respond do
      accept [:survey_id]

      argument :answers, {:array, :map}, default: []

      validate Gut.Conference.SurveyResponse.Validations.SurveyIsSent
      validate Gut.Conference.SurveyResponse.Validations.RequiredQuestionsAnswered
      validate Gut.Conference.SurveyResponse.Validations.HasAnswers

      change relate_actor(:user)
      change manage_relationship(:answers, type: :create)
    end
  end

  policies do
    policy action([:read, :list]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
      authorize_if expr(user_id == ^actor(:id))
      authorize_if expr(exists(survey.workshop.speakers, user_id == ^actor(:id)))
    end

    policy action(:respond) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Conference.SurveyResponse.Checks.ActorIsWorkshopParticipant
    end

    policy action([:destroy, :clear_for_survey]) do
      authorize_if Gut.Checks.SystemActor
      authorize_if Gut.Checks.StaffActor
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :survey, Gut.Conference.Survey do
      allow_nil? false
      public? true
    end

    belongs_to :user, Gut.Accounts.User do
      allow_nil? false
      public? true
    end

    has_many :answers, Gut.Conference.SurveyAnswer do
      public? true
    end
  end

  identities do
    identity :unique_response, [:survey_id, :user_id],
      pre_check_with: Gut.Repo,
      message: "you have already responded to this survey"
  end
end
