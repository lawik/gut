defmodule Gut.Accounts.User.Senders.SendSurveyLinkEmail do
  @moduledoc """
  Sends a sign-in link for the survey_link strategy.

  Survey invitations are normally sent by `Gut.Workers.SurveyInvite`, which
  mints tokens directly. This sender only fires if someone triggers the
  strategy's request flow, so it just delivers a plain sign-in link.
  """

  use AshAuthentication.Sender
  use GutWeb, :verified_routes

  import Swoosh.Email
  alias Gut.Mailer

  @impl true
  def send(user_or_email, token, _) do
    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(to_string(email))
    |> subject("Your login link")
    |> html_body("""
    <p>Hello, #{email}! Click this link to sign in:</p>
    <p><a href="#{url(~p"/survey_link/#{token}")}">#{url(~p"/survey_link/#{token}")}</a></p>
    """)
    |> Mailer.deliver!()
  end
end
