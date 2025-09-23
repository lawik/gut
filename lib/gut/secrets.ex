defmodule Gut.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Gut.Accounts.User, _opts, _context) do
    Application.fetch_env(:gut, :token_signing_secret)
  end
end
