defmodule Gut.Emails.WorkshopStatus do
  @moduledoc """
  Builds the per-participant "where you stand" workshop status email.

  The same data and rendering are used by the delivery worker and by the
  staff preview, so the preview is exactly what recipients get.
  """

  require Ash.Query

  @system_actor Gut.system_actor("workshop_status_email")

  @default_intro """
  Goatmire approaches, this is the status of your workshop registration.

  If you cannot attend a workshop you have a seat in, please contact us at info@goatmire.com or via Discord and we will remove you to make space for others.

  Let us know if you have questions.
  """

  @doc "The intro text staff start from."
  def default_intro, do: String.trim(@default_intro)

  @doc """
  Participants who will receive the mailing: linked to a user with an email
  and signed up (registered or waitlisted) for at least one workshop.
  """
  def recipients do
    Gut.Conference.WorkshopParticipant
    |> Ash.Query.filter(not is_nil(user.email) and exists(workshop_participations, true))
    |> Ash.Query.load(:user)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: @system_actor)
  end

  @doc """
  Collects everything the email needs for one participant.

  Returns a map with the participant's name, their registered and waitlisted
  workshops (each with timeslot and room), and for every waitlisted workshop
  the alternatives in the same timeslot that still have seats.
  """
  def build(participant, intro) do
    participations =
      Gut.Conference.WorkshopParticipation
      |> Ash.Query.filter(workshop_participant_id == ^participant.id)
      |> Ash.read!(actor: @system_actor)

    workshops =
      Gut.Conference.Workshop
      |> Ash.Query.load([:workshop_timeslot, :workshop_room, :spots_remaining])
      |> Ash.read!(actor: @system_actor)
      |> Map.new(&{&1.id, &1})

    entries =
      participations
      |> Enum.map(fn p -> {p.status, Map.fetch!(workshops, p.workshop_id)} end)
      |> Enum.sort_by(fn {_status, w} -> slot_sort_key(w) end)

    registered = for {:registered, w} <- entries, do: entry(w, [])

    waitlisted =
      for {:waitlisted, w} <- entries do
        alternatives =
          workshops
          |> Map.values()
          |> Enum.filter(fn other ->
            other.id != w.id and
              other.workshop_timeslot_id == w.workshop_timeslot_id and
              not is_nil(other.workshop_timeslot_id) and
              (other.spots_remaining || 0) > 0
          end)
          |> Enum.sort_by(&(-(&1.spots_remaining || 0)))

        entry(w, alternatives)
      end

    %{
      name: participant.name,
      intro: intro,
      registered: registered,
      waitlisted: waitlisted
    }
  end

  defp slot_sort_key(%{workshop_timeslot: %{start: start}}), do: {0, DateTime.to_unix(start)}
  defp slot_sort_key(_), do: {1, 0}

  defp entry(workshop, alternatives) do
    %{
      name: workshop.name,
      slot: slot_label(workshop),
      room: workshop.workshop_room && workshop.workshop_room.name,
      alternatives: Enum.map(alternatives, &%{name: &1.name, seats_left: &1.spots_remaining || 0})
    }
  end

  defp slot_label(%{workshop_timeslot: %{name: name, start: start, end: finish}}) do
    "#{name}, #{Calendar.strftime(start, "%A %B %d, %H:%M")}-#{Calendar.strftime(finish, "%H:%M")}"
  end

  defp slot_label(_), do: nil

  @doc "Subject line for the email."
  def subject, do: "Your Goatmire workshop registrations"

  @doc "Renders the HTML body. `link` is the signed URL back to the browse page."
  def html(data, link) do
    intro_html = GutWeb.SurveyComponents.render_markdown(data.intro)

    """
    <p>Hello #{esc(data.name)}!</p>
    #{intro_html}
    #{html_section("You have a seat in", data.registered, "You do not currently have a seat in any workshop.")}
    #{if data.waitlisted == [], do: "", else: html_section("You are on the waitlist for", data.waitlisted, "")}
    <hr>
    <p><a href="#{link}">Review or change your workshop selections</a></p>
    <p>The link signs you in and takes you straight to the workshop registration page.</p>
    """
  end

  defp html_section(heading, entries, empty_text) do
    if entries == [] do
      if empty_text == "", do: "", else: "<p>#{empty_text}</p>"
    else
      items =
        Enum.map_join(entries, "\n", fn e ->
          details = Enum.reject([e.slot, e.room], &is_nil/1) |> Enum.map_join(", ", &esc/1)
          details = if details == "", do: "", else: " <em>(#{details})</em>"

          alternatives =
            case e.alternatives do
              [] ->
                ""

              alts ->
                list =
                  Enum.map_join(alts, ", ", fn a ->
                    "#{esc(a.name)} (#{a.seats_left} #{plural(a.seats_left, "seat")} left)"
                  end)

                "<br><small>Still has seats in this timeslot: #{list}</small>"
            end

          "<li><strong>#{esc(e.name)}</strong>#{details}#{alternatives}</li>"
        end)

      "<h3>#{heading}</h3>\n<ul>\n#{items}\n</ul>"
    end
  end

  @doc "Renders the plain text body."
  def text(data, link) do
    registered =
      if data.registered == [] do
        "You do not currently have a seat in any workshop."
      else
        "You have a seat in:\n" <> Enum.map_join(data.registered, "\n", &text_entry/1)
      end

    waitlisted =
      if data.waitlisted == [] do
        ""
      else
        "\n\nYou are on the waitlist for:\n" <>
          Enum.map_join(data.waitlisted, "\n", &text_entry/1)
      end

    """
    Hello #{data.name}!

    #{data.intro}

    #{registered}#{waitlisted}

    Review or change your workshop selections (the link signs you in): #{link}
    """
  end

  defp text_entry(e) do
    details = Enum.reject([e.slot, e.room], &is_nil/1) |> Enum.join(", ")
    details = if details == "", do: "", else: " (#{details})"

    alternatives =
      case e.alternatives do
        [] ->
          ""

        alts ->
          "\n    Still has seats in this timeslot: " <>
            Enum.map_join(alts, ", ", &"#{&1.name} (#{&1.seats_left} left)")
      end

    "  - #{e.name}#{details}#{alternatives}"
  end

  defp plural(1, word), do: word
  defp plural(_, word), do: word <> "s"

  defp esc(nil), do: ""
  defp esc(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
