# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# The script is idempotent: it can be re-run against an existing database
# without creating duplicates.

require Ash.Query

actor = Gut.system_actor("seeds")

# --- Workshops -------------------------------------------------------------

workshops = [
  {"Intro to Elixir", "Learn the basics of Elixir and functional programming.", 20},
  {"Phoenix LiveView Deep Dive", "Build real-time UIs without JavaScript.", 25},
  {"Building APIs with Ash", "Model your domain and get a full API for free.", 20},
  {"Nerves: Embedded Elixir", "Deploy Elixir to hardware devices with Nerves.", 15},
  {"OTP Patterns in Practice", "Supervisors, GenServers, and fault tolerance.", 30},
  {"Ecto Beyond Basics", "Advanced queries, multi-tenancy, and migrations.", 25},
  {"Testing Elixir Applications", "Property-based testing, mocks, and strategies.", 30},
  {"Machine Learning with Nx", "Numerical computing and ML in Elixir.", 20},
  {"Broadway for Data Pipelines", "Process large volumes of data concurrently.", 20},
  {"Distributed Systems with Elixir", "Clustering, CRDTs, and consistency.", 15},
  {"GraphQL with Absinthe", "Build flexible APIs with GraphQL.", 25},
  {"Deployment & Observability", "Releases, Docker, and production monitoring.", 30},
  {"LiveView Components", "Reusable UI components and design systems.", 25},
  {"Security for Elixir Apps", "Authentication, authorization, and OWASP.", 20},
  {"Concurrency Masterclass", "Tasks, processes, and back-pressure.", 20},
  {"Building CLI Tools", "Command-line applications with Elixir.", 15},
  {"Elixir for Rubyists", "Transition from Ruby/Rails to Elixir/Phoenix.", 30},
  {"Performance Tuning", "Profiling, benchmarking, and optimization.", 20},
  {"Event Sourcing with Commanded", "CQRS and event-driven architectures.", 15},
  {"Elixir in Production", "War stories and lessons from running Elixir at scale.", 25},
  {"WebSockets & Channels", "Real-time communication beyond LiveView.", 20},
  {"Ash Authentication & Authorization", "Secure your Ash resources.", 20},
  {"Contributing to Open Source", "How to contribute to the Elixir ecosystem.", 30},
  {"Functional Design Patterns", "Monads, pipelines, and composition.", 20},
  {"Building a Game Server", "Real-time multiplayer with Elixir.", 15},
  {"Internationalizing Phoenix Apps", "Gettext, locales, and multilingual UIs.", 25},
  {"Oban for Background Jobs", "Reliable job processing with Oban.", 20},
  {"From Monolith to Umbrella", "Structuring large Elixir codebases.", 25},
  {"Debugging & Tracing", "Observer, :dbg, recon, and Entrace.", 20},
  {"Type Specs & Dialyzer", "Static analysis and type checking.", 20}
]

find_workshop = fn name ->
  Gut.Conference.Workshop
  |> Ash.Query.filter(name == ^name)
  |> Ash.read_one!(actor: actor)
end

seeded_workshops =
  for {name, description, limit} <- workshops do
    find_workshop.(name) ||
      Gut.Conference.create_workshop!(
        %{name: name, description: description, limit: limit},
        actor: actor
      )
  end

IO.puts("Workshops: #{length(seeded_workshops)} present.")

# --- Users of every role ----------------------------------------------------
#
# One functional user per role so every flow can be exercised in dev.
# Sign in via magic link; in dev the email lands in /dev/mailbox.

find_or_create_user = fn email, role ->
  case Gut.Accounts.get_user_by_email(email, actor: actor) do
    {:ok, user} -> user
    {:error, _} -> Gut.Accounts.create_user!(email, role, actor: actor)
  end
end

staff = find_or_create_user.("staff@example.com", :staff)
organizer = find_or_create_user.("organizer@example.com", :speaker)
attendee = find_or_create_user.("attendee@example.com", :attendee)
sponsor_user = find_or_create_user.("sponsor@example.com", :sponsor)

# Organizer: a speaker profile attached to a workshop, so they can manage
# that workshop's survey via /my-workshops.

speaker =
  Gut.Conference.Speaker
  |> Ash.Query.filter(user_id == ^organizer.id)
  |> Ash.read_one!(actor: actor) ||
    Gut.Conference.create_speaker!(
      %{
        full_name: "Orla Ganizer",
        first_name: "Orla",
        last_name: "Ganizer",
        user_id: organizer.id
      },
      actor: actor
    )

organizer_workshop = List.first(seeded_workshops)

unless Gut.Conference.WorkshopSpeaker
       |> Ash.Query.filter(workshop_id == ^organizer_workshop.id and speaker_id == ^speaker.id)
       |> Ash.exists?(actor: actor) do
  Gut.Conference.create_workshop_speaker!(
    %{workshop_id: organizer_workshop.id, speaker_id: speaker.id},
    actor: actor
  )
end

# Attendee: a workshop participant registered for the organizer's workshop,
# so sent surveys reach and can be answered by this user.

participant =
  Gut.Conference.WorkshopParticipant
  |> Ash.Query.filter(user_id == ^attendee.id)
  |> Ash.read_one!(actor: actor) ||
    Gut.Conference.create_workshop_participant!(
      %{name: "Adda Tendee", user_id: attendee.id},
      actor: actor
    )

unless Gut.Conference.WorkshopParticipation
       |> Ash.Query.filter(
         workshop_id == ^organizer_workshop.id and workshop_participant_id == ^participant.id
       )
       |> Ash.exists?(actor: actor) do
  Gut.Conference.register_for_workshop!(
    %{workshop_id: organizer_workshop.id, workshop_participant_id: participant.id},
    actor: actor
  )
end

# Sponsor: a sponsor organization linked to the sponsor user for /my-sponsor.

Gut.Conference.Sponsor
|> Ash.Query.filter(user_id == ^sponsor_user.id)
|> Ash.read_one!(actor: actor) ||
  Gut.Conference.create_sponsor!(
    %{name: "Sponsorix AB", status: :ok, confirmed: true, user_id: sponsor_user.id},
    actor: actor
  )

# --- Timeslots, rooms and a full schedule ------------------------------------
#
# Only workshops with a timeslot show up on the browse page, and the status
# email suggests alternatives per timeslot, so give the first few workshops a
# schedule. The "Lab" room seats two, which makes the Nerves workshop fill up
# and puts later registrations on its waitlist.

find_or_create_timeslot = fn name, start, finish ->
  Gut.Conference.WorkshopTimeslot
  |> Ash.Query.filter(name == ^name)
  |> Ash.read_one!(actor: actor) ||
    Gut.Conference.create_workshop_timeslot!(%{name: name, start: start, end: finish},
      actor: actor
    )
end

find_or_create_room = fn name, limit ->
  Gut.Conference.WorkshopRoom
  |> Ash.Query.filter(name == ^name)
  |> Ash.read_one!(actor: actor) ||
    Gut.Conference.create_workshop_room!(%{name: name, limit: limit}, actor: actor)
end

day1_morning =
  find_or_create_timeslot.("Day 1 morning", ~U[2026-10-06 09:00:00Z], ~U[2026-10-06 12:00:00Z])

day1_afternoon =
  find_or_create_timeslot.("Day 1 afternoon", ~U[2026-10-06 13:00:00Z], ~U[2026-10-06 16:00:00Z])

day2_morning =
  find_or_create_timeslot.("Day 2 morning", ~U[2026-10-07 09:00:00Z], ~U[2026-10-07 12:00:00Z])

aula = find_or_create_room.("Aula", 40)
lab = find_or_create_room.("Lab", 2)

schedule = [
  {"Intro to Elixir", day1_morning, aula},
  {"Nerves: Embedded Elixir", day1_morning, lab},
  {"Phoenix LiveView Deep Dive", day1_morning, nil},
  {"Building APIs with Ash", day1_afternoon, aula},
  {"OTP Patterns in Practice", day1_afternoon, nil},
  {"Ecto Beyond Basics", day2_morning, aula},
  {"Testing Elixir Applications", day2_morning, nil}
]

scheduled =
  for {name, slot, room} <- schedule, into: %{} do
    workshop = find_workshop.(name)

    workshop =
      if workshop.workshop_timeslot_id == slot.id and
           workshop.workshop_room_id == (room && room.id) do
        workshop
      else
        Gut.Conference.update_workshop!(
          workshop,
          %{workshop_timeslot_id: slot.id, workshop_room_id: room && room.id},
          actor: actor
        )
      end

    {name, workshop}
  end

# --- Participants in every status combination --------------------------------

find_or_create_participant = fn name, user ->
  query =
    if user do
      Ash.Query.filter(Gut.Conference.WorkshopParticipant, user_id == ^user.id)
    else
      Ash.Query.filter(Gut.Conference.WorkshopParticipant, name == ^name and is_nil(user_id))
    end

  Ash.read_one!(query, actor: actor) ||
    Gut.Conference.create_workshop_participant!(
      %{name: name, user_id: user && user.id},
      actor: actor
    )
end

ensure_participation = fn workshop, participant ->
  Gut.Conference.WorkshopParticipation
  |> Ash.Query.filter(workshop_id == ^workshop.id and workshop_participant_id == ^participant.id)
  |> Ash.read_one!(actor: actor) ||
    Gut.Conference.register_for_workshop!(
      %{workshop_id: workshop.id, workshop_participant_id: participant.id},
      actor: actor
    )
end

nerves = scheduled["Nerves: Embedded Elixir"]

# Two participants without accounts fill the Nerves workshop (Lab seats two).
# They cannot be emailed, so the status mailing skips them.
for name <- ["Filler One", "Filler Two"] do
  ensure_participation.(nerves, find_or_create_participant.(name, nil))
end

# attendee@example.com has two seats and no waitlists.
ensure_participation.(scheduled["Building APIs with Ash"], participant)

# waitlisted@example.com has a seat in one workshop and is waitlisted for Nerves.
waitlisted_user = find_or_create_user.("waitlisted@example.com", :attendee)
waitlisted = find_or_create_participant.("Wanda Waitlist", waitlisted_user)
ensure_participation.(nerves, waitlisted)
ensure_participation.(scheduled["OTP Patterns in Practice"], waitlisted)

# onlywaitlist@example.com is waitlisted for Nerves and has no seat anywhere.
onlywait_user = find_or_create_user.("onlywaitlist@example.com", :attendee)
onlywait = find_or_create_participant.("Wally Onlywait", onlywait_user)
ensure_participation.(nerves, onlywait)

# A participant with an account but no workshops: not a mailing recipient.
idle_user = find_or_create_user.("noworkshops@example.com", :attendee)
find_or_create_participant.("Ida Idle", idle_user)

IO.puts("""
Users seeded:
  staff@example.com     (staff)
  organizer@example.com (speaker, organizes "#{organizer_workshop.name}")
  attendee@example.com  (attendee, seats in "#{organizer_workshop.name}" and "Building APIs with Ash")
  waitlisted@example.com (attendee, seat in "OTP Patterns in Practice", waitlisted for "Nerves: Embedded Elixir")
  onlywaitlist@example.com (attendee, waitlisted for "Nerves: Embedded Elixir" only)
  noworkshops@example.com (attendee, participant record but no workshops)
  sponsor@example.com   (sponsor, linked to Sponsorix AB)
""")
