defmodule Gut.Conference.Changes.NotifyDiscord do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      {type, name} = resource_info(record)

      %{"resource_type" => type, "name" => name}
      |> Gut.Workers.DiscordNotification.new()
      |> Oban.insert()

      {:ok, record}
    end)
  end

  defp resource_info(%Gut.Conference.Speaker{} = speaker), do: {"Speaker", speaker.full_name}
  defp resource_info(%Gut.Conference.Sponsor{} = sponsor), do: {"Sponsor", sponsor.name}
end
