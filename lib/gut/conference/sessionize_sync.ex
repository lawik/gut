defmodule Gut.Conference.SessionizeSync do
  @moduledoc """
  Syncs speaker data from the Sessionize API.

  Fetches speaker info from two endpoints:
  - Main URL: speaker profiles (names, bios, links, sessions, etc.)
  - Email URL: speaker emails keyed by sessionize ID

  Speakers are matched by email. If a speaker with the same email already exists
  (either via linked user account or from a previous sync), they are updated.
  Otherwise a new speaker is created.

  Fields that don't map to existing Speaker attributes are stored in `sessionize_data`.
  """

  require Logger

  @known_fields ~w(firstName lastName fullName id)

  @doc """
  Fetches data from the configured Sessionize URLs and syncs speakers.
  """
  def sync(actor) do
    main_url = Application.get_env(:gut, :sessionize_main_url)
    email_url = Application.get_env(:gut, :sessionize_speaker_email_url)

    cond do
      is_nil(main_url) or main_url == "" ->
        Logger.warning("SESSIONIZE_MAIN_URL not configured, skipping sync")
        {:error, :not_configured}

      is_nil(email_url) or email_url == "" ->
        Logger.warning("SESSIONIZE_SPEAKER_EMAIL_URL not configured, skipping sync")
        {:error, :not_configured}

      true ->
        with {:ok, main_data} <- fetch_json(main_url),
             {:ok, email_data} <- fetch_json(email_url) do
          sync_from_data(main_data, email_data, actor)
        end
    end
  end

  @doc """
  Syncs speakers from already-fetched Sessionize data.

  `main_data` is the decoded JSON from the main Sessionize endpoint (speaker profiles).
  `email_data` is the decoded JSON from the email endpoint (list of `%{"id" => ..., "email" => ...}`).
  """
  def sync_from_data(main_data, email_data, actor) do
    speakers = extract_speakers(main_data)
    email_map = build_email_map(email_data)
    existing = load_existing_speakers(actor)

    results =
      speakers
      |> Enum.map(fn speaker_data ->
        sessionize_id = to_string(Map.get(speaker_data, "id"))
        email = Map.get(email_map, sessionize_id)

        if email do
          upsert_speaker(speaker_data, email, existing, actor)
        else
          Logger.warning("No email found for sessionize speaker #{sessionize_id}, skipping")
          {:skip, sessionize_id}
        end
      end)
      |> Enum.reject(&match?({:skip, _}, &1))

    {ok, errors} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    Logger.info("Sessionize sync complete: #{length(ok)} synced, #{length(errors)} errors")

    {:ok, %{synced: length(ok), errors: length(errors)}}
  end

  @doc """
  Extracts speaker entries from the main Sessionize response.
  Handles both a bare list and a `%{"speakers" => [...]}` wrapper.
  """
  def extract_speakers(data) when is_list(data), do: data
  def extract_speakers(%{"speakers" => speakers}) when is_list(speakers), do: speakers

  def extract_speakers(data) when is_map(data) do
    if Map.has_key?(data, "speakers"), do: List.wrap(data["speakers"]), else: []
  end

  def extract_speakers(_), do: []

  @doc """
  Builds a map of `%{sessionize_id => email}` from the email endpoint data.
  """
  def build_email_map(data) when is_list(data) do
    Enum.reduce(data, %{}, fn item, acc ->
      id = to_string(Map.get(item, "id"))
      email = Map.get(item, "email")

      if id && email do
        Map.put(acc, id, String.downcase(email))
      else
        acc
      end
    end)
  end

  def build_email_map(_), do: %{}

  defp fetch_json(url) do
    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        Logger.error("Sessionize API returned status #{status} for #{url}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to fetch #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_existing_speakers(actor) do
    speakers =
      Gut.Conference.list_speakers!(actor: actor, load: [:user])

    Enum.reduce(speakers, %{}, fn speaker, acc ->
      acc =
        if speaker.user do
          Map.put(acc, speaker.user.email |> to_string() |> String.downcase(), speaker)
        else
          acc
        end

      case get_in(speaker.sessionize_data || %{}, ["email"]) do
        nil -> acc
        email -> Map.put(acc, String.downcase(email), speaker)
      end
    end)
  end

  defp upsert_speaker(speaker_data, email, existing, actor) do
    first_name = Map.get(speaker_data, "firstName", "")
    last_name = Map.get(speaker_data, "lastName", "")
    full_name = Map.get(speaker_data, "fullName", "#{first_name} #{last_name}")

    extra_data =
      speaker_data
      |> Map.drop(@known_fields)
      |> Map.put("email", email)

    attrs = %{
      first_name: first_name,
      last_name: last_name,
      full_name: full_name,
      sessionize_data: extra_data,
      email: email
    }

    case Map.get(existing, String.downcase(email)) do
      nil ->
        Gut.Conference.create_speaker(attrs, actor: actor)

      speaker ->
        Gut.Conference.update_speaker(speaker, attrs, actor: actor)
    end
  end
end
