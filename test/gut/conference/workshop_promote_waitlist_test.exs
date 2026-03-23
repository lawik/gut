defmodule Gut.Conference.WorkshopPromoteWaitlistTest do
  use Gut.DataCase

  import Gut.Generators

  @actor Gut.system_actor("test")

  defp setup_workshop(workshop_limit, room_limit) do
    room = generate(workshop_room(limit: room_limit))
    slot = generate(workshop_timeslot())

    workshop =
      generate(
        workshop(limit: workshop_limit, workshop_room_id: room.id, workshop_timeslot_id: slot.id)
      )

    {workshop, room}
  end

  defp register_participant(workshop) do
    participant = generate(workshop_participant())

    {:ok, participation} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @actor
      )

    {participant, participation}
  end

  describe "promote_waitlist" do
    test "workshop limit constrains promotion" do
      {workshop, _room} = setup_workshop(2, 100)

      # Register 2 (fills workshop limit), then 1 waitlisted
      {_, p1} = register_participant(workshop)
      {_, p2} = register_participant(workshop)
      {_, p3} = register_participant(workshop)

      assert p1.status == :registered
      assert p2.status == :registered
      assert p3.status == :waitlisted

      # Increase workshop limit to 5
      Ash.update!(Ash.Changeset.for_update(workshop, :update, %{limit: 5}), actor: @actor)

      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 1

      # Verify the waitlisted participant is now registered
      updated = Ash.get!(Gut.Conference.WorkshopParticipation, p3.id, actor: @actor)
      assert updated.status == :registered
    end

    test "room limit constrains promotion" do
      {workshop, room} = setup_workshop(100, 2)

      {_, p1} = register_participant(workshop)
      {_, p2} = register_participant(workshop)
      {_, p3} = register_participant(workshop)

      assert p1.status == :registered
      assert p2.status == :registered
      assert p3.status == :waitlisted

      # Increase room limit to 5
      Ash.update!(Ash.Changeset.for_update(room, :update, %{limit: 5}), actor: @actor)

      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 1

      updated = Ash.get!(Gut.Conference.WorkshopParticipation, p3.id, actor: @actor)
      assert updated.status == :registered
    end

    test "promotes in inserted_at order" do
      {workshop, _room} = setup_workshop(1, 100)

      # Fill workshop, then add multiple waitlisted
      {_, _p1} = register_participant(workshop)
      {_, p2} = register_participant(workshop)
      {_, p3} = register_participant(workshop)
      {_, p4} = register_participant(workshop)

      assert p2.status == :waitlisted
      assert p3.status == :waitlisted
      assert p4.status == :waitlisted

      # Increase limit to 3 (2 spots open)
      Ash.update!(Ash.Changeset.for_update(workshop, :update, %{limit: 3}), actor: @actor)

      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 2

      # First two waitlisted should be promoted, third stays waitlisted
      assert Ash.get!(Gut.Conference.WorkshopParticipation, p2.id, actor: @actor).status ==
               :registered

      assert Ash.get!(Gut.Conference.WorkshopParticipation, p3.id, actor: @actor).status ==
               :registered

      assert Ash.get!(Gut.Conference.WorkshopParticipation, p4.id, actor: @actor).status ==
               :waitlisted
    end

    test "does not over-promote" do
      {workshop, _room} = setup_workshop(3, 100)

      # Register 3, then add 5 waitlisted
      {_, _} = register_participant(workshop)
      {_, _} = register_participant(workshop)
      {_, _} = register_participant(workshop)
      {_, w1} = register_participant(workshop)
      {_, w2} = register_participant(workshop)
      {_, w3} = register_participant(workshop)
      {_, w4} = register_participant(workshop)
      {_, w5} = register_participant(workshop)

      assert w1.status == :waitlisted
      assert w5.status == :waitlisted

      # Increase limit by 2
      Ash.update!(Ash.Changeset.for_update(workshop, :update, %{limit: 5}), actor: @actor)

      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 2

      # First 2 waitlisted promoted, last 3 still waitlisted
      assert Ash.get!(Gut.Conference.WorkshopParticipation, w1.id, actor: @actor).status ==
               :registered

      assert Ash.get!(Gut.Conference.WorkshopParticipation, w2.id, actor: @actor).status ==
               :registered

      assert Ash.get!(Gut.Conference.WorkshopParticipation, w3.id, actor: @actor).status ==
               :waitlisted

      assert Ash.get!(Gut.Conference.WorkshopParticipation, w4.id, actor: @actor).status ==
               :waitlisted

      assert Ash.get!(Gut.Conference.WorkshopParticipation, w5.id, actor: @actor).status ==
               :waitlisted
    end

    test "no-op when no capacity available" do
      {workshop, _room} = setup_workshop(2, 100)

      {_, _} = register_participant(workshop)
      {_, _} = register_participant(workshop)
      {_, w1} = register_participant(workshop)

      assert w1.status == :waitlisted

      # Don't increase limit - no capacity
      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 0

      assert Ash.get!(Gut.Conference.WorkshopParticipation, w1.id, actor: @actor).status ==
               :waitlisted
    end

    test "no-op when no waitlisted participants" do
      {workshop, _room} = setup_workshop(10, 100)

      {_, p1} = register_participant(workshop)
      assert p1.status == :registered

      {:ok, promoted_count} = Gut.Conference.promote_waitlist(workshop.id, actor: @actor)
      assert promoted_count == 0
    end
  end
end
