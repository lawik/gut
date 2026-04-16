defmodule Gut.Conference.WorkshopDestroyTest do
  use Gut.DataCase

  describe "destroy workshop" do
    setup do
      actor = Gut.system_actor("test")
      %{actor: actor}
    end

    test "can delete a workshop with no associations", %{actor: actor} do
      workshop = generate(workshop(workshop_room_id: nil, workshop_timeslot_id: nil))

      assert :ok = Gut.Conference.destroy_workshop(workshop, actor: actor)
    end

    test "can delete a workshop that has speakers", %{actor: actor} do
      workshop = generate(workshop(workshop_room_id: nil, workshop_timeslot_id: nil))
      speaker = generate(speaker())

      Gut.Conference.create_workshop_speaker(
        %{workshop_id: workshop.id, speaker_id: speaker.id},
        actor: actor
      )

      assert :ok = Gut.Conference.destroy_workshop(workshop, actor: actor)
    end

    test "cannot delete a workshop that has participations", %{actor: actor} do
      workshop = generate(workshop(workshop_room_id: nil, workshop_timeslot_id: nil))
      participant = generate(workshop_participant())

      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: actor
      )

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.destroy_workshop(workshop, actor: actor)
    end

    test "cannot delete a workshop that has both speakers and participations", %{actor: actor} do
      workshop = generate(workshop(workshop_room_id: nil, workshop_timeslot_id: nil))
      speaker = generate(speaker())
      participant = generate(workshop_participant())

      Gut.Conference.create_workshop_speaker(
        %{workshop_id: workshop.id, speaker_id: speaker.id},
        actor: actor
      )

      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: actor
      )

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.destroy_workshop(workshop, actor: actor)
    end
  end
end
