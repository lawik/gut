defmodule Gut.Conference.SurveyResponse.Validations.HasAnswers do
  @moduledoc """
  Requires at least one non-blank answer in a response.

  An accidental empty submission would otherwise consume the attendee's
  single response (unique per survey and user) with no content.
  """
  use Ash.Resource.Validation

  @impl true
  def atomic?, do: false

  @impl true
  def validate(changeset, _opts, _context) do
    answers = Ash.Changeset.get_argument(changeset, :answers) || []

    if Enum.any?(answers, &non_blank?/1) do
      :ok
    else
      {:error, field: :answers, message: "must answer at least one question"}
    end
  end

  defp non_blank?(%{value: value}) when is_binary(value), do: String.trim(value) != ""
  defp non_blank?(%{"value" => value}) when is_binary(value), do: String.trim(value) != ""
  defp non_blank?(_), do: false
end
