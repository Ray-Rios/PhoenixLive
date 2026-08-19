import Config

# Minimal test configuration to allow unit tests that don't boot the DB
config :phoenix_app, PhoenixApp.Repo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "phoenixapp_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :phoenix_app, PhoenixApp.GamesRepo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("GAMES_DB_NAME") || "phoenix_games_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :phoenix_app, PhoenixAppWeb.Endpoint,
  server: false

config :logger, level: :warn

# Tests register accounts and then log in as them; without this the login gate
# on email_verified_at makes that a two-step dance in every fixture.
config :phoenix_app, :allow_dev_verify, true
