defmodule Gut.Repo.Migrations.CreateInvites do
  @moduledoc """
  Creates the invites table.
  This resource was added but the migration was missed.
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:invites, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :email, :citext, null: false
      add :resource_type, :text, null: false
      add :resource_id, :uuid, null: false
      add :accepted, :boolean, null: false, default: false

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
  end

  def down do
    drop_if_exists table(:invites)
  end
end
