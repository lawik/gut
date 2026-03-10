defmodule Gut.Conference.WorkshopParticipationTest do
  use Gut.DataCase

  import Gut.Generators

  @actor Gut.system_actor("test")

  describe "capacity constraint" do
    test "registers participant when workshop has capacity" do
      room = generate(workshop_room(limit: 10))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 5, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant = generate(workshop_participant())

      {:ok, participation} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert participation.status == :registered
    end

    test "waitlists participant when workshop limit is reached" do
      room = generate(workshop_room(limit: 10))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 1, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant1 = generate(workshop_participant(name: "First"))
      participant2 = generate(workshop_participant(name: "Second"))

      {:ok, p1} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant1.id},
          actor: @actor
        )

      assert p1.status == :registered

      {:ok, p2} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant2.id},
          actor: @actor
        )

      assert p2.status == :waitlisted
    end

    test "uses room limit when it is lower than workshop limit" do
      room = generate(workshop_room(limit: 1))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 100, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant1 = generate(workshop_participant(name: "First"))
      participant2 = generate(workshop_participant(name: "Second"))

      {:ok, p1} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant1.id},
          actor: @actor
        )

      assert p1.status == :registered

      {:ok, p2} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant2.id},
          actor: @actor
        )

      assert p2.status == :waitlisted
    end

    test "uses workshop limit when it is lower than room limit" do
      room = generate(workshop_room(limit: 100))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 1, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant1 = generate(workshop_participant(name: "First"))
      participant2 = generate(workshop_participant(name: "Second"))

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant1.id},
          actor: @actor
        )

      {:ok, p2} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant2.id},
          actor: @actor
        )

      assert p2.status == :waitlisted
    end
  end

  describe "same-slot constraint" do
    test "prevents registration for workshop in same timeslot" do
      room1 = generate(workshop_room(name: "Room 1", limit: 30))
      room2 = generate(workshop_room(name: "Room 2", limit: 30))
      slot = generate(workshop_timeslot())

      workshop1 =
        generate(
          workshop(
            name: "Workshop A",
            limit: 20,
            workshop_room_id: room1.id,
            workshop_timeslot_id: slot.id
          )
        )

      workshop2 =
        generate(
          workshop(
            name: "Workshop B",
            limit: 20,
            workshop_room_id: room2.id,
            workshop_timeslot_id: slot.id
          )
        )

      participant = generate(workshop_participant())

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop1.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert {:error, _} =
               Gut.Conference.register_for_workshop(
                 %{workshop_id: workshop2.id, workshop_participant_id: participant.id},
                 actor: @actor
               )
    end

    test "allows registration for workshops in different timeslots" do
      room = generate(workshop_room(limit: 30))

      slot1 =
        generate(
          workshop_timeslot(
            name: "Morning",
            start: ~U[2026-06-15 09:00:00Z],
            end: ~U[2026-06-15 12:00:00Z]
          )
        )

      slot2 =
        generate(
          workshop_timeslot(
            name: "Afternoon",
            start: ~U[2026-06-15 13:00:00Z],
            end: ~U[2026-06-15 16:00:00Z]
          )
        )

      workshop1 =
        generate(
          workshop(
            name: "Workshop A",
            limit: 20,
            workshop_room_id: room.id,
            workshop_timeslot_id: slot1.id
          )
        )

      workshop2 =
        generate(
          workshop(
            name: "Workshop B",
            limit: 20,
            workshop_room_id: room.id,
            workshop_timeslot_id: slot2.id
          )
        )

      participant = generate(workshop_participant())

      {:ok, p1} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop1.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert p1.status == :registered

      {:ok, p2} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop2.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert p2.status == :registered
    end

    test "prevents registration even when already waitlisted in same slot" do
      room1 = generate(workshop_room(name: "Room 1", limit: 30))
      room2 = generate(workshop_room(name: "Room 2", limit: 30))
      slot = generate(workshop_timeslot())

      workshop1 =
        generate(
          workshop(
            name: "Full Workshop",
            limit: 1,
            workshop_room_id: room1.id,
            workshop_timeslot_id: slot.id
          )
        )

      workshop2 =
        generate(
          workshop(
            name: "Workshop B",
            limit: 20,
            workshop_room_id: room2.id,
            workshop_timeslot_id: slot.id
          )
        )

      filler = generate(workshop_participant(name: "Filler"))
      participant = generate(workshop_participant(name: "Test"))

      # Fill up workshop1 so participant gets waitlisted
      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop1.id, workshop_participant_id: filler.id},
          actor: @actor
        )

      {:ok, p1} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop1.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert p1.status == :waitlisted

      # Now try to register for workshop2 in the same slot -- should fail
      assert {:error, _} =
               Gut.Conference.register_for_workshop(
                 %{workshop_id: workshop2.id, workshop_participant_id: participant.id},
                 actor: @actor
               )
    end
  end

  describe "duplicate participation" do
    test "cannot register same participant for same workshop twice" do
      room = generate(workshop_room(limit: 30))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 20, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant = generate(workshop_participant())

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @actor
        )

      assert {:error, _} =
               Gut.Conference.register_for_workshop(
                 %{workshop_id: workshop.id, workshop_participant_id: participant.id},
                 actor: @actor
               )
    end
  end

  describe "unique room/timeslot constraint" do
    test "cannot create two workshops with the same room and timeslot" do
      room = generate(workshop_room(limit: 30))
      slot = generate(workshop_timeslot())

      {:ok, _} =
        Gut.Conference.create_workshop(
          %{
            name: "Workshop A",
            limit: 20,
            workshop_room_id: room.id,
            workshop_timeslot_id: slot.id
          },
          actor: @actor
        )

      assert {:error, _} =
               Gut.Conference.create_workshop(
                 %{
                   name: "Workshop B",
                   limit: 20,
                   workshop_room_id: room.id,
                   workshop_timeslot_id: slot.id
                 },
                 actor: @actor
               )
    end

    test "allows workshops in the same room but different timeslots" do
      room = generate(workshop_room(limit: 30))

      slot1 =
        generate(
          workshop_timeslot(
            name: "Morning",
            start: ~U[2026-06-15 09:00:00Z],
            end: ~U[2026-06-15 12:00:00Z]
          )
        )

      slot2 =
        generate(
          workshop_timeslot(
            name: "Afternoon",
            start: ~U[2026-06-15 13:00:00Z],
            end: ~U[2026-06-15 16:00:00Z]
          )
        )

      {:ok, _} =
        Gut.Conference.create_workshop(
          %{
            name: "Workshop A",
            limit: 20,
            workshop_room_id: room.id,
            workshop_timeslot_id: slot1.id
          },
          actor: @actor
        )

      assert {:ok, _} =
               Gut.Conference.create_workshop(
                 %{
                   name: "Workshop B",
                   limit: 20,
                   workshop_room_id: room.id,
                   workshop_timeslot_id: slot2.id
                 },
                 actor: @actor
               )
    end
  end
end
