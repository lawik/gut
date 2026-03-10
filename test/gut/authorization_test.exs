defmodule Gut.AuthorizationTest do
  use Gut.DataCase

  describe "speaker-role user is denied staff actions" do
    setup do
      user = generate(user(email: "speaker@test.com", role: :speaker))
      %{actor: user}
    end

    test "cannot see speakers", %{actor: actor} do
      generate(speaker())

      assert {:ok, []} = Gut.Conference.list_speakers(actor: actor)
    end

    test "cannot create speaker", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_speaker(
                 %{full_name: "Test", first_name: "T", last_name: "T"},
                 actor: actor
               )
    end

    test "cannot update speaker", %{actor: actor} do
      speaker = generate(speaker())

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.update_speaker(speaker, %{full_name: "Changed"}, actor: actor)
    end

    test "cannot destroy speaker", %{actor: actor} do
      speaker = generate(speaker())

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.destroy_speaker(speaker, actor: actor)
    end

    test "cannot sync from sessionize", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.sync_from_sessionize(actor: actor)
    end

    test "cannot see sponsors", %{actor: actor} do
      generate(sponsor())

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "cannot create sponsor", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "cannot see users", %{actor: actor} do
      assert {:ok, []} = Gut.Accounts.list_users(actor: actor)
    end
  end

  describe "sponsor-role user is denied staff actions" do
    setup do
      user = generate(user(email: "sponsor@test.com", role: :sponsor))
      %{actor: user}
    end

    test "cannot see speakers", %{actor: actor} do
      generate(speaker())

      assert {:ok, []} = Gut.Conference.list_speakers(actor: actor)
    end

    test "cannot create speaker", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_speaker(
                 %{full_name: "Test", first_name: "T", last_name: "T"},
                 actor: actor
               )
    end

    test "cannot sync from sessionize", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.sync_from_sessionize(actor: actor)
    end

    test "cannot see sponsors", %{actor: actor} do
      generate(sponsor())

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "cannot create sponsor", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "cannot see users", %{actor: actor} do
      assert {:ok, []} = Gut.Accounts.list_users(actor: actor)
    end
  end

  describe "attendee-role user is denied staff actions" do
    setup do
      user = generate(user(email: "attendee@test.com", role: :attendee))
      %{actor: user}
    end

    test "cannot see speakers", %{actor: actor} do
      generate(speaker())

      assert {:ok, []} = Gut.Conference.list_speakers(actor: actor)
    end

    test "cannot create speaker", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_speaker(
                 %{full_name: "Test", first_name: "T", last_name: "T"},
                 actor: actor
               )
    end

    test "cannot sync from sessionize", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.sync_from_sessionize(actor: actor)
    end

    test "cannot see sponsors", %{actor: actor} do
      generate(sponsor())

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "cannot create sponsor", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "cannot see users", %{actor: actor} do
      assert {:ok, []} = Gut.Accounts.list_users(actor: actor)
    end
  end

  describe "public actor can access browse data" do
    @public_actor Gut.public_actor()

    test "can browse workshops" do
      generate(workshop(workshop_room_id: nil, workshop_timeslot_id: nil))

      assert {:ok, [_]} = Gut.Conference.browse_workshops(actor: @public_actor)
    end

    test "can read workshop timeslots" do
      generate(workshop_timeslot())

      assert {:ok, [_]} = Gut.Conference.list_workshop_timeslots(actor: @public_actor)
    end

    test "can read workshop rooms" do
      generate(workshop_room())

      assert {:ok, [_]} = Gut.Conference.list_workshop_rooms(actor: @public_actor)
    end

    test "can read speakers" do
      generate(speaker())

      assert {:ok, [_]} = Gut.Conference.list_speakers(actor: @public_actor)
    end

    test "can create workshop participant" do
      assert {:ok, _} =
               Gut.Conference.create_workshop_participant(%{name: "Public User"},
                 actor: @public_actor
               )
    end

    test "can register for workshop" do
      room = generate(workshop_room(limit: 10))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 5, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant = generate(workshop_participant())

      assert {:ok, participation} =
               Gut.Conference.register_for_workshop(
                 %{workshop_id: workshop.id, workshop_participant_id: participant.id},
                 actor: @public_actor
               )

      assert participation.status == :registered
    end

    test "can destroy own participation" do
      room = generate(workshop_room(limit: 10))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 5, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      participant = generate(workshop_participant())

      {:ok, participation} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @public_actor
        )

      assert :ok =
               Gut.Conference.destroy_workshop_participation(participation, actor: @public_actor)
    end

    test "cannot create workshops" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_workshop(%{name: "Hack", limit: 10}, actor: @public_actor)
    end

    test "cannot create speakers" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_speaker(
                 %{full_name: "Hack", first_name: "H", last_name: "H"},
                 actor: @public_actor
               )
    end

    test "cannot see users" do
      assert {:ok, []} = Gut.Accounts.list_users(actor: @public_actor)
    end

    test "cannot see sponsors" do
      generate(sponsor())

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: @public_actor)
    end
  end

  describe "system actor internal operations" do
    @system_actor Gut.system_actor("test")

    test "speaker HandleUser creates user via system actor" do
      {:ok, speaker} =
        Gut.Conference.create_speaker(
          %{
            full_name: "New Speaker",
            first_name: "New",
            last_name: "Speaker",
            email: "new-speaker@test.com"
          },
          actor: @system_actor
        )

      assert speaker.user_id != nil
      {:ok, user} = Gut.Accounts.get_user(speaker.user_id, actor: @system_actor)
      assert user.role == :speaker
    end

    test "speaker HandleUser finds existing user via system actor" do
      existing = generate(user(email: "existing@test.com", role: :staff))

      {:ok, speaker} =
        Gut.Conference.create_speaker(
          %{full_name: "Existing", first_name: "E", last_name: "S", email: "existing@test.com"},
          actor: @system_actor
        )

      assert speaker.user_id == existing.id
    end

    test "workshop participant HandleUser creates user via system actor" do
      {:ok, participant} =
        Gut.Conference.create_workshop_participant(
          %{name: "New Participant", email: "participant@test.com"},
          actor: @system_actor
        )

      assert participant.user_id != nil
    end

    test "DetermineStatus reads workshop data via system actor" do
      room = generate(workshop_room(limit: 1))
      slot = generate(workshop_timeslot())

      workshop =
        generate(workshop(limit: 1, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

      p1 = generate(workshop_participant(name: "First"))
      p2 = generate(workshop_participant(name: "Second"))

      {:ok, reg1} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: p1.id},
          actor: @system_actor
        )

      assert reg1.status == :registered

      {:ok, reg2} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: p2.id},
          actor: @system_actor
        )

      assert reg2.status == :waitlisted
    end

    test "UniqueSlot validation reads workshop data via system actor" do
      room1 = generate(workshop_room(name: "Room 1", limit: 30))
      room2 = generate(workshop_room(name: "Room 2", limit: 30))
      slot = generate(workshop_timeslot())

      w1 =
        generate(
          workshop(
            name: "W1",
            limit: 20,
            workshop_room_id: room1.id,
            workshop_timeslot_id: slot.id
          )
        )

      w2 =
        generate(
          workshop(
            name: "W2",
            limit: 20,
            workshop_room_id: room2.id,
            workshop_timeslot_id: slot.id
          )
        )

      participant = generate(workshop_participant())

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: w1.id, workshop_participant_id: participant.id},
          actor: @system_actor
        )

      assert {:error, _} =
               Gut.Conference.register_for_workshop(
                 %{workshop_id: w2.id, workshop_participant_id: participant.id},
                 actor: @system_actor
               )
    end
  end

  describe "staff-role user is allowed" do
    setup do
      user = generate(user(email: "staff@test.com", role: :staff))
      %{actor: user}
    end

    test "can list speakers", %{actor: actor} do
      generate(speaker())

      assert {:ok, [_]} = Gut.Conference.list_speakers(actor: actor)
    end

    test "can create speaker", %{actor: actor} do
      assert {:ok, _} =
               Gut.Conference.create_speaker(
                 %{full_name: "Test", first_name: "T", last_name: "T"},
                 actor: actor
               )
    end

    test "can list sponsors", %{actor: actor} do
      generate(sponsor())

      assert {:ok, [_]} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "can create sponsor", %{actor: actor} do
      assert {:ok, _} = Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "can list users", %{actor: actor} do
      assert {:ok, [_]} = Gut.Accounts.list_users(actor: actor)
    end
  end
end
