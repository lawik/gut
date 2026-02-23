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
