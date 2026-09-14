defmodule Gut.Workers.StatusEmail do
  @moduledoc """
  Delivers the workshop status email to one participant.

  Enqueued per recipient when staff send a status mailing, so a delivery
  failure only retries that recipient.
  """
  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, keys: [:mailing_id, :participant_id]]

  use GutWeb, :verified_routes

  import Swoosh.Email

  alias Gut.Emails.WorkshopStatus
  alias Gut.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"mailing_id" => mailing_id, "participant_id" => participant_id}}) do
    with {:ok, mailing} <- Ash.get(Gut.Conference.StatusMailing, mailing_id, authorize?: false),
         {:ok, %{user: %{email: email}} = participant} when not is_nil(email) <-
           Ash.get(Gut.Conference.WorkshopParticipant, participant_id,
             load: [:user],
             authorize?: false
           ) do
      deliver(participant, to_string(email), mailing)
      :ok
    else
      {:error, _} -> {:cancel, "mailing or participant no longer exists"}
      {:ok, _participant_without_email} -> {:cancel, "participant has no email"}
    end
  end

  defp deliver(participant, email, mailing) do
    link =
      case Gut.Accounts.survey_link_token(email) do
        {:ok, token} -> url(~p"/browse-link?token=#{token}")
        _ -> url(~p"/browse-link")
      end

    data = WorkshopStatus.build(participant, mailing.intro)

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(email)
    |> subject(WorkshopStatus.subject())
    |> text_body(WorkshopStatus.text(data, link))
    |> html_body(WorkshopStatus.html(data, link))
    |> Mailer.deliver!()
  end
end
