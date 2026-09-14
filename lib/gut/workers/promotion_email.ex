defmodule Gut.Workers.PromotionEmail do
  @moduledoc """
  Tells one attendee that they have been moved from the waitlist into a
  seat for a workshop.

  Enqueued per promotion. The participation is re-read at delivery time so
  a promotion that was reverted, or a participant who withdrew or has no
  email, is skipped rather than told something untrue.
  """
  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, keys: [:participation_id]]

  use GutWeb, :verified_routes

  import Swoosh.Email

  alias Gut.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"participation_id" => participation_id}}) do
    case Ash.get(Gut.Conference.WorkshopParticipation, participation_id,
           load: [workshop: [:workshop_timeslot, :workshop_room], workshop_participant: [:user]],
           authorize?: false
         ) do
      {:ok,
       %{status: :registered, workshop_participant: %{user: %{email: email}}} = participation}
      when not is_nil(email) ->
        deliver(participation, to_string(email))
        :ok

      {:ok, %{status: :registered}} ->
        {:cancel, "participant has no email"}

      {:ok, _participation} ->
        {:cancel, "participant is no longer registered"}

      {:error, _} ->
        {:cancel, "participation no longer exists"}
    end
  end

  defp deliver(participation, email) do
    workshop = participation.workshop
    name = participation.workshop_participant.name

    link =
      case Gut.Accounts.survey_link_token(email) do
        {:ok, token} -> url(~p"/browse-link?token=#{token}")
        _ -> url(~p"/browse-link")
      end

    when_where =
      [
        slot_label(workshop.workshop_timeslot),
        workshop.workshop_room && workshop.workshop_room.name
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    when_where_html = if when_where == "", do: "", else: " <em>(#{esc(when_where)})</em>"
    when_where_text = if when_where == "", do: "", else: " (#{when_where})"

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(email)
    |> subject("You now have a seat in #{workshop.name}")
    |> text_body("""
    Hello #{name}!

    Good news: a seat opened up in #{workshop.name}#{when_where_text} and you were next on the waitlist. You are now registered.

    If you cannot attend after all, please contact us at info@goatmire.com or via Discord and we will remove you to make space for others.

    Review or change your workshop selections (the link signs you in): #{link}
    """)
    |> html_body("""
    <p>Hello #{esc(name)}!</p>
    <p>
      Good news: a seat opened up in <strong>#{esc(workshop.name)}</strong>#{when_where_html}
      and you were next on the waitlist. You are now registered.
    </p>
    <p>
      If you cannot attend after all, please contact us at info@goatmire.com or via Discord
      and we will remove you to make space for others.
    </p>
    <hr>
    <p><a href="#{link}">Review or change your workshop selections</a></p>
    <p>The link signs you in and takes you straight to the workshop registration page.</p>
    """)
    |> Mailer.deliver!()
  end

  defp slot_label(%{name: name, start: start, end: finish}) do
    "#{name}, #{Calendar.strftime(start, "%A %B %d, %H:%M")}-#{Calendar.strftime(finish, "%H:%M")}"
  end

  defp slot_label(_), do: nil

  defp esc(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
