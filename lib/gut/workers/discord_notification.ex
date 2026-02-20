defmodule Gut.Workers.DiscordNotification do
  use Oban.Worker, queue: :discord

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resource_type" => type, "name" => name}}) do
    Gut.Discord.notify_staff("#{type} updated: **#{name}**")
  end
end
