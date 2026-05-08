defmodule Gut.GitSha do
  @moduledoc """
  Returns the git revision the running code was built from.

  In production, the build pipeline sets `GIT_SHA` at compile time.
  In dev, we fall back to `git rev-parse HEAD` so testing actually records
  a meaningful revision.
  """

  @sha (case System.get_env("GIT_SHA") do
          sha when is_binary(sha) and sha != "" ->
            sha

          _ ->
            case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
              {sha, 0} -> String.trim(sha)
              _ -> ""
            end
        end)

  def current, do: @sha
end
