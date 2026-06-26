defmodule Gut.Repo.Migrations.UpgradeObanToV14 do
  use Ecto.Migration

  # The original add_oban migration ran Oban.Migration.up() when Oban was at v13,
  # so existing databases (production) have an oban_job_state enum without the
  # :suspended state added in v14. Oban 2.21+ / oban_met query that state, so the
  # reporter crashes with: invalid input value for enum oban_job_state:
  # "suspended". Step those databases up to v14. A no-op on fresh databases,
  # which already migrate straight to the current version.
  def up, do: Oban.Migration.up(version: 14)

  def down, do: Oban.Migration.down(version: 13)
end
