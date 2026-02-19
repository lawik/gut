defmodule Gut.Repo.Migrations.AddUserToSponsors do
  @moduledoc """
  Adds the user_id column to sponsors table.
  This relationship was added to the resource but the migration was missed.
  """
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sponsors' AND column_name = 'user_id'
      ) THEN
        ALTER TABLE sponsors ADD COLUMN user_id uuid REFERENCES users(id);
      END IF;
    END $$;
    """
  end

  def down do
    alter table(:sponsors) do
      remove :user_id
    end
  end
end
