defmodule Gut.Conference.WorkshopAttendanceTest do
  use Gut.DataCase, async: true

  @system_actor Gut.system_actor("test")

  defp register(workshop) do
    participant = generate(workshop_participant())

    Gut.Conference.register_for_workshop!(
      %{workshop_id: workshop.id, workshop_participant_id: participant.id},
      actor: @system_actor
    )
  end

  test "reports capacity, registrations, waitlist and remaining spots" do
    crowded = generate(workshop(name: "Crowded", limit: 2))
    empty = generate(workshop(name: "Empty", limit: 5))

    for _ <- 1..3, do: register(crowded)

    staff = generate(user(role: :staff))

    stats = Gut.Conference.list_workshop_attendance!(actor: staff)

    crowded_stats = Enum.find(stats, &(&1.id == crowded.id))
    assert crowded_stats.registration_count == 2
    assert crowded_stats.waitlist_count == 1
    assert crowded_stats.participant_count == 3
    assert crowded_stats.spots_remaining == 0

    empty_stats = Enum.find(stats, &(&1.id == empty.id))
    assert empty_stats.registration_count == 0
    assert empty_stats.waitlist_count == 0
    assert empty_stats.spots_remaining == 5

    fetched = Gut.Conference.get_workshop_attendance!(crowded.id, actor: staff)
    assert fetched.registration_count == 2
  end

  test "totals attendance per timeslot across its workshops" do
    slot = generate(workshop_timeslot(name: "Morning"))
    other_slot = generate(workshop_timeslot(name: "Afternoon"))
    room_a = generate(workshop_room(name: "Room A"))
    room_b = generate(workshop_room(name: "Room B"))

    first =
      generate(
        workshop(
          name: "First",
          limit: 2,
          workshop_timeslot_id: slot.id,
          workshop_room_id: room_a.id
        )
      )

    second =
      generate(
        workshop(
          name: "Second",
          limit: 10,
          workshop_timeslot_id: slot.id,
          workshop_room_id: room_b.id
        )
      )

    # 3 sign-ups for a limit of 2: 2 registered, 1 waitlisted.
    for _ <- 1..3, do: register(first)
    for _ <- 1..2, do: register(second)

    staff = generate(user(role: :staff))
    stats = Gut.Conference.list_timeslot_attendance!(actor: staff)

    morning = Enum.find(stats, &(&1.id == slot.id))
    assert morning.workshop_count == 2
    assert morning.registered_attendees == 4
    assert morning.waitlisted_attendees == 1

    afternoon = Enum.find(stats, &(&1.id == other_slot.id))
    assert afternoon.workshop_count == 0
    assert afternoon.registered_attendees == 0
  end

  test "non-staff users see no attendance stats" do
    generate(workshop(name: "Hidden", limit: 5))
    attendee = generate(user(role: :attendee))

    # Read policies filter rather than error: non-staff get nothing back.
    assert Gut.Conference.list_workshop_attendance!(actor: attendee) == []
  end
end
