defmodule Gut.Conference.SurveyAnswer.Validations.AnswerMatchesSurvey do
  @moduledoc """
  Validates that an answer's question belongs to the same survey as its
  response and, for select questions, that the value is one of the
  question's options.
  """
  use Ash.Resource.Validation

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, _opts, _context) do
    with response_id when not is_nil(response_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_response_id),
         question_id when not is_nil(question_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_question_id),
         {:ok, response} <-
           Ash.get(Gut.Conference.SurveyResponse, response_id, authorize?: false),
         {:ok, question} <-
           Ash.get(Gut.Conference.SurveyQuestion, question_id,
             load: [:options],
             authorize?: false
           ) do
      validate_answer(changeset, response, question)
    else
      _ ->
        {:error, field: :survey_question_id, message: "could not resolve the question"}
    end
  end

  defp validate_answer(changeset, response, question) do
    cond do
      question.survey_id != response.survey_id ->
        {:error, field: :survey_question_id, message: "question does not belong to this survey"}

      question.question_type == :select ->
        value = Ash.Changeset.get_attribute(changeset, :value)
        labels = Enum.map(question.options, & &1.label)

        if value in labels do
          :ok
        else
          {:error, field: :value, message: "must be one of the question's options"}
        end

      true ->
        :ok
    end
  end
end
