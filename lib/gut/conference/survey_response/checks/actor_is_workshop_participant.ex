defmodule Gut.Conference.SurveyResponse.Checks.ActorIsWorkshopParticipant do
  @moduledoc """
  Policy check that passes when the actor is a user linked to a participant
  of the workshop the survey belongs to.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor participates in the survey's workshop"

  @impl true
  def match?(%{id: user_id}, %{subject: %Ash.Changeset{} = changeset}, _opts)
      when is_binary(user_id) do
    with survey_id when not is_nil(survey_id) <-
           Ash.Changeset.get_attribute(changeset, :survey_id),
         {:ok, survey} <- Ash.get(Gut.Conference.Survey, survey_id, authorize?: false) do
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(
        workshop_id == ^survey.workshop_id and workshop_participant.user_id == ^user_id
      )
      |> Ash.exists?(authorize?: false)
    else
      _ -> false
    end
  end

  def match?(_, _, _), do: false
end
