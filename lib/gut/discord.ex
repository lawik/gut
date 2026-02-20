defmodule Gut.Discord do
  require Logger

  def notify_staff(message) do
    channel_id = Application.get_env(:gut, :discord_channel_id)

    if channel_id do
      channel_id = String.to_integer(channel_id)

      case Nostrum.Api.Message.create(channel_id, content: message) do
        {:ok, _msg} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to send Discord notification: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("Discord channel ID not configured, skipping notification")
      :ok
    end
  end
end
