defmodule Gut.Conference.Changes.NotifyDiscordTest do
  use Gut.DataCase
  use Oban.Testing, repo: Gut.Repo

  @actor Gut.system_actor("test")

  defp update_speaker(speaker, attrs) do
    Gut.Conference.update_speaker!(speaker, attrs, actor: @actor)
  end

  defp update_sponsor(sponsor, attrs) do
    Gut.Conference.update_sponsor!(sponsor, attrs, actor: @actor)
  end

  describe "speaker updates" do
    test "enqueues notification when values change" do
      speaker = generate(speaker())

      update_speaker(speaker, %{full_name: "Ada Byron"})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "resource_type" => "Speaker",
          "name" => "Ada Byron",
          "changes" => [%{"field" => "full_name", "from" => "Ada Lovelace", "to" => "Ada Byron"}]
        }
      )
    end

    test "does not enqueue notification when no values change" do
      speaker = generate(speaker())

      update_speaker(speaker, %{full_name: "Ada Lovelace"})

      refute_enqueued(worker: Gut.Workers.DiscordNotification)
    end

    test "includes only changed fields in notification" do
      speaker = generate(speaker())

      update_speaker(speaker, %{
        full_name: "Ada Lovelace",
        first_name: "Ada",
        last_name: "Byron"
      })

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "resource_type" => "Speaker",
          "name" => "Ada Lovelace",
          "changes" => [%{"field" => "last_name", "from" => "Lovelace", "to" => "Byron"}]
        }
      )
    end

    test "formats date values as strings" do
      speaker = generate(speaker())

      update_speaker(speaker, %{arrival_date: ~D[2026-06-15]})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "resource_type" => "Speaker",
          "changes" => [
            %{"field" => "arrival_date", "from" => nil, "to" => "2026-06-15"}
          ]
        }
      )
    end

    test "formats time values as strings" do
      speaker = generate(speaker())

      update_speaker(speaker, %{arrival_time: ~T[14:30:00]})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "changes" => [
            %{"field" => "arrival_time", "from" => nil, "to" => "14:30:00"}
          ]
        }
      )
    end

    test "formats map values as complex data" do
      speaker = generate(speaker())

      update_speaker(speaker, %{sessionize_data: %{"bio" => "Hello"}})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "changes" => [
            %{
              "field" => "sessionize_data",
              "from" => nil,
              "to" => "_(complex data)_"
            }
          ]
        }
      )
    end

    test "tracks multiple changes in one update" do
      speaker = generate(speaker())

      update_speaker(speaker, %{
        first_name: "Grace",
        last_name: "Hopper",
        full_name: "Grace Hopper",
        arrival_date: ~D[2026-06-15]
      })

      assert_enqueued(worker: Gut.Workers.DiscordNotification)

      [job] = all_enqueued(worker: Gut.Workers.DiscordNotification)
      changes = job.args["changes"]

      fields = Enum.map(changes, & &1["field"]) |> Enum.sort()
      assert "arrival_date" in fields
      assert "first_name" in fields
      assert "full_name" in fields
      assert "last_name" in fields
    end
  end

  describe "sponsor updates" do
    test "enqueues notification when values change" do
      sponsor = generate(sponsor())

      update_sponsor(sponsor, %{status: :warm})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "resource_type" => "Sponsor",
          "name" => "Acme Corp",
          "changes" => [%{"field" => "status", "from" => "cold", "to" => "warm"}]
        }
      )
    end

    test "does not enqueue notification when no values change" do
      sponsor = generate(sponsor())

      update_sponsor(sponsor, %{name: "Acme Corp"})

      refute_enqueued(worker: Gut.Workers.DiscordNotification)
    end

    test "formats boolean changes" do
      sponsor = generate(sponsor())

      update_sponsor(sponsor, %{confirmed: true})

      assert_enqueued(
        worker: Gut.Workers.DiscordNotification,
        args: %{
          "changes" => [%{"field" => "confirmed", "from" => "false", "to" => "true"}]
        }
      )
    end
  end
end
