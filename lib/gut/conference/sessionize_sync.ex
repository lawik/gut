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
  Syncs speakers and workshops from already-fetched Sessionize data.

  `main_data` is the decoded JSON from the main Sessionize endpoint (speaker profiles).
  `email_data` is the decoded JSON from the email endpoint (list of `%{"id" => ..., "email" => ...}`).
  """
  def sync_from_data(main_data, email_data, actor) do
    speakers = extract_speakers(main_data)
    sessions = extract_sessions(main_data)
    workshop_category_ids = extract_workshop_category_ids(main_data)
    email_map = build_email_map(email_data)
    existing = load_existing_speakers(actor)

    speaker_results =
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
      Enum.split_with(speaker_results, fn
        {:ok, _} -> true
        _ -> false
      end)

    Logger.info("Sessionize speaker sync: #{length(ok)} synced, #{length(errors)} errors")

    # Sync workshops from top-level sessions, filtering to workshop category only
    workshop_sessions =
      Enum.filter(sessions, fn session ->
        category_items = MapSet.new(Map.get(session, "categoryItems", []))
        MapSet.size(MapSet.intersection(category_items, workshop_category_ids)) > 0
      end)

    workshop_result = sync_workshops(workshop_sessions, speakers, email_map, actor)

    {:ok,
     %{
       synced: length(ok),
       errors: length(errors),
       workshops_synced: workshop_result.synced,
       workshops_errors: workshop_result.errors
     }}
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
  Extracts session entries from the main Sessionize response.
  Sessions live at the top level of the response map, not inside speakers.
  """
  def extract_sessions(%{"sessions" => sessions}) when is_list(sessions), do: sessions
  def extract_sessions(_), do: []

  @workshop_category_names MapSet.new(["Workshop session", "workshop"])

  @doc """
  Extracts category item IDs that identify workshops from the Sessionize categories.
  Matches items whose name is in #{inspect(@workshop_category_names)}.
  """
  def extract_workshop_category_ids(%{"categories" => categories}) when is_list(categories) do
    categories
    |> Enum.flat_map(fn cat -> Map.get(cat, "items", []) end)
    |> Enum.filter(fn item -> MapSet.member?(@workshop_category_names, item["name"]) end)
    |> Enum.map(fn item -> item["id"] end)
    |> MapSet.new()
  end

  def extract_workshop_category_ids(_), do: MapSet.new()

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
    speakers = Gut.Conference.list_speakers!(actor: actor, load: [:user])

    Enum.reduce(speakers, %{}, fn speaker, acc ->
      acc =
        if speaker.user do
          # Force a binary copy of the email to avoid stale sub-binary references
          # from Postgrex response buffers (observed as flaky CiString corruption
          # in the Ecto SQL Sandbox).
          email =
            speaker.user.email
            |> to_string()
            |> String.downcase()
            |> :binary.copy()

          Map.put(acc, email, speaker)
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

  @default_workshop_limit 30

  defp sync_workshops(sessions, speakers, email_map, actor) do
    if sessions == [] do
      %{synced: 0, errors: 0}
    else
      # Build a map of speaker UUID -> email for resolving session speakers
      speaker_uuid_to_email =
        Enum.reduce(speakers, %{}, fn speaker_data, acc ->
          uuid = to_string(Map.get(speaker_data, "id"))
          sessionize_id = to_string(Map.get(speaker_data, "id"))
          email = Map.get(email_map, sessionize_id)
          if email, do: Map.put(acc, uuid, email), else: acc
        end)

      existing_workshops = load_existing_workshops(actor)
      existing_speakers = load_existing_speakers(actor)

      results =
        Enum.map(sessions, fn session_data ->
          session_id = to_string(Map.get(session_data, "id"))
          speaker_uuids = Map.get(session_data, "speakers", [])

          speaker_emails =
            Enum.map(speaker_uuids, fn uuid ->
              Map.get(speaker_uuid_to_email, uuid)
            end)

          upsert_workshop(
            session_id,
            session_data,
            speaker_emails,
            existing_workshops,
            existing_speakers,
            actor
          )
        end)

      {ok, errors} =
        Enum.split_with(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      Logger.info("Sessionize workshop sync: #{length(ok)} synced, #{length(errors)} errors")
      %{synced: length(ok), errors: length(errors)}
    end
  end

  defp load_existing_workshops(actor) do
    require Ash.Query

    Gut.Conference.Workshop
    |> Ash.Query.filter(not is_nil(sessionize_id))
    |> Ash.read!(actor: actor, load: [:speakers])
    |> Enum.reduce(%{}, fn workshop, acc ->
      Map.put(acc, workshop.sessionize_id, workshop)
    end)
  end

  defp upsert_workshop(
         session_id,
         session_data,
         speaker_emails,
         existing_workshops,
         existing_speakers,
         actor
       ) do
    name = Map.get(session_data, "title", "Untitled Workshop")

    attrs = %{
      name: name,
      sessionize_id: session_id
    }

    workshop_result =
      case Map.get(existing_workshops, session_id) do
        nil ->
          Gut.Conference.create_workshop(Map.put(attrs, :limit, @default_workshop_limit),
            actor: actor
          )

        workshop ->
          Gut.Conference.update_workshop(workshop, attrs, actor: actor)
      end

    case workshop_result do
      {:ok, workshop} ->
        sync_workshop_speakers(workshop, speaker_emails, existing_speakers, actor)
        {:ok, workshop}

      error ->
        error
    end
  end

  defp sync_workshop_speakers(workshop, speaker_emails, existing_speakers, actor) do
    existing_speaker_ids =
      case Ash.load(workshop, :speakers, actor: actor) do
        {:ok, w} -> Enum.map(w.speakers, & &1.id) |> MapSet.new()
        _ -> MapSet.new()
      end

    speaker_emails
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.each(fn email ->
      case Map.get(existing_speakers, String.downcase(email)) do
        nil ->
          nil

        speaker ->
          unless MapSet.member?(existing_speaker_ids, speaker.id) do
            Gut.Conference.create_workshop_speaker(
              %{workshop_id: workshop.id, speaker_id: speaker.id},
              actor: actor
            )
          end
      end
    end)
  end
end
