defmodule Gut.Conference.Survey.Changes.NotifyStaffOfReview do
  @moduledoc """
  Posts a Discord message to staff when a survey is submitted for review,
  with a direct link to the review page.
  """
  use Ash.Resource.Change
  use GutWeb, :verified_routes

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, survey ->
      workshop = Ash.get!(Gut.Conference.Workshop, survey.workshop_id, authorize?: false)

      message =
        """
        **Survey submitted for review: #{survey.title}**
        Workshop: #{workshop.name}
        <#{url(~p"/surveys/#{survey.id}/review")}>
        """
        |> String.trim()

      %{"message" => message}
      |> Gut.Workers.DiscordNotification.new()
      |> Oban.insert!()

      {:ok, survey}
    end)
  end
end
