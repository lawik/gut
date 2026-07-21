defmodule Gut.Conference.SurveyResponse.Validations.RequiredQuestionsAnswered do
  @moduledoc """
  Validates that every required question of the survey has a non-blank answer
  in the response being submitted.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, _opts, _context) do
    survey_id = Ash.Changeset.get_attribute(changeset, :survey_id)
    answers = Ash.Changeset.get_argument(changeset, :answers) || []

    answered_ids =
      answers
      |> Enum.filter(&(String.trim(answer_value(&1) || "") != ""))
      |> MapSet.new(&answer_question_id/1)

    missing =
      Gut.Conference.SurveyQuestion
      |> Ash.Query.filter(survey_id == ^survey_id and required == true)
      |> Ash.read!(authorize?: false)
      |> Enum.reject(&MapSet.member?(answered_ids, &1.id))

    case missing do
      [] ->
        :ok

      questions ->
        prompts = Enum.map_join(questions, ", ", &"\"#{&1.prompt}\"")

        {:error, field: :answers, message: "required questions must be answered: #{prompts}"}
    end
  end

  defp answer_value(%{value: value}), do: value
  defp answer_value(%{"value" => value}), do: value
  defp answer_value(_), do: nil

  defp answer_question_id(%{survey_question_id: id}), do: id
  defp answer_question_id(%{"survey_question_id" => id}), do: id
  defp answer_question_id(_), do: nil
end
