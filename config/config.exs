import Config

# ----------------------------
# MIME Types
# ----------------------------
# Add custom MIME types for file uploads
config :mime, :types, %{
  "audio/mpeg" => ["mp3"],
  "audio/wav" => ["wav"],
  "audio/ogg" => ["ogg"],
  "video/ogg" => ["ogv"],
  "audio/flac" => ["flac"],
  "audio/x-m4a" => ["m4a"],
  "video/webm" => ["webm"],
  "video/quicktime" => ["mov"],
  "video/x-msvideo" => ["avi"]
}

# ----------------------------
# Global Phoenix App Config
# ----------------------------
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# ----------------------------
# Ecto Repos
# ----------------------------
config :phoenix_app,
  ecto_repos: [PhoenixApp.Repo, PhoenixApp.GamesRepo], # PhoenixApp.Repo = main app, GamesRepo = isolated multiplayer game data
  generators: [timestamp_type: :utc_datetime]

# ----------------------------
# Phoenix Endpoint
# ----------------------------
config :phoenix_app, PhoenixAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PhoenixAppWeb.ErrorHTML, json: PhoenixAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PhoenixApp.PubSub

# ----------------------------
# Mailer (default - overridden by runtime.exs in prod)
# Using Logger adapter as default since Local adapter causes global process conflicts in clusters
# ----------------------------
config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.Logger,
  level: :info

# ----------------------------
# Esbuild (JS bundler)
# ----------------------------
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --format=iife --minify --tree-shaking=true),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__), "NODE_ENV" => "production"}
  ]

# ----------------------------
# Logger
# ----------------------------
config :logger,
  backends: [:console, PhoenixApp.LogBufferBackend]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, PhoenixApp.LogBufferBackend,
  level: :info

# ----------------------------
# JSON library
# ----------------------------
config :phoenix, :json_library, Jason

# ----------------------------
# CORS defaults (can override per environment)
# ----------------------------
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:4000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# ----------------------------
# Ecto Repo defaults
# ----------------------------
config :phoenix_app, PhoenixApp.Repo,
  username: System.get_env("DB_USERNAME") || "root",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "phoenixapp_dev",
  hostname: System.get_env("DB_HOST") || "db",
  port: String.to_integer(System.get_env("DB_PORT") || "26257"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  migration_primary_key: [type: :bigserial],
  migration_lock: false

# ----------------------------
# Games Repo defaults (isolated database for multiplayer game data - RaysSpaceSim, future games)
# ----------------------------
config :phoenix_app, PhoenixApp.GamesRepo,
  username: System.get_env("DB_USERNAME") || "root",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("GAMES_DB_NAME") || "phoenix_games_dev",
  hostname: System.get_env("DB_HOST") || "db",
  port: String.to_integer(System.get_env("DB_PORT") || "26257"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  priv: "priv/games_repo",
  migration_primary_key: [type: :binary_id],
  migration_lock: false



# ----------------------------
# Import environment-specific configs
# ----------------------------
import_config "#{config_env()}.exs"
