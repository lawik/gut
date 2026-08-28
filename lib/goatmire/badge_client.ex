defmodule Goatmire.BadgeClient do
  @moduledoc """
  Client for the Goatmire badge login API. Zero dependencies: plain
  Erlang `:httpc` plus a built-in minimal JSON encoder/decoder, written
  against the Elixir/OTP subset that AtomVM supports (binary pattern
  matching and `:erlang`/`:maps`/`:lists` BIFs — no `Enum`, `String`,
  `Keyword`, or `Regex`).

  Maintained here; distributed to badge devices as a single file (gist).

  ## Usage

      Goatmire.BadgeClient.start()

      base = "https://gut.example.com"
      {:ok, email, role} = Goatmire.BadgeClient.login(base, "me@example.com")
      # role is :staff | :presenter | :attendee

  `login/2,3,4` runs the whole flow: it POSTs the email, tells the user
  to check their inbox, then long-polls until the emailed link is
  clicked (or the deadline passes). The individual steps are also
  public if you want to drive your own UI between them:

      {:ok, token} = Goatmire.BadgeClient.start_login(base, "me@example.com")
      # show "check your email" on the badge...
      {:ok, :pending} = Goatmire.BadgeClient.check(base, token)
      {:ok, {:verified, email, role}} = Goatmire.BadgeClient.await(base, token, 25)

  ## AtomVM notes

  * Pack the `inets` (and `ssl`, for https) application beams into your
    .avm image alongside this module; `:httpc` is pure Erlang.
  * Call `start/0` once before use (it starts `inets`/`ssl`, tolerating
    "already started" and a missing `ssl`).
  * For `https` URLs this module uses `verify: :verify_none`, because a
    badge has no CA store. That means no server authentication — use it
    on a trusted network, or swap in `:public_key.cacerts_get()` when
    running on full OTP.
  """

  @default_long_seconds 25
  @default_total_seconds 120
  @request_timeout_ms 10_000

  ## ------------------------------------------------------------------
  ## High level flow
  ## ------------------------------------------------------------------

  @doc """
  Full login flow: start a login for `email`, then long-poll until it is
  verified. Returns `{:ok, email, role}`, `{:error, :timeout}` when
  `total_seconds` elapse unverified, or `{:error, reason}`.
  """
  def login(
        base_url,
        email,
        total_seconds \\ @default_total_seconds,
        long_seconds \\ @default_long_seconds
      ) do
    case start_login(base_url, email) do
      {:ok, token} ->
        deadline = now_ms() + total_seconds * 1000
        poll_until(base_url, token, deadline, long_seconds)

      error ->
        error
    end
  end

  defp poll_until(base_url, token, deadline, long_seconds) do
    remaining_s = div(deadline - now_ms(), 1000)

    cond do
      remaining_s <= 0 ->
        {:error, :timeout}

      true ->
        long = min(long_seconds, remaining_s)

        case await(base_url, token, long) do
          {:ok, {:verified, email, role}} -> {:ok, email, role}
          {:ok, :pending} -> poll_until(base_url, token, deadline, long_seconds)
          {:error, :unknown_token} -> {:error, :unknown_token}
          error -> error
        end
    end
  end

  ## ------------------------------------------------------------------
  ## Individual steps
  ## ------------------------------------------------------------------

  @doc """
  POST /api/badge_login. Returns `{:ok, request_token}`. Always succeeds
  for well-formed emails — the server answers identically whether or not
  the email holds a ticket, and only emails actual ticket holders.
  """
  def start_login(base_url, email) do
    url = base(base_url) <> "/api/badge_login"
    body = json_encode(%{"email" => email})

    case request(:post, url, body, @request_timeout_ms) do
      {:ok, 200, resp} ->
        case json_decode(resp) do
          {:ok, %{"request_token" => token}} when is_binary(token) -> {:ok, token}
          _ -> {:error, :bad_response}
        end

      {:ok, status, _} ->
        {:error, {:http, status}}

      error ->
        error
    end
  end

  @doc """
  GET /api/badge_login/:token — immediate status check.
  Returns `{:ok, :pending}`, `{:ok, {:verified, email, role}}`, or
  `{:error, :unknown_token}` once the token has expired.
  """
  def check(base_url, request_token) do
    status_request(base(base_url) <> "/api/badge_login/" <> request_token, @request_timeout_ms)
  end

  @doc """
  GET /api/badge_login/:token?long=N — long-poll: the server holds the
  request up to `long_seconds` (max 60) waiting for verification.
  Same returns as `check/2`.
  """
  def await(base_url, request_token, long_seconds \\ @default_long_seconds) do
    long = clamp(long_seconds, 1, 60)

    url =
      base(base_url) <>
        "/api/badge_login/" <> request_token <> "?long=" <> :erlang.integer_to_binary(long)

    status_request(url, long * 1000 + 10_000)
  end

  defp status_request(url, timeout_ms) do
    case request(:get, url, nil, timeout_ms) do
      {:ok, 200, resp} ->
        case json_decode(resp) do
          {:ok, %{"status" => "pending"}} ->
            {:ok, :pending}

          {:ok, %{"status" => "verified", "email" => email, "role" => role}} ->
            {:ok, {:verified, email, role_atom(role)}}

          _ ->
            {:error, :bad_response}
        end

      {:ok, 404, _} ->
        {:error, :unknown_token}

      {:ok, status, _} ->
        {:error, {:http, status}}

      error ->
        error
    end
  end

  defp role_atom("staff"), do: :staff
  defp role_atom("presenter"), do: :presenter
  defp role_atom("attendee"), do: :attendee
  defp role_atom(other), do: other

  ## ------------------------------------------------------------------
  ## HTTP plumbing
  ## ------------------------------------------------------------------

  @doc "Starts `inets` (and `ssl` when present). Call once before use."
  def start do
    _ = :inets.start()

    try do
      :ssl.start()
    catch
      _, _ -> :ok
    end

    :ok
  end

  defp request(method, url, body, timeout_ms) do
    headers = [{~c"accept", ~c"application/json"}]

    req =
      case body do
        nil -> {to_cl(url), headers}
        b -> {to_cl(url), headers, ~c"application/json", :erlang.binary_to_list(b)}
      end

    http_options = [timeout: timeout_ms] ++ ssl_options(url)

    case :httpc.request(method, req, http_options, body_format: :binary) do
      {:ok, {{_version, status, _reason}, _headers, resp_body}} ->
        {:ok, status, to_bin(resp_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ssl_options(<<"https", _::binary>>), do: [ssl: [verify: :verify_none]]
  defp ssl_options(_), do: []

  defp base(url) do
    size = byte_size(url) - 1

    case url do
      <<prefix::binary-size(^size), "/">> -> prefix
      _ -> url
    end
  end

  defp clamp(n, lo, _hi) when n < lo, do: lo
  defp clamp(n, _lo, hi) when n > hi, do: hi
  defp clamp(n, _lo, _hi), do: n

  defp now_ms, do: :erlang.monotonic_time(:millisecond)

  defp to_cl(bin) when is_binary(bin), do: :erlang.binary_to_list(bin)

  defp to_bin(l) when is_list(l), do: :erlang.list_to_binary(l)
  defp to_bin(b) when is_binary(b), do: b

  ## ------------------------------------------------------------------
  ## Minimal JSON (just enough for this API; no dependencies)
  ## ------------------------------------------------------------------

  @doc "Encodes maps, lists, binaries, atoms, numbers, booleans and nil."
  def json_encode(value), do: :erlang.iolist_to_binary(enc(value))

  defp enc(nil), do: "null"
  defp enc(true), do: "true"
  defp enc(false), do: "false"
  defp enc(n) when is_integer(n), do: :erlang.integer_to_binary(n)
  defp enc(f) when is_float(f), do: :erlang.float_to_binary(f, [:short])
  defp enc(b) when is_binary(b), do: [?", esc(b, <<>>), ?"]
  defp enc(a) when is_atom(a), do: enc(:erlang.atom_to_binary(a, :utf8))
  defp enc(l) when is_list(l), do: [?[, enc_join(l), ?]]

  defp enc(m) when is_map(m) do
    [?{, enc_join_pairs(:maps.to_list(m)), ?}]
  end

  defp enc_join([]), do: []
  defp enc_join([x]), do: [enc(x)]
  defp enc_join([x | rest]), do: [enc(x), ?, | enc_join(rest)]

  defp enc_join_pairs([]), do: []
  defp enc_join_pairs([{k, v}]), do: [enc_key(k), ?:, enc(v)]
  defp enc_join_pairs([{k, v} | rest]), do: [enc_key(k), ?:, enc(v), ?, | enc_join_pairs(rest)]

  defp enc_key(k) when is_binary(k), do: enc(k)
  defp enc_key(k) when is_atom(k), do: enc(:erlang.atom_to_binary(k, :utf8))

  defp esc(<<>>, acc), do: acc
  defp esc(<<?", rest::binary>>, acc), do: esc(rest, <<acc::binary, "\\\"">>)
  defp esc(<<?\\, rest::binary>>, acc), do: esc(rest, <<acc::binary, "\\\\">>)
  defp esc(<<?\n, rest::binary>>, acc), do: esc(rest, <<acc::binary, "\\n">>)
  defp esc(<<?\r, rest::binary>>, acc), do: esc(rest, <<acc::binary, "\\r">>)
  defp esc(<<?\t, rest::binary>>, acc), do: esc(rest, <<acc::binary, "\\t">>)

  defp esc(<<c, rest::binary>>, acc) when c < 0x20 do
    hex = :erlang.integer_to_binary(c, 16)
    pad = if byte_size(hex) == 1, do: <<"000", hex::binary>>, else: <<"00", hex::binary>>
    esc(rest, <<acc::binary, "\\u", pad::binary>>)
  end

  defp esc(<<c, rest::binary>>, acc), do: esc(rest, <<acc::binary, c>>)

  @doc "Decodes a JSON document. Returns `{:ok, term}` or `{:error, :invalid_json}`."
  def json_decode(bin) when is_binary(bin) do
    try do
      {value, rest} = dec_value(skip_ws(bin))

      case skip_ws(rest) do
        <<>> -> {:ok, value}
        _ -> {:error, :invalid_json}
      end
    catch
      _, _ -> {:error, :invalid_json}
    end
  end

  defp skip_ws(<<c, rest::binary>>) when c == ?\s or c == ?\t or c == ?\n or c == ?\r,
    do: skip_ws(rest)

  defp skip_ws(bin), do: bin

  defp dec_value(<<"true", rest::binary>>), do: {true, rest}
  defp dec_value(<<"false", rest::binary>>), do: {false, rest}
  defp dec_value(<<"null", rest::binary>>), do: {nil, rest}
  defp dec_value(<<?", rest::binary>>), do: dec_string(rest, <<>>)
  defp dec_value(<<?{, rest::binary>>), do: dec_object(skip_ws(rest), %{})
  defp dec_value(<<?[, rest::binary>>), do: dec_array(skip_ws(rest), [])

  defp dec_value(<<c, _::binary>> = bin) when c == ?- or (c >= ?0 and c <= ?9),
    do: dec_number(bin, <<>>)

  defp dec_value(_), do: throw(:invalid_json)

  defp dec_object(<<?}, rest::binary>>, acc), do: {acc, rest}

  defp dec_object(<<?", rest::binary>>, acc) do
    {key, rest} = dec_string(rest, <<>>)

    rest =
      case skip_ws(rest) do
        <<?:, r::binary>> -> r
        _ -> throw(:invalid_json)
      end

    {value, rest} = dec_value(skip_ws(rest))
    acc = :maps.put(key, value, acc)

    case skip_ws(rest) do
      <<?,, r::binary>> ->
        case skip_ws(r) do
          <<?}, _::binary>> -> throw(:invalid_json)
          r2 -> dec_object(r2, acc)
        end

      <<?}, r::binary>> ->
        {acc, r}

      _ ->
        throw(:invalid_json)
    end
  end

  defp dec_object(_, _), do: throw(:invalid_json)

  defp dec_array(<<?], rest::binary>>, acc), do: {:lists.reverse(acc), rest}

  defp dec_array(bin, acc) do
    {value, rest} = dec_value(bin)
    acc = [value | acc]

    case skip_ws(rest) do
      <<?,, r::binary>> ->
        case skip_ws(r) do
          <<?], _::binary>> -> throw(:invalid_json)
          r2 -> dec_array(r2, acc)
        end

      <<?], r::binary>> ->
        {:lists.reverse(acc), r}

      _ ->
        throw(:invalid_json)
    end
  end

  defp dec_string(<<?", rest::binary>>, acc), do: {acc, rest}

  defp dec_string(<<?\\, esc, rest::binary>>, acc) do
    case esc do
      ?" -> dec_string(rest, <<acc::binary, ?">>)
      ?\\ -> dec_string(rest, <<acc::binary, ?\\>>)
      ?/ -> dec_string(rest, <<acc::binary, ?/>>)
      ?b -> dec_string(rest, <<acc::binary, 8>>)
      ?f -> dec_string(rest, <<acc::binary, 12>>)
      ?n -> dec_string(rest, <<acc::binary, ?\n>>)
      ?r -> dec_string(rest, <<acc::binary, ?\r>>)
      ?t -> dec_string(rest, <<acc::binary, ?\t>>)
      ?u -> dec_unicode(rest, acc)
      _ -> throw(:invalid_json)
    end
  end

  defp dec_string(<<c, rest::binary>>, acc), do: dec_string(rest, <<acc::binary, c>>)
  defp dec_string(<<>>, _acc), do: throw(:invalid_json)

  defp dec_unicode(<<h::binary-size(4), rest::binary>>, acc) do
    code = :erlang.binary_to_integer(h, 16)

    cond do
      code >= 0xD800 and code <= 0xDBFF ->
        case rest do
          <<?\\, ?u, l::binary-size(4), rest2::binary>> ->
            low = :erlang.binary_to_integer(l, 16)
            combined = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
            dec_string(rest2, <<acc::binary, combined::utf8>>)

          _ ->
            throw(:invalid_json)
        end

      true ->
        dec_string(rest, <<acc::binary, code::utf8>>)
    end
  end

  defp dec_unicode(_, _), do: throw(:invalid_json)

  defp dec_number(<<c, rest::binary>>, acc)
       when (c >= ?0 and c <= ?9) or c == ?- or c == ?+ or c == ?. or c == ?e or c == ?E,
       do: dec_number(rest, <<acc::binary, c>>)

  defp dec_number(rest, acc), do: {to_number(acc), rest}

  defp to_number(token) do
    if plain_integer?(token) do
      :erlang.binary_to_integer(token)
    else
      case :binary.split(token, [<<"e">>, <<"E">>]) do
        [_mantissa] ->
          :erlang.binary_to_float(token)

        [mantissa, exponent] ->
          mantissa =
            case :binary.match(mantissa, <<".">>) do
              :nomatch -> <<mantissa::binary, ".0">>
              _ -> mantissa
            end

          :erlang.binary_to_float(<<mantissa::binary, "e", exponent::binary>>)
      end
    end
  end

  defp plain_integer?(<<?-, rest::binary>>), do: plain_integer?(rest)
  defp plain_integer?(<<>>), do: true

  defp plain_integer?(<<c, rest::binary>>) when c >= ?0 and c <= ?9,
    do: plain_integer?(rest)

  defp plain_integer?(_), do: false
end
