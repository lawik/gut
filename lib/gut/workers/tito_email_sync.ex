defmodule Gut.Workers.TitoEmailSync do
  @moduledoc """
  Periodically refreshes `Gut.TitoEmailCache` from the Tito API (read-only).

  Scheduled via the Oban cron plugin; can also be enqueued manually with
  `Gut.Workers.TitoEmailSync.new(%{}) |> Oban.insert()`.
  """

  use Oban.Worker, queue: :default, unique: [period: 60]

  @impl Oban.Worker
  def perform(_job) do
    case Gut.TitoEmailCache.refresh() do
      {:ok, _count} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
