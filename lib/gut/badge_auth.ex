defmodule Gut.BadgeAuth do
  @moduledoc """
  Login flow for badge hardware devices — entirely separate from user
  authentication. No Gut user account is involved, looked up, or created
  at any point; the emailed link only confirms the *device* login.

  Flow:

    1. The device POSTs an email and receives a *request token*. If the
       email belongs to a valid ticket holder (per `Gut.TitoEmailCache`),
       we email the holder a link carrying a separate *auth token*. The
       response is identical either way, so the endpoint doesn't leak who
       holds a ticket.
    2. The device polls (or long-polls) with its request token.
    3. Opening the emailed link verifies the auth token, which flips the
       request to `:verified`; waiting long-pollers are notified via `:pg`.
    4. The device's next poll returns `{:verified, %{email, role}}`.

  State lives in an ETS table owned by this GenServer, holding
  `{{:request, request_token}, entry}` rows plus an
  `{{:auth, auth_token}, request_token}` index so the emailed token can be
  resolved back to its request. Verified logins are kept for 10 minutes so
  a device that has trouble polling can still pick up the result;
  unverified requests also expire after 10 minutes.
  """

  use GenServer
  require Logger

  @table :badge_auth
  @pg_scope Gut.BadgeAuth.PG
  @pending_ttl_ms 10 * 60_000
  @verified_ttl_ms 10 * 60_000
  @sweep_every_ms 60_000

  @type status :: :unknown | :pending | {:verified, %{email: String.t(), role: atom()}}

  def pg_scope, do: @pg_scope

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Starts a badge login for `email` and returns `{:ok, request_token}`.

  Always succeeds (whether or not the email holds a ticket) so callers
  cannot probe which emails are ticket holders; the confirmation email is
  only actually sent for valid ticket holders.

  Options (mainly for tests): `:server`, `:role_lookup` (fun returning
  `{:ok, role} | :error`), `:mailer` (fun `(email, auth_token) -> any`).
  """
  @spec start_login(String.t(), keyword()) :: {:ok, String.t()}
  def start_login(email, opts \\ []) when is_binary(email) do
    server = Keyword.get(opts, :server, __MODULE__)
    role_lookup = Keyword.get(opts, :role_lookup, &Gut.TitoEmailCache.role_for_email/1)
    mailer = Keyword.get(opts, :mailer, &Gut.BadgeAuth.Email.deliver_login_link/2)

    email = normalize(email)

    role =
      case role_lookup.(email) do
        {:ok, role} -> role
        :error -> nil
      end

    {:ok, request_token, auth_token} = GenServer.call(server, {:start, email, role})

    if auth_token do
      try do
        mailer.(email, auth_token)
      rescue
        e -> Logger.error("Badge login email delivery failed: #{Exception.message(e)}")
      end
    end

    {:ok, request_token}
  end

  @doc """
  Verifies an auth token (from the emailed link). Idempotent: a second
  click on the same link also returns `{:ok, info}` while the login is
  still retained.
  """
  @spec verify(String.t(), GenServer.server()) ::
          {:ok, %{email: String.t(), role: atom()}} | :error
  def verify(auth_token, server \\ __MODULE__) when is_binary(auth_token) do
    GenServer.call(server, {:verify, auth_token})
  end

  @doc "Immediate status check for a request token."
  @spec status(String.t(), atom()) :: status()
  def status(request_token, table \\ @table) when is_binary(request_token) do
    case :ets.lookup(table, {:request, request_token}) do
      [{_, entry}] ->
        cond do
          expired?(entry) -> :unknown
          entry.state == :verified -> {:verified, %{email: entry.email, role: entry.role}}
          true -> :pending
        end

      [] ->
        :unknown
    end
  end

  @doc """
  Long-poll: like `status/1`, but a `:pending` result waits up to
  `timeout_ms` for the login to be verified before answering.
  """
  @spec await(String.t(), non_neg_integer(), keyword()) :: status()
  def await(request_token, timeout_ms, opts \\ []) when is_binary(request_token) do
    table = Keyword.get(opts, :table, @table)
    scope = Keyword.get(opts, :pg_scope, @pg_scope)

    case status(request_token, table) do
      :pending ->
        :ok = :pg.join(scope, request_token, self())

        try do
          # Re-check after joining, so a verification racing with the join
          # is not missed.
          case status(request_token, table) do
            :pending ->
              receive do
                {:badge_auth, :verified, ^request_token} -> :ok
              after
                timeout_ms -> :ok
              end

            _ ->
              :ok
          end
        after
          :pg.leave(scope, request_token, self())
        end

        # Drain a stray notification that may have arrived post-timeout.
        receive do
          {:badge_auth, :verified, ^request_token} -> :ok
        after
          0 -> :ok
        end

        status(request_token, table)

      other ->
        other
    end
  end

  ## Server

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table, @table)
    :ets.new(table, [:named_table, :protected, read_concurrency: true])

    state = %{
      table: table,
      pg_scope: Keyword.get(opts, :pg_scope, @pg_scope),
      pending_ttl: Keyword.get(opts, :pending_ttl_ms, @pending_ttl_ms),
      verified_ttl: Keyword.get(opts, :verified_ttl_ms, @verified_ttl_ms),
      sweep_every: Keyword.get(opts, :sweep_every_ms, @sweep_every_ms)
    }

    Process.send_after(self(), :sweep, state.sweep_every)
    {:ok, state}
  end

  @impl true
  def handle_call({:start, email, role}, _from, state) do
    request_token = token()
    auth_token = if role, do: token()

    entry = %{
      email: email,
      role: role,
      state: :pending,
      auth_token: auth_token,
      expires_at: now_ms() + state.pending_ttl
    }

    :ets.insert(state.table, {{:request, request_token}, entry})
    if auth_token, do: :ets.insert(state.table, {{:auth, auth_token}, request_token})

    {:reply, {:ok, request_token, auth_token}, state}
  end

  def handle_call({:verify, auth_token}, _from, state) do
    with [{_, request_token}] <- :ets.lookup(state.table, {:auth, auth_token}),
         [{_, entry}] <- :ets.lookup(state.table, {:request, request_token}),
         false <- expired?(entry) do
      entry =
        case entry.state do
          :verified ->
            entry

          :pending ->
            entry = %{entry | state: :verified, expires_at: now_ms() + state.verified_ttl}
            :ets.insert(state.table, {{:request, request_token}, entry})

            for pid <- :pg.get_members(state.pg_scope, request_token) do
              send(pid, {:badge_auth, :verified, request_token})
            end

            entry
        end

      {:reply, {:ok, %{email: entry.email, role: entry.role}}, state}
    else
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_info(:sweep, state) do
    now = now_ms()

    for {{:request, request_token}, entry} <-
          :ets.match_object(state.table, {{:request, :_}, :_}),
        entry.expires_at <= now do
      :ets.delete(state.table, {:request, request_token})
      if entry.auth_token, do: :ets.delete(state.table, {:auth, entry.auth_token})
    end

    Process.send_after(self(), :sweep, state.sweep_every)
    {:noreply, state}
  end

  defp expired?(entry), do: entry.expires_at <= now_ms()

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp token, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp normalize(email), do: email |> String.trim() |> String.downcase()
end
