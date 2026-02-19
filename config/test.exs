import Config
config :gut, Oban, testing: :manual
config :gut, token_signing_secret: "L4RqKk67T+NAFtcnFQ0dVAQ1EvH8GaYq"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :gut, Gut.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "gut_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gut, GutWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0G1JvpPhSrp3d3oOTh2Rp1xlDYHr66Pepzzpp2Q134bEFFa/RIybN0FMiPGxpbI/",
  server: false

# In test we don't send emails
config :gut, Gut.Mailer, adapter: Swoosh.Adapters.Test, from_email: "noreply@example.com"

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, GutWeb.Endpoint
