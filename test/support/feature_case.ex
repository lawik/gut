defmodule GutWeb.FeatureCase do
  @moduledoc """
  Test case for feature/integration tests using PhoenixTest.

  Provides authenticated staff sessions for testing LiveViews.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      use GutWeb, :verified_routes

      import PhoenixTest
      import GutWeb.FeatureCase
      import Gut.Generators
    end
  end

  setup tags do
    Gut.DataCase.setup_sandbox(tags)

    user = Gut.Generators.generate(Gut.Generators.user(email: "staff@test.com", role: :staff))
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    conn = log_in_user(conn, user)

    {:ok, conn: conn, user: user}
  end

  @doc """
  Logs in a user by generating a JWT and storing it in the session.
  """
  def log_in_user(conn, user) do
    token = AshAuthentication.Jwt.token_for_user(user)

    case token do
      {:ok, token, _claims} ->
        Plug.Conn.put_session(conn, "user_token", token)

      _ ->
        raise "Failed to generate token for test user"
    end
  end

  @doc """
  Builds a conn logged in as a user with the given role.
  """
  def log_in_as(role) do
    user = Gut.Generators.generate(Gut.Generators.user(email: "#{role}@test.com", role: role))
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    log_in_user(conn, user)
  end
end
