defmodule Gut.TitoEmailCache do
  @moduledoc """
  ETS cache mapping hashed ticket-holder emails to their conference role.

  Refreshed from the Tito Admin API (read-only) by `Gut.Workers.TitoEmailSync`.
  Emails are normalized (trimmed, downcased) and stored only as SHA-256
  hashes, so the cache never holds plain attendee emails.

  Roles are `:staff`, `:presenter`, or `:attendee`, derived per ticket:
  ticket tags win over the release (ticket type) title, and when one email
  holds several tickets the highest-ranked role wins. Entries added with
  `put_email/2` (e.g. staff without a Tito ticket) survive refreshes.
  """

  use GenServer
  require Logger

  @table :tito_email_cache
  @roles [:staff, :presenter, :attendee]
  @role_rank %{staff: 2, presenter: 1, attendee: 0}

  ## Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Looks up the role for an email, if it holds a valid ticket."
  @spec role_for_email(String.t(), atom()) :: {:ok, atom()} | :error
  def role_for_email(email, table \\ @table) when is_binary(email) do
    case :ets.lookup(table, hash_email(email)) do
      [{_hash, role, _source}] -> {:ok, role}
      [] -> :error
    end
  end

  @doc "Re-pulls ticket holders from Tito and updates the cache."
  @spec refresh(GenServer.server()) :: {:ok, non_neg_integer()} | {:error, term()}
  def refresh(server \\ __MODULE__), do: GenServer.call(server, :refresh, 60_000)

  @doc """
  Manually adds an email → role entry, e.g. staff who hold no Tito ticket.
  Manual entries are kept across refreshes (but a Tito ticket for the same
  email takes precedence).
  """
  def put_email(email, role, server \\ __MODULE__)
      when is_binary(email) and role in @roles do
    GenServer.call(server, {:put, hash_email(email), role})
  end

  @doc "SHA-256 hash of the normalized (trimmed, downcased) email."
  def hash_email(email) when is_binary(email) do
    :crypto.hash(:sha256, email |> String.trim() |> String.downcase())
  end

  ## Server

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table, @table)
    :ets.new(table, [:named_table, :protected, read_concurrency: true])
    state = %{table: table}

    refresh_on_boot? =
      Keyword.get(
        opts,
        :refresh_on_boot,
        Application.get_env(:gut, :tito_cache_refresh_on_boot, true)
      )

    if refresh_on_boot? do
      {:ok, state, {:continue, :refresh}}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_continue(:refresh, state) do
    case do_refresh(state.table) do
      {:ok, count} ->
        Logger.info("TitoEmailCache warmed with #{count} ticket-holder emails")

      {:error, reason} ->
        Logger.warning("TitoEmailCache boot refresh failed: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    {:reply, do_refresh(state.table), state}
  end

  def handle_call({:put, hash, role}, _from, state) do
    :ets.insert(state.table, {hash, role, :manual})
    {:reply, :ok, state}
  end

  defp do_refresh(table) do
    with {:ok, releases} <- Gut.Tito.list_releases(),
         {:ok, tickets} <- Gut.Tito.list_tickets() do
      release_roles =
        Map.new(releases, fn release ->
          {release["id"], role_from_title(release["title"] || "")}
        end)

      new_entries =
        tickets
        |> Enum.filter(&Gut.Tito.valid_ticket_map?/1)
        |> Enum.reduce(%{}, fn ticket, acc ->
          email = ticket["email"] || ""

          if String.trim(email) == "" do
            acc
          else
            role = ticket_role(ticket, release_roles)
            Map.update(acc, hash_email(email), role, &max_role(&1, role))
          end
        end)

      stale =
        table
        |> :ets.select([{{:"$1", :_, :tito}, [], [:"$1"]}])
        |> Enum.reject(&Map.has_key?(new_entries, &1))

      :ets.insert(table, Enum.map(new_entries, fn {hash, role} -> {hash, role, :tito} end))
      Enum.each(stale, &:ets.delete(table, &1))

      {:ok, map_size(new_entries)}
    end
  end

  defp ticket_role(ticket, release_roles) do
    tags = ticket["tag_names"] || []

    role_from_tags(tags) || Map.get(release_roles, ticket["release_id"], :attendee)
  end

  defp role_from_tags(tags) do
    tags = Enum.map(tags, &String.downcase/1)

    cond do
      Enum.any?(tags, &(&1 =~ ~r/staff|crew|organi[sz]er/)) -> :staff
      Enum.any?(tags, &(&1 =~ ~r/presenter|speaker/)) -> :presenter
      true -> nil
    end
  end

  defp role_from_title(title) do
    cond do
      title =~ ~r/staff|crew|organi[sz]er/i -> :staff
      title =~ ~r/presenter|speaker/i -> :presenter
      true -> :attendee
    end
  end

  defp max_role(a, b), do: if(@role_rank[a] >= @role_rank[b], do: a, else: b)
end
