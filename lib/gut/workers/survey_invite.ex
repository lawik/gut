defmodule Gut.Workers.SurveyInvite do
  @moduledoc """
  Delivers a survey invitation email to one attendee.

  Enqueued per recipient when staff send a survey, so a delivery failure
  only retries that recipient instead of blocking or losing the rest.
  """
  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, keys: [:survey_id, :email]]

  use GutWeb, :verified_routes

  import Swoosh.Email

  alias Gut.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"survey_id" => survey_id, "email" => email}}) do
    case Ash.get(Gut.Conference.Survey, survey_id, authorize?: false) do
      {:ok, %{status: :sent} = survey} ->
        workshop = Ash.get!(Gut.Conference.Workshop, survey.workshop_id, authorize?: false)
        deliver(survey, workshop, email)
        :ok

      {:ok, _survey} ->
        {:cancel, "survey is no longer sent"}

      {:error, _} ->
        {:cancel, "survey no longer exists"}
    end
  end

  defp deliver(survey, workshop, email) do
    link =
      case Gut.Accounts.survey_link_token(email) do
        {:ok, token} -> url(~p"/survey-invite/#{survey.id}?token=#{token}")
        _ -> url(~p"/survey-invite/#{survey.id}")
      end

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(email)
    |> subject("Survey for #{workshop.name}")
    |> html_body("""
    <p>Hello!</p>
    <p>
      The organizer of the workshop <strong>#{workshop.name}</strong> would like
      you to answer the survey <strong>#{survey.title}</strong>.
    </p>
    <p><a href="#{link}">Answer the survey</a></p>
    <p>The link signs you in and takes you straight to the survey.</p>
    """)
    |> Mailer.deliver!()
  end
end
