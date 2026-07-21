defmodule Gut.Conference.Survey.Changes.SendToAttendees do
  @moduledoc """
  Emails the survey to all registered attendees of the workshop after the
  survey is marked as sent.

  Each email carries a magic-link token so the attendee is signed in and
  redirected straight to the survey.
  """
  use Ash.Resource.Change
  use GutWeb, :verified_routes

  import Swoosh.Email

  require Ash.Query

  alias Gut.Mailer

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, survey} <- result do
        deliver_invites(survey)
      end

      result
    end)
  end

  defp deliver_invites(survey) do
    workshop = Ash.get!(Gut.Conference.Workshop, survey.workshop_id, authorize?: false)

    participations =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_id == ^survey.workshop_id and status == :registered)
      |> Ash.Query.load(workshop_participant: [:user])
      |> Ash.read!(authorize?: false)

    for %{workshop_participant: %{user: %{email: email}}} <- participations,
        not is_nil(email) do
      deliver_invite(survey, workshop, to_string(email))
    end

    :ok
  end

  defp deliver_invite(survey, workshop, email) do
    link =
      case Gut.Accounts.magic_link_token(email) do
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
