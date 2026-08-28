# Tests drive the client against a tiny gen_tcp HTTP stub, so :httpc,
# paths, bodies, and long-polling are exercised for real.

defmodule Goatmire.BadgeClientTest.TestServer do
  @moduledoc """
  Minimal one-shot-per-connection HTTP server. `handler` receives
  `(method, path_with_query, headers_map, body)` and returns
  `{status, json_body}`.
  """

  def start(handler) do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listen)
    spawn_link(fn -> accept_loop(listen, handler) end)
    {port, listen}
  end

  defp accept_loop(listen, handler) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        spawn_link(fn -> handle(socket, handler) end)
        accept_loop(listen, handler)

      {:error, :closed} ->
        :ok
    end
  end

  defp handle(socket, handler) do
    {head, partial_body} = read_head(socket, <<>>)
    [request_line | header_lines] = String.split(head, "\r\n")
    [method, path, _version] = String.split(request_line, " ")

    headers =
      Map.new(header_lines, fn line ->
        [k, v] = String.split(line, ": ", parts: 2)
        {String.downcase(k), v}
      end)

    content_length = String.to_integer(headers["content-length"] || "0")
    body = read_body(socket, partial_body, content_length)

    {status, resp_body} = handler.(method, path, headers, body)

    reason = %{200 => "OK", 400 => "Bad Request", 404 => "Not Found", 500 => "Error"}[status]

    :gen_tcp.send(socket, [
      "HTTP/1.1 #{status} #{reason}\r\n",
      "content-type: application/json; charset=utf-8\r\n",
      "content-length: #{byte_size(resp_body)}\r\n",
      "connection: close\r\n\r\n",
      resp_body
    ])

    :gen_tcp.close(socket)
  end

  defp read_head(socket, acc) do
    case :binary.match(acc, "\r\n\r\n") do
      {pos, 4} ->
        <<head::binary-size(pos), _::binary-size(4), rest::binary>> = acc
        {head, rest}

      :nomatch ->
        {:ok, data} = :gen_tcp.recv(socket, 0, 5_000)
        read_head(socket, acc <> data)
    end
  end

  defp read_body(_socket, acc, len) when byte_size(acc) >= len, do: acc

  defp read_body(socket, acc, len) do
    {:ok, data} = :gen_tcp.recv(socket, 0, 5_000)
    read_body(socket, acc <> data, len)
  end
end

defmodule Goatmire.BadgeClientTest do
  use ExUnit.Case, async: true

  alias Goatmire.BadgeClient

  setup_all do
    BadgeClient.start()
    :ok
  end

  defp start_server(handler) do
    {port, _listen} = Goatmire.BadgeClientTest.TestServer.start(handler)
    "http://127.0.0.1:#{port}"
  end

  # -- JSON -----------------------------------------------------------

  describe "json_encode/1" do
    test "encodes the request body shape" do
      assert BadgeClient.json_encode(%{"email" => "a@b.se"}) == ~s({"email":"a@b.se"})
    end

    test "escapes quotes, backslashes and control characters" do
      assert BadgeClient.json_encode("a\"b\\c\nd\x01") == ~s("a\\"b\\\\c\\nd\\u0001")
    end

    test "encodes scalars, lists and atoms" do
      assert BadgeClient.json_encode([1, -2.5, true, false, nil, :ok]) ==
               ~s([1,-2.5,true,false,null,"ok"])
    end
  end

  describe "json_decode/1" do
    test "decodes nested structures" do
      assert BadgeClient.json_decode(~s({"a": [1, {"b": null}], "c": "x", "d": true})) ==
               {:ok, %{"a" => [1, %{"b" => nil}], "c" => "x", "d" => true}}
    end

    test "decodes escapes and unicode, including surrogate pairs" do
      assert BadgeClient.json_decode(~s("l\\u00e4get \\u00e5\\n\\"\\u0001 \\ud83d\\ude00")) ==
               {:ok, "läget å\n\"\x01 😀"}
    end

    test "decodes numbers" do
      assert BadgeClient.json_decode("[0, -12, 3.5, -0.25, 1e3, 2.5E-1]") ==
               {:ok, [0, -12, 3.5, -0.25, 1.0e3, 0.25]}
    end

    test "rejects invalid documents" do
      for bad <- [
            "",
            "{",
            ~s({"a"}),
            "[1,]",
            ~s({"a":1,}),
            ~s("unterminated),
            "12x",
            ~s({"a":1} trailing)
          ] do
        assert BadgeClient.json_decode(bad) == {:error, :invalid_json}, "expected invalid: #{bad}"
      end
    end
  end

  # -- start_login ----------------------------------------------------

  describe "start_login/2" do
    test "POSTs JSON to /api/badge_login and returns the request token" do
      test_pid = self()

      base =
        start_server(fn method, path, headers, body ->
          send(test_pid, {:request, method, path, headers, body})
          {200, ~s({"request_token":"req-123","message":"Check your email"})}
        end)

      assert BadgeClient.start_login(base, "me@example.com") == {:ok, "req-123"}

      assert_receive {:request, "POST", "/api/badge_login", headers, body}
      assert headers["content-type"] =~ "application/json"
      assert BadgeClient.json_decode(body) == {:ok, %{"email" => "me@example.com"}}
    end

    test "a trailing slash on the base url is tolerated" do
      base =
        start_server(fn _, path, _, _ ->
          {200, ~s({"request_token":"tok-#{path == "/api/badge_login"}"})}
        end)

      assert BadgeClient.start_login(base <> "/", "me@example.com") == {:ok, "tok-true"}
    end

    test "non-200 responses and connection errors surface as errors" do
      base = start_server(fn _, _, _, _ -> {500, ~s({"oops":true})} end)
      assert BadgeClient.start_login(base, "me@example.com") == {:error, {:http, 500}}

      assert {:error, _reason} =
               BadgeClient.start_login("http://127.0.0.1:1", "me@example.com")
    end
  end

  # -- check / await --------------------------------------------------

  describe "check/2" do
    test "parses pending, verified, and unknown" do
      base =
        start_server(fn "GET", path, _, _ ->
          case path do
            "/api/badge_login/pending-tok" ->
              {200, ~s({"status":"pending"})}

            "/api/badge_login/done-tok" ->
              {200, ~s({"status":"verified","email":"me@example.com","role":"presenter"})}

            _ ->
              {404, ~s({"status":"unknown"})}
          end
        end)

      assert BadgeClient.check(base, "pending-tok") == {:ok, :pending}

      assert BadgeClient.check(base, "done-tok") ==
               {:ok, {:verified, "me@example.com", :presenter}}

      assert BadgeClient.check(base, "expired-tok") == {:error, :unknown_token}
    end
  end

  describe "await/3" do
    test "passes ?long=N (clamped to 1..60) and waits out the server delay" do
      test_pid = self()

      base =
        start_server(fn "GET", path, _, _ ->
          send(test_pid, {:path, path})
          Process.sleep(300)
          {200, ~s({"status":"verified","email":"me@example.com","role":"staff"})}
        end)

      started = System.monotonic_time(:millisecond)
      assert BadgeClient.await(base, "tok", 2) == {:ok, {:verified, "me@example.com", :staff}}
      assert System.monotonic_time(:millisecond) - started >= 300

      assert_receive {:path, "/api/badge_login/tok?long=2"}

      BadgeClient.await(base, "tok", 999)
      assert_receive {:path, "/api/badge_login/tok?long=60"}
      BadgeClient.await(base, "tok", 0)
      assert_receive {:path, "/api/badge_login/tok?long=1"}
    end
  end

  # -- login (full flow) ----------------------------------------------

  describe "login/4" do
    test "starts a login, then long-polls until verified" do
      counter = :ets.new(:counter, [:public])
      :ets.insert(counter, {:polls, 0})

      base =
        start_server(fn
          "POST", "/api/badge_login", _, _ ->
            {200, ~s({"request_token":"flow-tok"})}

          "GET", "/api/badge_login/flow-tok?long=" <> _, _, _ ->
            case :ets.update_counter(counter, :polls, 1) do
              n when n < 3 -> {200, ~s({"status":"pending"})}
              _ -> {200, ~s({"status":"verified","email":"me@example.com","role":"attendee"})}
            end
        end)

      assert BadgeClient.login(base, "me@example.com", 30, 1) ==
               {:ok, "me@example.com", :attendee}

      assert :ets.lookup_element(counter, :polls, 2) == 3
    end

    test "gives up with {:error, :timeout} when never verified" do
      base =
        start_server(fn
          "POST", _, _, _ -> {200, ~s({"request_token":"never-tok"})}
          "GET", _, _, _ -> {200, ~s({"status":"pending"})}
        end)

      started = System.monotonic_time(:millisecond)
      assert BadgeClient.login(base, "me@example.com", 2, 1) == {:error, :timeout}
      elapsed = System.monotonic_time(:millisecond) - started
      assert elapsed >= 1_000 and elapsed < 10_000
    end

    test "stops immediately when the token becomes unknown" do
      base =
        start_server(fn
          "POST", _, _, _ -> {200, ~s({"request_token":"gone-tok"})}
          "GET", _, _, _ -> {404, ~s({"status":"unknown"})}
        end)

      assert BadgeClient.login(base, "me@example.com", 30, 1) == {:error, :unknown_token}
    end
  end
end
