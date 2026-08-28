defmodule Gut.BadgeAuthTest do
  use ExUnit.Case, async: true

  alias Gut.BadgeAuth

  @holder "holder@example.com"

  defp start_auth(opts \\ []) do
    id = System.unique_integer([:positive])
    table = :"badge_auth_test_#{id}"
    name = :"badge_auth_server_#{id}"

    pid = start_supervised!({BadgeAuth, [table: table, name: name] ++ opts})
    %{pid: pid, table: table, name: name}
  end

  defp start_login(auth, email, opts \\ []) do
    test_pid = self()

    BadgeAuth.start_login(
      email,
      [
        server: auth.name,
        role_lookup: fn
          @holder -> {:ok, :attendee}
          _ -> :error
        end,
        mailer: fn email, auth_token -> send(test_pid, {:email, email, auth_token}) end
      ] ++ opts
    )
  end

  test "valid ticket holder: email sent, verify flips status to verified" do
    auth = start_auth()

    {:ok, request_token} = start_login(auth, @holder)
    assert_receive {:email, @holder, auth_token}
    assert BadgeAuth.status(request_token, auth.table) == :pending

    assert {:ok, %{email: @holder, role: :attendee}} = BadgeAuth.verify(auth_token, auth.name)

    assert {:verified, %{email: @holder, role: :attendee}} =
             BadgeAuth.status(request_token, auth.table)
  end

  test "email is normalized before lookup and delivery" do
    auth = start_auth()

    {:ok, _request_token} = start_login(auth, "  HOLDER@example.COM ")
    assert_receive {:email, @holder, _auth_token}
  end

  test "unknown email: request token issued but no email sent, stays pending" do
    auth = start_auth()

    {:ok, request_token} = start_login(auth, "stranger@example.com")
    refute_receive {:email, _, _}, 50
    assert BadgeAuth.status(request_token, auth.table) == :pending
  end

  test "verify with a bogus auth token returns :error" do
    auth = start_auth()
    assert BadgeAuth.verify("no-such-token", auth.name) == :error
  end

  test "verify is idempotent" do
    auth = start_auth()

    {:ok, _request_token} = start_login(auth, @holder)
    assert_receive {:email, _, auth_token}

    assert {:ok, _} = BadgeAuth.verify(auth_token, auth.name)
    assert {:ok, %{role: :attendee}} = BadgeAuth.verify(auth_token, auth.name)
  end

  test "status for an unknown request token is :unknown" do
    auth = start_auth()
    assert BadgeAuth.status("no-such-token", auth.table) == :unknown
  end

  test "await long-polls until verification arrives" do
    auth = start_auth()

    {:ok, request_token} = start_login(auth, @holder)
    assert_receive {:email, _, auth_token}

    task =
      Task.async(fn ->
        BadgeAuth.await(request_token, 5_000, table: auth.table)
      end)

    # Give the poller time to join the pg group before verifying.
    Process.sleep(50)
    assert {:ok, _} = BadgeAuth.verify(auth_token, auth.name)

    assert {:verified, %{role: :attendee}} = Task.await(task, 1_000)
  end

  test "await returns :pending after the timeout with no verification" do
    auth = start_auth()

    {:ok, request_token} = start_login(auth, @holder)
    assert BadgeAuth.await(request_token, 50, table: auth.table) == :pending
  end

  test "await returns immediately when already verified" do
    auth = start_auth()

    {:ok, request_token} = start_login(auth, @holder)
    assert_receive {:email, _, auth_token}
    assert {:ok, _} = BadgeAuth.verify(auth_token, auth.name)

    assert {:verified, _} = BadgeAuth.await(request_token, 30_000, table: auth.table)
  end

  test "pending requests expire" do
    auth = start_auth(pending_ttl_ms: 40)

    {:ok, request_token} = start_login(auth, @holder)
    assert_receive {:email, _, auth_token}

    Process.sleep(60)
    assert BadgeAuth.status(request_token, auth.table) == :unknown
    assert BadgeAuth.verify(auth_token, auth.name) == :error
  end

  test "verified logins are kept, then expire" do
    auth = start_auth(verified_ttl_ms: 40)

    {:ok, request_token} = start_login(auth, @holder)
    assert_receive {:email, _, auth_token}
    assert {:ok, _} = BadgeAuth.verify(auth_token, auth.name)

    assert {:verified, _} = BadgeAuth.status(request_token, auth.table)
    Process.sleep(60)
    assert BadgeAuth.status(request_token, auth.table) == :unknown
  end

  test "the sweep removes expired entries from the table" do
    auth = start_auth(pending_ttl_ms: 10, sweep_every_ms: 30)

    {:ok, _request_token} = start_login(auth, @holder)
    assert_receive {:email, _, _}

    Process.sleep(80)
    assert :ets.tab2list(auth.table) == []
  end
end
