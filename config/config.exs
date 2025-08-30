import Config

# ----------------------------
# Global Phoenix App Config
# ----------------------------
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# ----------------------------
# Ecto Repos
# ----------------------------
config :phoenix_app,
  ecto_repos: [PhoenixApp.Repo], # updated to use PhoenixApp.Repo
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
# Mailer
# ----------------------------
config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.Local

# ----------------------------
# Esbuild (JS bundler)
# ----------------------------
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# ----------------------------
# Logger
# ----------------------------
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

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
# Cockroach/Ecto Repo defaults
# ----------------------------
config :phoenix_app, PhoenixApp.Repo,
  username: System.get_env("DB_USERNAME") || "root",
  password: System.get_env("DB_PASSWORD") || "cockroachDB",
  database: System.get_env("DB_NAME") || "phoenixapp_dev",
  hostname: System.get_env("DB_HOST") || "db",
  port: String.to_integer(System.get_env("DB_PORT") || "26257"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  migration_primary_key: [type: :bigserial],
  migration_lock: false

# ----------------------------
# Import environment-specific configs
# ----------------------------
import_config "#{config_env()}.exs"
