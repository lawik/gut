defmodule Gut.Conference.Survey.Validations.HasQuestions do
  @moduledoc """
  Requires a survey to have at least one question before it can move
  towards being sent to attendees.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, _opts, _context) do
    has_questions =
      Gut.Conference.SurveyQuestion
      |> Ash.Query.filter(survey_id == ^changeset.data.id)
      |> Ash.exists?(authorize?: false)

    if has_questions do
      :ok
    else
      {:error, field: :base, message: "the survey needs at least one question"}
    end
  end
end
