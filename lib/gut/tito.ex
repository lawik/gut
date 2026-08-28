defmodule Gut.Tito do
  @moduledoc """
  Read-only client for the Tito Admin API (v3).

  Only ever performs GET requests against the Goatmire Tito account —
  it must never write to the event data.

  Requires the `TITO_API_KEY` environment variable (config `:tito_api_key`).
  """

  require Logger

  @base_url "https://api.tito.io/v3"
  @account_slug "goatmire"
  @event_slug "elixir-2026"
  @max_pages 50

  @doc """
  Checks whether `email` holds at least one valid ticket.

  A ticket is considered valid when it is assigned to the given email
  (case-insensitive), its state is `"complete"`, it is not void, and it
  is not a test-mode ticket.
  """
  @spec valid_ticket?(String.t()) :: {:ok, boolean()} | {:error, term()}
  def valid_ticket?(email) when is_binary(email) do
    with {:ok, tickets} <- tickets_for_email(email) do
      {:ok, Enum.any?(tickets, &valid_ticket_map?/1)}
    end
  end

  @doc """
  Lists tickets assigned to `email` (case-insensitive exact match).

  Uses Tito's server-side search (`search[q]`; note that plain `?q=` is
  silently ignored on this endpoint), then filters to exact email matches,
  since the search also matches names, references etc.
  """
  @spec tickets_for_email(String.t()) :: {:ok, [map()]} | {:error, term()}
  def tickets_for_email(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()

    if email == "" do
      {:ok, []}
    else
      case get("/tickets", [{"search[q]", email}, {"page[size]", "100"}]) do
        {:ok, %{"tickets" => tickets}} when is_list(tickets) ->
          {:ok, Enum.filter(tickets, &(String.downcase(&1["email"] || "") == email))}

        {:ok, other} ->
          {:error, {:unexpected_response, other}}

        {:error, _} = error ->
          error
      end
    end
  end

  @doc "All tickets for the event, following pagination."
  @spec list_tickets() :: {:ok, [map()]} | {:error, term()}
  def list_tickets, do: get_all_pages("/tickets", "tickets")

  @doc "All ticket releases (ticket types) for the event."
  @spec list_releases() :: {:ok, [map()]} | {:error, term()}
  def list_releases, do: get_all_pages("/releases", "releases")

  @doc "Whether a ticket map counts as a valid, assigned ticket."
  @spec valid_ticket_map?(map()) :: boolean()
  def valid_ticket_map?(ticket) do
    ticket["state"] == "complete" and ticket["void"] != true and ticket["test_mode"] != true
  end

  defp get_all_pages(path, key, page \\ 1, acc \\ []) do
    case get(path, [{"page[size]", "1000"}, {"page[number]", to_string(page)}]) do
      {:ok, %{^key => items} = body} when is_list(items) ->
        acc = acc ++ items

        case body["meta"]["next_page"] do
          nil -> {:ok, acc}
          next when is_integer(next) and next <= @max_pages -> get_all_pages(path, key, next, acc)
          _ -> {:error, :too_many_pages}
        end

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, _} = error ->
        error
    end
  end

  defp get(path, params) do
    case Application.get_env(:gut, :tito_api_key) do
      nil ->
        Logger.warning("Tito API key not configured, cannot call Tito API")
        {:error, :not_configured}

      api_key ->
        opts =
          [
            method: :get,
            url: @base_url <> "/#{@account_slug}/#{@event_slug}" <> path,
            params: params,
            headers: [
              {"authorization", "Token token=#{api_key}"},
              {"accept", "application/json"}
            ]
          ] ++ Application.get_env(:gut, :tito_req_options, [])

        case Req.request(opts) do
          {:ok, %Req.Response{status: 200, body: body}} ->
            {:ok, body}

          {:ok, %Req.Response{status: status}} ->
            Logger.error("Tito API returned status #{status} for #{path}")
            {:error, {:http_status, status}}

          {:error, reason} ->
            Logger.error("Tito API request failed: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end
end
