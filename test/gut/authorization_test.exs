defmodule Gut.AuthorizationTest do
  use Gut.DataCase

  describe "speaker-role user is denied staff actions" do
    setup do
      user = Gut.Accounts.create_user!("speaker@test.com", :speaker, authorize?: false)
      %{actor: user}
    end

    test "cannot see speakers", %{actor: actor} do
      Gut.Conference.create_speaker!(
        %{full_name: "Test", first_name: "T", last_name: "T"},
        authorize?: false
      )

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
      speaker =
        Gut.Conference.create_speaker!(
          %{full_name: "Test", first_name: "T", last_name: "T"},
          authorize?: false
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.update_speaker(speaker, %{full_name: "Changed"}, actor: actor)
    end

    test "cannot destroy speaker", %{actor: actor} do
      speaker =
        Gut.Conference.create_speaker!(
          %{full_name: "Test", first_name: "T", last_name: "T"},
          authorize?: false
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.destroy_speaker(speaker, actor: actor)
    end

    test "cannot sync from sessionize", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.sync_from_sessionize(actor: actor)
    end

    test "cannot see sponsors", %{actor: actor} do
      Gut.Conference.create_sponsor!(%{name: "Test Corp"}, authorize?: false)

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "cannot create sponsor", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "cannot see users", %{actor: actor} do
      assert {:ok, []} = Gut.Accounts.list_users(actor: actor)
    end

    test "cannot see invites", %{actor: actor} do
      Gut.Accounts.create_invite!(
        %{email: "x@test.com", resource_type: :speaker, resource_id: Ash.UUID.generate()},
        authorize?: false
      )

      assert {:ok, []} = Gut.Accounts.list_invites(actor: actor)
    end
  end

  describe "sponsor-role user is denied staff actions" do
    setup do
      user = Gut.Accounts.create_user!("sponsor@test.com", :sponsor, authorize?: false)
      %{actor: user}
    end

    test "cannot see speakers", %{actor: actor} do
      Gut.Conference.create_speaker!(
        %{full_name: "Test", first_name: "T", last_name: "T"},
        authorize?: false
      )

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
      Gut.Conference.create_sponsor!(%{name: "Test Corp"}, authorize?: false)

      assert {:ok, []} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "cannot create sponsor", %{actor: actor} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "cannot see users", %{actor: actor} do
      assert {:ok, []} = Gut.Accounts.list_users(actor: actor)
    end

    test "cannot see invites", %{actor: actor} do
      Gut.Accounts.create_invite!(
        %{email: "x@test.com", resource_type: :speaker, resource_id: Ash.UUID.generate()},
        authorize?: false
      )

      assert {:ok, []} = Gut.Accounts.list_invites(actor: actor)
    end
  end

  describe "staff-role user is allowed" do
    setup do
      user = Gut.Accounts.create_user!("staff@test.com", :staff, authorize?: false)
      %{actor: user}
    end

    test "can list speakers", %{actor: actor} do
      Gut.Conference.create_speaker!(
        %{full_name: "Test", first_name: "T", last_name: "T"},
        authorize?: false
      )

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
      Gut.Conference.create_sponsor!(%{name: "Test Corp"}, authorize?: false)

      assert {:ok, [_]} = Gut.Conference.list_sponsors(actor: actor)
    end

    test "can create sponsor", %{actor: actor} do
      assert {:ok, _} = Gut.Conference.create_sponsor(%{name: "Test Corp"}, actor: actor)
    end

    test "can list users", %{actor: actor} do
      assert {:ok, [_]} = Gut.Accounts.list_users(actor: actor)
    end

    test "can list invites", %{actor: actor} do
      Gut.Accounts.create_invite!(
        %{email: "x@test.com", resource_type: :speaker, resource_id: Ash.UUID.generate()},
        authorize?: false
      )

      assert {:ok, [_]} = Gut.Accounts.list_invites(actor: actor)
    end
  end
end
