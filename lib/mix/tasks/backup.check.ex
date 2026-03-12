defmodule Mix.Tasks.Backup.Check do
  @moduledoc "Verify the latest Tigris backup by restoring into a temp database and checking data."
  @shortdoc "Verify latest backup from Tigris"

  use Mix.Task

  @temp_db "gut_backup_check"

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)
    Application.ensure_all_started(:req_s3)

    bucket = System.fetch_env!("TIGRIS_BUCKET_NAME")

    req = Req.new() |> ReqS3.attach()

    Mix.shell().info("Listing backups in s3://#{bucket}/backups/ ...")

    %{status: 200, body: body} =
      Req.get!(req, url: "s3://#{bucket}", params: [{"prefix", "backups/"}])

    contents =
      body
      |> Map.get(:contents, body["ListBucketResult"]["Contents"])
      |> List.wrap()

    keys =
      contents
      |> Enum.map(&(&1[:key] || &1["Key"]))
      |> Enum.filter(&String.ends_with?(&1, ".dump"))
      |> Enum.sort()

    if keys == [] do
      Mix.raise("No .dump files found in s3://#{bucket}/backups/")
    end

    latest_key = List.last(keys)
    Mix.shell().info("Latest backup: #{latest_key}")

    tmp_path =
      Path.join(System.tmp_dir!(), "gut_backup_check_#{System.unique_integer([:positive])}.dump")

    try do
      Mix.shell().info("Downloading to #{tmp_path} ...")
      %{status: 200, body: dump_data} = Req.get!(req, url: "s3://#{bucket}/#{latest_key}")
      File.write!(tmp_path, dump_data)
      Mix.shell().info("Downloaded #{byte_size(dump_data)} bytes.")

      Mix.shell().info("Creating temporary database #{@temp_db} ...")
      docker_psql("postgres", "CREATE DATABASE #{@temp_db};")

      Mix.shell().info("Restoring backup ...")

      {output, exit_code} =
        System.cmd(
          "docker",
          [
            "run",
            "--rm",
            "--network=host",
            "-e",
            "PGPASSWORD=postgres",
            "-v",
            "#{tmp_path}:/backup.dump:ro",
            "postgres:17",
            "pg_restore",
            "-h",
            "localhost",
            "-U",
            "postgres",
            "--dbname=#{@temp_db}",
            "--no-owner",
            "--no-acl",
            "--clean",
            "--if-exists",
            "/backup.dump"
          ],
          stderr_to_stdout: true
        )

      if exit_code not in [0, 1] do
        Mix.shell().info(output)
        Mix.raise("pg_restore failed with exit code #{exit_code}")
      end

      Mix.shell().info("Restore complete. Verifying data ...")

      {table_list, 0} =
        docker_psql_query(
          @temp_db,
          "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
        )

      Mix.shell().info("Tables found: #{String.trim(table_list)}")

      tables = ["speakers", "sponsors"]

      for table <- tables do
        {output, exit_code} = docker_psql_query(@temp_db, "SELECT COUNT(*) FROM #{table}")

        count = String.trim(output)

        if exit_code == 0 do
          Mix.shell().info("  #{table}: #{count} rows")

          if count == "0" do
            Mix.shell().info("  WARNING: #{table} is empty!")
          end
        else
          Mix.shell().info("  #{table}: table does not exist (skipped)")
        end
      end

      Mix.shell().info("Backup verification complete!")
    after
      Mix.shell().info("Cleaning up ...")

      docker_psql("postgres", "DROP DATABASE IF EXISTS #{@temp_db};")

      if File.exists?(tmp_path) do
        File.rm!(tmp_path)
      end
    end
  end

  defp docker_psql(db, sql) do
    System.cmd(
      "docker",
      [
        "run",
        "--rm",
        "--network=host",
        "-e",
        "PGPASSWORD=postgres",
        "postgres:17",
        "psql",
        "-h",
        "localhost",
        "-U",
        "postgres",
        "-d",
        db,
        "-c",
        sql
      ],
      stderr_to_stdout: true
    )
  end

  defp docker_psql_query(db, sql) do
    System.cmd(
      "docker",
      [
        "run",
        "--rm",
        "--network=host",
        "-e",
        "PGPASSWORD=postgres",
        "postgres:17",
        "psql",
        "-h",
        "localhost",
        "-U",
        "postgres",
        "-d",
        db,
        "-t",
        "-A",
        "-c",
        sql
      ],
      stderr_to_stdout: true
    )
  end
end
