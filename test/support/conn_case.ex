defmodule GutWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use GutWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint GutWeb.Endpoint

      use GutWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import GutWeb.ConnCase
    end
  end

  setup tags do
    pid = Gut.DataCase.setup_sandbox(tags)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Gut.Repo, pid)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header(
        "user-agent",
        Phoenix.Ecto.SQL.Sandbox.encode_metadata(metadata)
      )

    {:ok, conn: conn}
  end
end
