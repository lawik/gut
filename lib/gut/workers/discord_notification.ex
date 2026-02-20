defmodule Gut.Workers.DiscordNotification do
  use Oban.Worker, queue: :discord

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resource_type" => type, "name" => name, "changes" => changes}}) do
    message =
      ["**#{type} updated: #{name}**" | format_changes(changes)]
      |> Enum.join("\n")

    Gut.Discord.notify_staff(message)
  end

  defp format_changes(changes) do
    Enum.map(changes, fn %{"field" => field, "from" => from, "to" => to} ->
      field = field |> String.replace("_", " ") |> String.capitalize()
      "- #{field}: #{display(from)} → #{display(to)}"
    end)
  end

  defp display(nil), do: "_empty_"
  defp display(""), do: "_empty_"
  defp display(val), do: val
end
