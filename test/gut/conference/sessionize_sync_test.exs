defmodule Gut.Conference.SessionizeSyncTest do
  use Gut.DataCase

  alias Gut.Conference.SessionizeSync

  @actor Gut.system_actor("test")

  describe "extract_speakers/1" do
    test "extracts from a bare list" do
      data = [%{"id" => 1, "fullName" => "Alice"}, %{"id" => 2, "fullName" => "Bob"}]
      assert SessionizeSync.extract_speakers(data) == data
    end

    test "extracts from a map with speakers key" do
      speakers = [%{"id" => 1, "fullName" => "Alice"}]
      assert SessionizeSync.extract_speakers(%{"speakers" => speakers}) == speakers
    end

    test "returns empty list for map without speakers key" do
      assert SessionizeSync.extract_speakers(%{"other" => "data"}) == []
    end

    test "returns empty list for nil speakers value" do
      assert SessionizeSync.extract_speakers(%{"speakers" => nil}) == []
    end

    test "returns empty list for non-list, non-map input" do
      assert SessionizeSync.extract_speakers("garbage") == []
      assert SessionizeSync.extract_speakers(42) == []
      assert SessionizeSync.extract_speakers(nil) == []
    end
  end

  describe "build_email_map/1" do
    test "builds map from id/email pairs" do
      data = [
        %{"id" => "abc-123", "email" => "alice@example.com"},
        %{"id" => "def-456", "email" => "BOB@Example.COM"}
      ]

      result = SessionizeSync.build_email_map(data)

      assert result == %{
               "abc-123" => "alice@example.com",
               "def-456" => "bob@example.com"
             }
    end

    test "converts integer ids to strings" do
      data = [%{"id" => 123, "email" => "alice@example.com"}]
      result = SessionizeSync.build_email_map(data)
      assert result == %{"123" => "alice@example.com"}
    end

    test "skips entries missing email" do
      data = [
        %{"id" => "1", "email" => "alice@example.com"},
        %{"id" => "2"}
      ]

      result = SessionizeSync.build_email_map(data)
      assert result == %{"1" => "alice@example.com"}
    end

    test "returns empty map for non-list input" do
      assert SessionizeSync.build_email_map(nil) == %{}
      assert SessionizeSync.build_email_map("bad") == %{}
    end
  end

  describe "sync_from_data/3" do
    test "creates new speakers from sessionize data" do
      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith",
          "bio" => "Speaker bio",
          "tagLine" => "Elixir enthusiast"
        }
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 1
      assert result.errors == 0

      # Verify the speaker was created with correct data
      [speaker] = Gut.Conference.list_speakers!(actor: @actor)
      assert speaker.first_name == "Alice"
      assert speaker.last_name == "Smith"
      assert speaker.full_name == "Alice Smith"
      assert speaker.sessionize_data["bio"] == "Speaker bio"
      assert speaker.sessionize_data["tagLine"] == "Elixir enthusiast"
      assert speaker.sessionize_data["email"] == "alice@example.com"
    end

    test "stores extra fields in sessionize_data, not known fields" do
      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith",
          "sessions" => [%{"id" => 1, "name" => "Talk"}],
          "links" => [%{"url" => "https://example.com"}]
        }
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      [speaker] = Gut.Conference.list_speakers!(actor: @actor)
      # Known fields should NOT be in sessionize_data
      refute Map.has_key?(speaker.sessionize_data, "firstName")
      refute Map.has_key?(speaker.sessionize_data, "lastName")
      refute Map.has_key?(speaker.sessionize_data, "fullName")
      refute Map.has_key?(speaker.sessionize_data, "id")
      # Extra fields should be stored
      assert speaker.sessionize_data["sessions"] == [%{"id" => 1, "name" => "Talk"}]
      assert speaker.sessionize_data["links"] == [%{"url" => "https://example.com"}]
    end

    test "creates multiple speakers" do
      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith"
        },
        %{"id" => "s2", "firstName" => "Bob", "lastName" => "Jones", "fullName" => "Bob Jones"}
      ]

      email_data = [
        %{"id" => "s1", "email" => "alice@example.com"},
        %{"id" => "s2", "email" => "bob@example.com"}
      ]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 2
      assert result.errors == 0
    end

    test "updates existing speaker matched by email" do
      # Create a speaker with an email first
      {:ok, existing} =
        Gut.Conference.create_speaker(
          %{
            first_name: "Alice",
            last_name: "Old",
            full_name: "Alice Old",
            email: "alice@example.com"
          },
          actor: @actor
        )

      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith"
        }
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 1
      assert result.errors == 0

      # Should have updated, not created a new one
      speakers = Gut.Conference.list_speakers!(actor: @actor)
      assert length(speakers) == 1

      [speaker] = speakers
      assert speaker.id == existing.id
      assert speaker.full_name == "Alice Smith"
      assert speaker.last_name == "Smith"
    end

    test "skips speakers without matching email in email data" do
      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith"
        },
        %{
          "id" => "s2",
          "firstName" => "Bob",
          "lastName" => "Jones",
          "fullName" => "Bob Jones"
        }
      ]

      # Only provide email for s1
      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 1
      assert result.errors == 0

      speakers = Gut.Conference.list_speakers!(actor: @actor)
      assert length(speakers) == 1
      assert hd(speakers).full_name == "Alice Smith"
    end

    test "handles empty speaker list" do
      {:ok, result} = SessionizeSync.sync_from_data([], [], @actor)

      assert result.synced == 0
      assert result.errors == 0
    end

    test "handles speakers wrapped in map" do
      main_data = %{
        "speakers" => [
          %{
            "id" => "s1",
            "firstName" => "Alice",
            "lastName" => "Smith",
            "fullName" => "Alice Smith"
          }
        ]
      }

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 1
    end

    test "matches emails case-insensitively" do
      {:ok, _existing} =
        Gut.Conference.create_speaker(
          %{
            first_name: "Alice",
            last_name: "Old",
            full_name: "Alice Old",
            email: "Alice@Example.COM"
          },
          actor: @actor
        )

      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith"
        }
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, result} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      assert result.synced == 1

      # Should have updated, not created a second speaker
      speakers = Gut.Conference.list_speakers!(actor: @actor)
      assert length(speakers) == 1
      assert hd(speakers).full_name == "Alice Smith"
    end

    test "constructs full_name from first and last when not provided" do
      main_data = [
        %{"id" => "s1", "firstName" => "Alice", "lastName" => "Smith"}
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      [speaker] = Gut.Conference.list_speakers!(actor: @actor)
      assert speaker.full_name == "Alice Smith"
    end

    test "preserves sessionize_data email for matching on subsequent syncs" do
      main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Smith",
          "fullName" => "Alice Smith"
        }
      ]

      email_data = [%{"id" => "s1", "email" => "alice@example.com"}]

      # First sync creates the speaker
      {:ok, _} = SessionizeSync.sync_from_data(main_data, email_data, @actor)

      [speaker] = Gut.Conference.list_speakers!(actor: @actor)
      assert speaker.sessionize_data["email"] == "alice@example.com"

      # Second sync with updated name should update the same speaker
      updated_main_data = [
        %{
          "id" => "s1",
          "firstName" => "Alice",
          "lastName" => "Updated",
          "fullName" => "Alice Updated"
        }
      ]

      {:ok, result} = SessionizeSync.sync_from_data(updated_main_data, email_data, @actor)

      assert result.synced == 1
      speakers = Gut.Conference.list_speakers!(actor: @actor)
      assert length(speakers) == 1
      assert hd(speakers).full_name == "Alice Updated"
    end
  end

  describe "sync/1" do
    test "returns error when main URL is not configured" do
      Application.put_env(:gut, :sessionize_main_url, nil)
      Application.put_env(:gut, :sessionize_speaker_email_url, "http://example.com")

      assert {:error, :not_configured} = SessionizeSync.sync(@actor)
    after
      Application.delete_env(:gut, :sessionize_main_url)
      Application.delete_env(:gut, :sessionize_speaker_email_url)
    end

    test "returns error when email URL is not configured" do
      Application.put_env(:gut, :sessionize_main_url, "http://example.com")
      Application.put_env(:gut, :sessionize_speaker_email_url, nil)

      assert {:error, :not_configured} = SessionizeSync.sync(@actor)
    after
      Application.delete_env(:gut, :sessionize_main_url)
      Application.delete_env(:gut, :sessionize_speaker_email_url)
    end

    test "returns error when main URL is empty string" do
      Application.put_env(:gut, :sessionize_main_url, "")
      Application.put_env(:gut, :sessionize_speaker_email_url, "http://example.com")

      assert {:error, :not_configured} = SessionizeSync.sync(@actor)
    after
      Application.delete_env(:gut, :sessionize_main_url)
      Application.delete_env(:gut, :sessionize_speaker_email_url)
    end
  end
end
