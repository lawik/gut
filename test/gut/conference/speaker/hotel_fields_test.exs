defmodule Gut.Conference.Speaker.HotelFieldsTest do
  use Gut.DataCase

  @actor Gut.system_actor("test")

  describe "hotel fields on create" do
    test "defaults confirmed_with_hotel to :unconfirmed" do
      speaker = generate(speaker())
      assert speaker.confirmed_with_hotel == :unconfirmed
    end

    test "defaults wants_early_checkin to false" do
      speaker = generate(speaker())
      assert speaker.wants_early_checkin == false
    end

    test "defaults double_bed to false" do
      speaker = generate(speaker())
      assert speaker.double_bed == false
    end

    test "creates speaker with all hotel fields" do
      speaker =
        generate(
          speaker(
            room_number: "204",
            sharing_with: "Jane Doe",
            wants_early_checkin: true,
            double_bed: true,
            special_requests: "Vegetarian",
            notes: "Arrives 1 day early"
          )
        )

      assert speaker.room_number == "204"
      assert speaker.sharing_with == "Jane Doe"
      assert speaker.wants_early_checkin == true
      assert speaker.double_bed == true
      assert speaker.special_requests == "Vegetarian"
      assert speaker.notes == "Arrives 1 day early"
    end
  end

  describe "confirmed_with_hotel flip on update" do
    setup do
      speaker = generate(speaker())

      {:ok, confirmed} =
        Gut.Conference.update_speaker(speaker, %{confirmed_with_hotel: :confirmed},
          actor: @actor
        )

      %{speaker: speaker, confirmed_speaker: confirmed}
    end

    test "flips to :changed when hotel_stay_start_date changes", %{
      confirmed_speaker: speaker
    } do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{hotel_stay_start_date: ~D[2026-09-10]},
          actor: @actor
        )

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when hotel_stay_end_date changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{hotel_stay_end_date: ~D[2026-09-13]},
          actor: @actor
        )

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when hotel_covered_start_date changes", %{
      confirmed_speaker: speaker
    } do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{hotel_covered_start_date: ~D[2026-09-10]},
          actor: @actor
        )

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when hotel_covered_end_date changes", %{
      confirmed_speaker: speaker
    } do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{hotel_covered_end_date: ~D[2026-09-13]},
          actor: @actor
        )

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when room_number changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{room_number: "101"}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when sharing_with changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{sharing_with: "Someone"}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when wants_early_checkin changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{wants_early_checkin: true}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when double_bed changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{double_bed: true}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when special_requests changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{special_requests: "No nuts"}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "flips to :changed when notes changes", %{confirmed_speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{notes: "Updated info"}, actor: @actor)

      assert updated.confirmed_with_hotel == :changed
    end

    test "does not flip when non-hotel fields change", %{speaker: speaker} do
      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{full_name: "New Name"}, actor: @actor)

      assert updated.confirmed_with_hotel == :unconfirmed
    end

    test "stays :unconfirmed when hotel fields change on unconfirmed speaker", %{
      speaker: speaker
    } do
      assert speaker.confirmed_with_hotel == :unconfirmed

      {:ok, updated} =
        Gut.Conference.update_speaker(speaker, %{room_number: "101"}, actor: @actor)

      assert updated.confirmed_with_hotel == :unconfirmed
    end

    test "allows explicit confirmed_with_hotel override alongside hotel field changes", %{
      speaker: speaker
    } do
      {:ok, updated} =
        Gut.Conference.update_speaker(
          speaker,
          %{room_number: "305", confirmed_with_hotel: :confirmed},
          actor: @actor
        )

      assert updated.confirmed_with_hotel == :confirmed
    end
  end
end
