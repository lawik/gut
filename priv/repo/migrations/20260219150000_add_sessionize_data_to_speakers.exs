defmodule Gut.Repo.Migrations.AddSessionizeDataToSpeakers do
  @moduledoc """
  Adds sessionize_data jsonb column to speakers for storing
  extra fields from the Sessionize API.
  """
  use Ecto.Migration

  def change do
    alter table(:speakers) do
      add :sessionize_data, :map
    end
  end
end
