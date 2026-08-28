defmodule Gut.TitoEmailCacheTest do
  use ExUnit.Case, async: true

  alias Gut.TitoEmailCache

  @releases [
    %{"id" => 1, "title" => "Presenter's ticket"},
    %{"id" => 2, "title" => "Goatmire Elixir 2026"},
    %{"id" => 3, "title" => "Volunteer staff"}
  ]

  defp ticket(attrs) do
    Map.merge(
      %{
        "email" => "attendee@example.com",
        "state" => "complete",
        "void" => false,
        "test_mode" => false,
        "release_id" => 2,
        "tag_names" => []
      },
      attrs
    )
  end

  defp start_cache do
    id = System.unique_integer([:positive])
    table = :"tito_cache_test_#{id}"
    name = :"tito_cache_server_#{id}"

    pid = start_supervised!({TitoEmailCache, table: table, name: name, refresh_on_boot: false})
    Req.Test.allow(Gut.Tito, self(), pid)
    %{pid: pid, table: table, name: name}
  end

  defp stub_tito(tickets, releases \\ @releases) do
    Req.Test.stub(Gut.Tito, fn conn ->
      assert conn.method == "GET"

      case conn.request_path do
        "/v3/goatmire/elixir-2026/releases" ->
          Req.Test.json(conn, %{"releases" => releases, "meta" => %{"next_page" => nil}})

        "/v3/goatmire/elixir-2026/tickets" ->
          Req.Test.json(conn, %{"tickets" => tickets, "meta" => %{"next_page" => nil}})
      end
    end)
  end

  test "maps roles from release titles" do
    cache = start_cache()

    stub_tito([
      ticket(%{"email" => "speaker@example.com", "release_id" => 1}),
      ticket(%{"email" => "attendee@example.com", "release_id" => 2}),
      ticket(%{"email" => "staff@example.com", "release_id" => 3})
    ])

    assert {:ok, 3} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("speaker@example.com", cache.table) == {:ok, :presenter}
    assert TitoEmailCache.role_for_email("attendee@example.com", cache.table) == {:ok, :attendee}
    assert TitoEmailCache.role_for_email("staff@example.com", cache.table) == {:ok, :staff}
  end

  test "ticket tags override the release title" do
    cache = start_cache()
    stub_tito([ticket(%{"tag_names" => ["Staff"], "release_id" => 2})])

    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("attendee@example.com", cache.table) == {:ok, :staff}
  end

  test "skips invalid and unassigned tickets" do
    cache = start_cache()

    stub_tito([
      ticket(%{"email" => "void@example.com", "void" => true}),
      ticket(%{"email" => "test@example.com", "test_mode" => true}),
      ticket(%{"email" => nil, "state" => "unassigned"}),
      ticket(%{"email" => "  "}),
      ticket(%{"email" => "incomplete@example.com", "state" => "incomplete"})
    ])

    assert {:ok, 0} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("void@example.com", cache.table) == :error
  end

  test "lookups normalize the email" do
    cache = start_cache()
    stub_tito([ticket(%{"email" => "Mixed@Case.com"})])

    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("  mixed@CASE.com ", cache.table) == {:ok, :attendee}
  end

  test "the highest role wins when an email holds several tickets" do
    cache = start_cache()

    stub_tito([
      ticket(%{"email" => "multi@example.com", "release_id" => 2}),
      ticket(%{"email" => "multi@example.com", "release_id" => 1})
    ])

    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("multi@example.com", cache.table) == {:ok, :presenter}
  end

  test "refresh drops stale Tito entries but keeps manual ones" do
    cache = start_cache()
    stub_tito([ticket(%{"email" => "gone@example.com"})])
    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)

    :ok = TitoEmailCache.put_email("manual-staff@example.com", :staff, cache.name)

    stub_tito([ticket(%{"email" => "fresh@example.com"})])
    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)

    assert TitoEmailCache.role_for_email("gone@example.com", cache.table) == :error
    assert TitoEmailCache.role_for_email("fresh@example.com", cache.table) == {:ok, :attendee}
    assert TitoEmailCache.role_for_email("manual-staff@example.com", cache.table) == {:ok, :staff}
  end

  test "a failed refresh keeps the existing cache" do
    cache = start_cache()
    stub_tito([ticket(%{"email" => "kept@example.com"})])
    assert {:ok, 1} = TitoEmailCache.refresh(cache.name)

    Req.Test.stub(Gut.Tito, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

    assert {:error, {:http_status, 500}} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("kept@example.com", cache.table) == {:ok, :attendee}
  end

  test "refresh follows pagination" do
    cache = start_cache()

    Req.Test.stub(Gut.Tito, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case {conn.request_path, conn.query_params["page"]["number"]} do
        {"/v3/goatmire/elixir-2026/releases", _} ->
          Req.Test.json(conn, %{"releases" => @releases, "meta" => %{"next_page" => nil}})

        {"/v3/goatmire/elixir-2026/tickets", "1"} ->
          Req.Test.json(conn, %{
            "tickets" => [ticket(%{"email" => "page1@example.com"})],
            "meta" => %{"next_page" => 2}
          })

        {"/v3/goatmire/elixir-2026/tickets", "2"} ->
          Req.Test.json(conn, %{
            "tickets" => [ticket(%{"email" => "page2@example.com"})],
            "meta" => %{"next_page" => nil}
          })
      end
    end)

    assert {:ok, 2} = TitoEmailCache.refresh(cache.name)
    assert TitoEmailCache.role_for_email("page1@example.com", cache.table) == {:ok, :attendee}
    assert TitoEmailCache.role_for_email("page2@example.com", cache.table) == {:ok, :attendee}
  end
end
