defmodule Gut.Workers.BlastEmail do
  @moduledoc """
  Delivers a workshop blast email to one attendee.

  Enqueued per recipient when an organizer sends a blast, so a delivery
  failure only retries that recipient instead of blocking or losing the rest.
  """
  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, keys: [:blast_id, :email]]

  use GutWeb, :verified_routes

  import Swoosh.Email

  alias Gut.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"blast_id" => blast_id, "email" => email}}) do
    case Ash.get(Gut.Conference.Blast, blast_id, authorize?: false) do
      {:ok, blast} ->
        workshop = Ash.get!(Gut.Conference.Workshop, blast.workshop_id, authorize?: false)
        deliver(blast, workshop, email)
        :ok

      {:error, _} ->
        {:cancel, "blast no longer exists"}
    end
  end

  defp deliver(blast, workshop, email) do
    link =
      case Gut.Accounts.survey_link_token(email) do
        {:ok, token} -> url(~p"/blast-link/#{blast.id}?token=#{token}")
        _ -> url(~p"/blast-link/#{blast.id}")
      end

    # Titles are organizer-controlled and workshop names come from
    # Sessionize; escape both before interpolating into HTML. The body is
    # Markdown rendered through the same sanitizing renderer as the web page.
    workshop_name = Plug.HTML.html_escape(workshop.name)
    title = Plug.HTML.html_escape(blast.title)
    body_html = GutWeb.SurveyComponents.render_markdown(blast.body)

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(email)
    |> subject("#{workshop.name}: #{blast.title}")
    |> text_body("""
    #{blast.title}

    An update from the organizer of the workshop #{workshop.name}.

    #{blast.body}

    Read this update online (the link signs you in): #{link}
    """)
    |> html_body("""
    <p>Hello!</p>
    <p>
      An update from the organizer of the workshop <strong>#{workshop_name}</strong>:
    </p>
    <h2>#{title}</h2>
    <div>
    #{body_html}
    </div>
    <hr>
    <p><a href="#{link}">Read this update online</a></p>
    <p>The link signs you in and takes you straight to the update.</p>
    """)
    |> Mailer.deliver!()
  end
end
