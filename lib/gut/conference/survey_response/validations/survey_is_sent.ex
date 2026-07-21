defmodule Gut.Conference.SurveyResponse.Validations.SurveyIsSent do
  @moduledoc """
  Validates that a response is only submitted for a survey that has been sent.
  """
  use Ash.Resource.Validation

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, _opts, _context) do
    with survey_id when not is_nil(survey_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_id),
         {:ok, %{status: :sent}} <-
           Ash.get(Gut.Conference.Survey, survey_id, authorize?: false) do
      :ok
    else
      _ -> {:error, field: :survey_id, message: "this survey is not accepting responses"}
    end
  end
end
