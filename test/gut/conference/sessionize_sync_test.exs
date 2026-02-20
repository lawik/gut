defmodule Gut.Conference.SessionizeSyncTest do
  use Gut.DataCase

  alias Gut.Conference.SessionizeSync

  @fixtures_path "test/support/fixtures"

  setup do
    main_data = read_fixture("sessionize_main.json")
    email_data = read_fixture("sessionize_emails.json")

    %{main_data: main_data, email_data: email_data}
  end

  defp read_fixture(filename) do
    @fixtures_path
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
  end

  describe "extract_speakers/1" do
    test "extracts from a bare list", %{main_data: main_data} do
      speakers = SessionizeSync.extract_speakers(main_data)
      assert length(speakers) == 3
      assert Enum.at(speakers, 0)["fullName"] == "Ada Lovelace"
    end

    test "extracts from a speakers wrapper" do
      wrapped = %{"speakers" => [%{"id" => "1", "fullName" => "Test"}]}
      assert [%{"fullName" => "Test"}] = SessionizeSync.extract_speakers(wrapped)
    end

    test "returns empty list for unexpected format" do
      assert SessionizeSync.extract_speakers(%{"other" => "stuff"}) == []
      assert SessionizeSync.extract_speakers("garbage") == []
      assert SessionizeSync.extract_speakers(nil) == []
    end
  end

  describe "build_email_map/1" do
    test "builds id-to-email map", %{email_data: email_data} do
      map = SessionizeSync.build_email_map(email_data)
      assert map["abc-1001"] == "ada@example.com"
      assert map["abc-1002"] == "grace@example.com"
      assert map["abc-1003"] == "alan@example.com"
    end

    test "downcases emails" do
      data = [%{"id" => "1", "email" => "LOUD@EXAMPLE.COM"}]
      map = SessionizeSync.build_email_map(data)
      assert map["1"] == "loud@example.com"
    end

    test "skips entries without email" do
      data = [%{"id" => "1"}, %{"id" => "2", "email" => "ok@example.com"}]
      map = SessionizeSync.build_email_map(data)
      assert map_size(map) == 1
    end

    test "returns empty map for non-list input" do
      assert SessionizeSync.build_email_map(%{}) == %{}
      assert SessionizeSync.build_email_map(nil) == %{}
    end
  end

  describe "sync_from_data/3" do
    test "creates new speakers from sessionize data", %{
      main_data: main_data,
      email_data: email_data
    } do
      assert {:ok, %{synced: 3, errors: 0}} =
               SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      assert length(speakers) == 3

      ada = Enum.find(speakers, &(&1.first_name == "Ada"))
      assert ada.last_name == "Lovelace"
      assert ada.full_name == "Ada Lovelace"
    end

    test "stores extra fields in sessionize_data", %{main_data: main_data, email_data: email_data} do
      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      ada = Enum.find(speakers, &(&1.first_name == "Ada"))

      assert ada.sessionize_data["bio"] == "Pioneer of computing, wrote the first algorithm."
      assert ada.sessionize_data["tagLine"] == "The first programmer"
      assert ada.sessionize_data["email"] == "ada@example.com"
      assert is_list(ada.sessionize_data["sessions"])
    end

    test "does not store known fields in sessionize_data", %{
      main_data: main_data,
      email_data: email_data
    } do
      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      ada = Enum.find(speakers, &(&1.first_name == "Ada"))

      refute Map.has_key?(ada.sessionize_data, "firstName")
      refute Map.has_key?(ada.sessionize_data, "lastName")
      refute Map.has_key?(ada.sessionize_data, "fullName")
      refute Map.has_key?(ada.sessionize_data, "id")
    end

    test "updates existing speaker matched by sessionize_data email", %{
      main_data: main_data,
      email_data: email_data
    } do
      # Create a speaker that was previously synced (has email in sessionize_data)
      Gut.Conference.create_speaker!(
        %{
          first_name: "Ada",
          last_name: "Old",
          full_name: "Ada Old",
          sessionize_data: %{"email" => "ada@example.com"}
        },
        authorize?: false
      )

      assert {:ok, %{synced: 3, errors: 0}} =
               SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      adas = Enum.filter(speakers, &(&1.first_name == "Ada"))
      assert length(adas) == 1

      ada = hd(adas)
      assert ada.last_name == "Lovelace"
      assert ada.full_name == "Ada Lovelace"
    end

    test "updates existing speaker matched by linked user email", %{
      main_data: main_data,
      email_data: email_data
    } do
      # Create a user with ada's email and a speaker linked to that user
      user = Gut.Accounts.create_user!("ada@example.com", :speaker, authorize?: false)

      Gut.Conference.create_speaker!(
        %{first_name: "Ada", last_name: "Old", full_name: "Ada Old", user_id: user.id},
        authorize?: false
      )

      assert {:ok, %{synced: 3, errors: 0}} =
               SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      adas = Enum.filter(speakers, &(&1.first_name == "Ada"))
      assert length(adas) == 1
      assert hd(adas).last_name == "Lovelace"
    end

    test "preserves existing speaker fields not set by sync", %{
      main_data: main_data,
      email_data: email_data
    } do
      Gut.Conference.create_speaker!(
        %{
          first_name: "Ada",
          last_name: "Old",
          full_name: "Ada Old",
          sessionize_data: %{"email" => "ada@example.com"},
          arrival_date: ~D[2026-06-15]
        },
        authorize?: false
      )

      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      ada = Enum.find(speakers, &(&1.first_name == "Ada"))
      assert ada.arrival_date == ~D[2026-06-15]
    end

    test "skips speakers without a matching email entry", %{main_data: main_data} do
      # Only provide emails for two of the three speakers
      partial_emails = [
        %{"id" => "abc-1001", "email" => "ada@example.com"},
        %{"id" => "abc-1002", "email" => "grace@example.com"}
      ]

      assert {:ok, %{synced: 2, errors: 0}} =
               SessionizeSync.sync_from_data(main_data, partial_emails, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      assert length(speakers) == 2
      refute Enum.any?(speakers, &(&1.first_name == "Alan"))
    end

    test "re-sync updates data without duplicating speakers", %{
      main_data: main_data,
      email_data: email_data
    } do
      {:ok, %{synced: 3}} =
        SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      {:ok, %{synced: 3}} =
        SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false)
      assert length(speakers) == 3
    end
  end

  describe "sync_from_data/2 invite handling" do
    test "creates invite for new email", %{main_data: main_data, email_data: email_data} do
      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      invites = Gut.Accounts.list_invites!(authorize?: false)
      ada_invites = Enum.filter(invites, &(to_string(&1.email) == "ada@example.com"))
      assert length(ada_invites) == 1
      assert hd(ada_invites).resource_type == :speaker
    end

    test "links existing user instead of creating invite", %{
      main_data: main_data,
      email_data: email_data
    } do
      user = Gut.Accounts.create_user!("grace@example.com", :staff, authorize?: false)

      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      speakers = Gut.Conference.list_speakers!(authorize?: false, load: [:user])
      grace = Enum.find(speakers, &(&1.first_name == "Grace"))
      assert grace.user_id == user.id

      # User role should be updated to speaker
      updated_user = Gut.Accounts.get_user!(user.id, authorize?: false)
      assert updated_user.role == :speaker
    end

    test "does not duplicate invites on re-sync when user was already linked", %{
      main_data: main_data,
      email_data: email_data
    } do
      user = Gut.Accounts.create_user!("ada@example.com", :staff, authorize?: false)

      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))
      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, Gut.system_actor("test"))

      # Ada was linked to user on first sync, second sync should find her by user email
      speakers = Gut.Conference.list_speakers!(authorize?: false)
      adas = Enum.filter(speakers, &(&1.first_name == "Ada"))
      assert length(adas) == 1
      assert hd(adas).user_id == user.id
    end
  end

  describe "sync/0 without config" do
    test "returns error when URLs not configured" do
      # The test env doesn't set these by default
      Application.put_env(:gut, :sessionize_main_url, nil)
      Application.put_env(:gut, :sessionize_speaker_email_url, nil)

      assert {:error, :not_configured} = SessionizeSync.sync(Gut.system_actor("test"))
    end
  end
end
