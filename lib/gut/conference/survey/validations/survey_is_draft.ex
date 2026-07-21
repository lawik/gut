defmodule Gut.Conference.Survey.Validations.SurveyIsDraft do
  @moduledoc """
  Validates that the survey a question or option belongs to is still a draft.

  Once a survey has been submitted for review or sent, its questions and
  options must not change. Use `via: :survey` on questions and
  `via: :survey_question` on options.
  """
  use Ash.Resource.Validation

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, opts, _context) do
    case survey_for(changeset, Keyword.fetch!(opts, :via)) do
      {:ok, %{status: :draft}} ->
        :ok

      {:ok, _survey} ->
        {:error, field: :base, message: "the survey can no longer be edited"}

      :error ->
        {:error, field: :base, message: "could not determine the survey"}
    end
  end

  defp survey_for(changeset, :survey) do
    with survey_id when not is_nil(survey_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_id),
         {:ok, survey} <- Ash.get(Gut.Conference.Survey, survey_id, authorize?: false) do
      {:ok, survey}
    else
      _ -> :error
    end
  end

  defp survey_for(changeset, :survey_question) do
    with question_id when not is_nil(question_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_question_id),
         {:ok, question} <-
           Ash.get(Gut.Conference.SurveyQuestion, question_id, authorize?: false),
         {:ok, survey} <-
           Ash.get(Gut.Conference.Survey, question.survey_id, authorize?: false) do
      {:ok, survey}
    else
      _ -> :error
    end
  end
end
