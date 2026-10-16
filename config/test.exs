import Config

# Minimal test configuration to allow unit tests that don't boot the DB
config :phxlive, Phxlive.Repo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "phoenixapp_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :phxlive, Phxlive.GamesRepo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("GAMES_DB_NAME") || "phoenix_games_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :phxlive, PhxliveWeb.Endpoint,
  server: false

config :logger, level: :warning

# Drive: no background janitor in tests; bodies go to a throwaway directory.
config :phxlive, Phxlive.Drive.Janitor, enabled: false

# Plugins: tests drive activation themselves; no background runtime, a fixture
# plugin, and nothing active by default.
config :phxlive, Phxlive.Plugins.Runtime, enabled: false
config :phxlive, :extra_plugins, [Phxlive.Test.FixturePlugin]
config :phxlive, :default_active_plugins, []
config :phxlive, Phxlive.Storage, root: Path.join(System.tmp_dir!(), "phxlive_test_drive")

# Tests register accounts and then log in as them; without this the login gate
# on email_verified_at makes that a two-step dance in every fixture.
config :phxlive, :allow_dev_verify, true
