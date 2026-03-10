defmodule Gut do
  @moduledoc """
  Gut keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Returns a system actor for use in background jobs and automated actions.

  The label identifies what part of the system is acting, useful for logging
  and debugging.

      Gut.system_actor("sessionize_sync")
      #=> %{type: :system, label: "sessionize_sync"}
  """
  def system_actor(label) do
    %{type: :system, label: label}
  end

  @doc """
  Returns a public actor for use in unauthenticated public-facing pages.

      Gut.public_actor()
      #=> %{type: :public}
  """
  def public_actor do
    %{type: :public}
  end
end
