defmodule Gut.ObanSuspendedStateTest do
  @moduledoc """
  Regression for the Sentry error:

      Postgrex.Error 22P02 invalid input value for enum oban_job_state: "suspended"

  raised from Oban.Met.Reporter.checks/1.

  Oban 2.21+ added the :suspended job state, whose enum value is added by Oban
  migration v14. The reporter aggregates over every state (including
  "suspended"), so on a database whose oban_job_state enum predates v14 the
  query crashes. Production hit this because its Oban migration ran at v13;
  fresh databases migrate straight to the current version, so the second test
  rebuilds the pre-v14 enum in a throwaway schema to reproduce it faithfully.

  Uses unboxed_run because CREATE TYPE / ALTER TYPE ADD VALUE are DDL that
  can't run inside the sandbox's rolled-back transaction.
  """
  use ExUnit.Case

  import Ecto.Query

  @prefix "oban_suspended_repro"
  # Every job state Oban.Met.Reporter aggregates over (see its @empty_states).
  @states ~w(suspended available scheduled executing retryable completed cancelled discarded)

  setup do
    drop = fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Gut.Repo, fn ->
        Gut.Repo.query!(~s|DROP SCHEMA IF EXISTS "#{@prefix}" CASCADE|)
      end)
    end

    drop.()
    on_exit(drop)
    :ok
  end

  test "the app's oban_job_state enum includes 'suspended' after migrations" do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Gut.Repo, fn ->
      query = from(j in "oban_jobs", where: j.state in ^@states, select: count(j.id))
      assert Gut.Repo.all(query) == [0]
    end)
  end

  test "reporter-style query crashes on a pre-v14 enum and the v14 fix resolves it" do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Gut.Repo, fn ->
      # Rebuild oban_job_state as it was before Oban v14: no :suspended value.
      Gut.Repo.query!(~s|CREATE SCHEMA "#{@prefix}"|)

      Gut.Repo.query!("""
      CREATE TYPE "#{@prefix}".oban_job_state AS ENUM
        ('available', 'scheduled', 'executing', 'retryable', 'completed', 'discarded', 'cancelled')
      """)

      Gut.Repo.query!("""
      CREATE TABLE "#{@prefix}".oban_jobs (
        id bigserial PRIMARY KEY,
        state "#{@prefix}".oban_job_state NOT NULL DEFAULT 'available'
      )
      """)

      query =
        from(j in "oban_jobs", where: j.state in ^@states, select: count(j.id))
        |> Ecto.Query.put_query_prefix(@prefix)

      # Reproduces the exact Sentry error.
      error = assert_raise Postgrex.Error, fn -> Gut.Repo.all(query) end
      assert error.postgres.code == :invalid_text_representation
      assert error.postgres.message =~ "oban_job_state"

      # Apply Oban's v14 fix: the same statement our new migration runs.
      Gut.Repo.query!("""
      ALTER TYPE "#{@prefix}".oban_job_state ADD VALUE IF NOT EXISTS 'suspended' BEFORE 'scheduled'
      """)

      # The reporter query now succeeds.
      assert Gut.Repo.all(query) == [0]
    end)
  end
end
