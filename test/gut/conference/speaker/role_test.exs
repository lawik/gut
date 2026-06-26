defmodule Gut.Conference.Speaker.RoleTest do
  use Gut.DataCase

  @actor Gut.system_actor("test")

  defp link_workshop(speaker) do
    workshop = generate(workshop())

    Gut.Conference.WorkshopSpeaker
    |> Ash.Changeset.for_create(:create, %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @actor
    )
    |> Ash.create!()

    speaker
  end

  defp reload_role(speaker) do
    speaker
    |> Ash.load!(:role, actor: @actor)
    |> Map.fetch!(:role)
  end

  test "is nil when speaker has no workshops and no sessionize data" do
    speaker = generate(speaker(sessionize_data: nil))
    assert reload_role(speaker) == nil
  end

  test "is \"Workshop\" when the speaker only has workshop links" do
    speaker = generate(speaker(sessionize_data: %{"sessions" => [123]}))
    speaker = link_workshop(speaker)

    assert reload_role(speaker) == "Workshop"
  end

  test "is \"Conference\" when sessionize sessions exist with no workshop links" do
    speaker = generate(speaker(sessionize_data: %{"sessions" => [123, 456]}))
    assert reload_role(speaker) == "Conference"
  end

  test "is \"Both\" when workshop count is less than total sessionize sessions" do
    speaker = generate(speaker(sessionize_data: %{"sessions" => [123, 456]}))
    speaker = link_workshop(speaker)

    assert reload_role(speaker) == "Both"
  end
end
