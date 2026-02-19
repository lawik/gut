defmodule Gut.Conference do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain, AshAi]

  admin do
    show? true
  end

  tools do
    tool :list_speakers, Gut.Conference.Speaker, :read
    tool :get_speaker, Gut.Conference.Speaker, :read
    tool :create_speaker, Gut.Conference.Speaker, :create
    tool :update_speaker, Gut.Conference.Speaker, :update
    tool :destroy_speaker, Gut.Conference.Speaker, :destroy
    tool :list_sponsors, Gut.Conference.Sponsor, :read
    tool :get_sponsor, Gut.Conference.Sponsor, :read
    tool :create_sponsor, Gut.Conference.Sponsor, :create
    tool :update_sponsor, Gut.Conference.Sponsor, :update
    tool :destroy_sponsor, Gut.Conference.Sponsor, :destroy
  end

  resources do
    resource Gut.Conference.Speaker do
      define :list_speakers, action: :read
      define :get_speaker, action: :read, get_by: [:id]
      define :create_speaker, action: :create
      define :update_speaker, action: :update
      define :destroy_speaker, action: :destroy
    end

    resource Gut.Conference.Sponsor do
      define :list_sponsors, action: :read
      define :get_sponsor, action: :read, get_by: [:id]
      define :create_sponsor, action: :create
      define :update_sponsor, action: :update
      define :destroy_sponsor, action: :destroy
    end
  end

  @doc """
  Imports speakers from a Sessionize JSON file.

  ## Examples

      iex> Gut.Conference.import_sessionize_speakers("sessionize.json")
      {:ok, [%Gut.Conference.Speaker{}, ...]}

      iex> Gut.Conference.import_sessionize_speakers("nonexistent.json")
      {:error, :enoent}
  """
  def import_sessionize_speakers(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content),
         speakers when is_list(speakers) <- Map.get(data, "speakers", []) do
      results =
        Enum.map(speakers, fn speaker_data ->
          create_speaker(%{
            first_name: Map.get(speaker_data, "firstName"),
            last_name: Map.get(speaker_data, "lastName"),
            full_name: Map.get(speaker_data, "fullName")
          })
        end)

      # Separate successful and failed creations
      {successes, errors} =
        Enum.split_with(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      if errors == [] do
        {:ok, Enum.map(successes, fn {:ok, speaker} -> speaker end)}
      else
        {:error,
         {:partial_success,
          %{
            created: Enum.map(successes, fn {:ok, speaker} -> speaker end),
            errors: errors
          }}}
      end
    else
      {:error, %Jason.DecodeError{}} = error ->
        {:error, {:invalid_json, error}}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:unexpected_format, other}}
    end
  end
end
