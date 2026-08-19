import Config

# -------------------------------------------------
# Swoosh API Client - MUST be disabled in production to prevent
# global process conflicts in clustered/multi-pod deployments
# -------------------------------------------------
config :swoosh, :api_client, false

# Optional Projects API key used by Taskbar calendar to fetch project items
config :phoenix_app, projects_api_key: System.get_env("PROJECTS_API_KEY") || ""

# API key used by trusted dedicated game servers (e.g. RaysSpaceSim) to act on behalf of players
config :phoenix_app, games_server_api_key: System.get_env("GAMES_SERVER_API_KEY") || ""

# -------------------------------------------------
# SECRET_KEY_BASE
# -------------------------------------------------
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    if config_env() == :dev do
      # Dev default - fixed key for development
      "sX9/Rn5BIxDT+OD20jOYEYImGrN9SR7F9NLC1av9z+aip2mySJdALjSICoNOX5Hc"
    else
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by running `mix phx.gen.secret`
      """
    end

# -------------------------------------------------
# LIVE_VIEW_SIGNING_SALT
# -------------------------------------------------
live_view_salt =
  System.get_env("LIVE_VIEW_SIGNING_SALT") ||
    if config_env() == :dev do
      "dev_live_view_salt_#{:crypto.strong_rand_bytes(8) |> Base.encode64()}"
    else
      raise """
      environment variable LIVE_VIEW_SIGNING_SALT is missing.
      You can generate one by running `mix phx.gen.secret`
      """
    end

# -------------------------------------------------
# GUARDIAN SECRET KEY
# -------------------------------------------------
guardian_secret =
  System.get_env("GUARDIAN_SECRET_KEY") ||
    if config_env() == :dev do
      "dev_guardian_secret_#{:crypto.strong_rand_bytes(16) |> Base.encode64()}"
    else
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by running `mix guardian.gen.secret`
      """
    end

# -------------------------------------------------
# PostgreSQL Database URL
# -------------------------------------------------
db_username = System.get_env("DB_USERNAME") || "postgres"
db_password = System.get_env("DB_PASSWORD") || "postgres"
db_host = System.get_env("DB_HOST") || if(config_env() == :dev, do: "localhost", else: "db")
db_port = String.to_integer(System.get_env("DB_PORT") || if(config_env() == :dev, do: "5432", else: "5432"))
db_name = System.get_env("DB_NAME") || "phoenixapp_dev"
db_pool = String.to_integer(System.get_env("POOL_SIZE") || "10")

database_url = 
  System.get_env("DATABASE_URL") || 
  "postgresql://#{db_username}:#{db_password}@#{db_host}:#{db_port}/#{db_name}"

config :phoenix_app, PhoenixApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: database_url,
  pool_size: db_pool,
  timeout: 60_000,
  ownership_timeout: 60_000,
  queue_target: 5000,
  queue_interval: 1000,
  migration_primary_key: [type: :bigserial],
  migration_lock: nil,
  parameters: [
    application_name: "phoenix_app"
  ]

# -------------------------------------------------
# Games Repo Database URL (isolated multiplayer game data)
# -------------------------------------------------
games_db_name = System.get_env("GAMES_DB_NAME") || "phoenix_games_dev"

games_database_url =
  System.get_env("GAMES_DATABASE_URL") ||
    "postgresql://#{db_username}:#{db_password}@#{db_host}:#{db_port}/#{games_db_name}"

# -------------------------------------------------
# Holo-sim instance orchestration (M5)
#
# Everything here is optional. With HOLOSIM_IMAGE unset the launcher reports
# itself unavailable and /launch falls back to the M4 behaviour - record the
# intent, answer `pending`, and let a hand-started server heartbeat in. That is
# the development loop and it must keep working, so "not configured" is a
# supported state rather than a broken one.
#
# Values are computed into variables FIRST, matching how games_database_url is
# handled above. That is not only style: a multi-line `case ... end` used
# directly as a keyword value does not parse - Elixir cannot tell that the
# keyword list resumes after `end,` - and the resulting SyntaxError is raised by
# the release's config provider at boot, long after any compile step could have
# caught it. The pod crash-loops with no application log at all.
# -------------------------------------------------

# Entrypoint override, for proving the orchestration before a server image
# exists. Comma-separated, e.g. HOLOSIM_COMMAND="sleep,3600" alongside
# HOLOSIM_IMAGE=busybox. Unset in production - the real image runs the server
# and takes the launcher's arguments as they are.
#
# STDLIB ONLY, DELIBERATELY. This was Jason.decode! on a JSON array, which reads
# better and was the one thing in this entire file reaching for a dependency.
# runtime.exs is evaluated before the applications start, on a restricted code
# path where dependency modules are not reliably loadable.
holosim_command =
  case System.get_env("HOLOSIM_COMMAND") do
    nil ->
      nil

    "" ->
      nil

    csv ->
      csv
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
  end

holosim_port_min = String.to_integer(System.get_env("HOLOSIM_PORT_MIN", "7800"))
holosim_port_max = String.to_integer(System.get_env("HOLOSIM_PORT_MAX", "7899"))

config :phoenix_app, PhoenixApp.Games.InstanceLauncher,
  # The packaged Linux dedicated server image. Until this exists, leave it unset.
  image: System.get_env("HOLOSIM_IMAGE"),
  image_pull_policy: System.get_env("HOLOSIM_IMAGE_PULL_POLICY", "IfNotPresent"),
  command: holosim_command,

  # The address a GAME CLIENT can reach, which is not necessarily the address
  # the cluster knows itself by. Getting this wrong produces an instance that
  # appears in the browser and times out on connect.
  public_host: System.get_env("HOLOSIM_PUBLIC_HOST", "127.0.0.1"),
  port_range: {holosim_port_min, holosim_port_max},

  # Removed this long after the Job finishes, which is also when its port frees.
  ttl_seconds: String.to_integer(System.get_env("HOLOSIM_TTL_SECONDS", "600")),

  # A backstop for a wedged instance. Normal retirement is the empty-instance
  # countdown inside the server itself.
  max_lifetime_seconds:
    String.to_integer(System.get_env("HOLOSIM_MAX_LIFETIME_SECONDS", "14400")),
  secret_name: System.get_env("HOLOSIM_SECRET_NAME", "phoenix-secrets"),
  hub_url:
    System.get_env(
      "HOLOSIM_HUB_URL",
      "http://phoenix-web.phoenixapp.svc.cluster.local:4000"
    )

config :phoenix_app, PhoenixApp.GamesRepo,
  adapter: Ecto.Adapters.Postgres,
  url: games_database_url,
  pool_size: db_pool,
  timeout: 60_000,
  ownership_timeout: 60_000,
  queue_target: 5000,
  queue_interval: 1000,
  priv: "priv/games_repo",
  migration_primary_key: [type: :binary_id],
  migration_lock: nil,
  parameters: [
    application_name: "phoenix_app_games"
  ]

# -------------------------------------------------
# Endpoint config
# -------------------------------------------------
http_port = String.to_integer(System.get_env("PORT") || "4000")


config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: http_port],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: live_view_salt],
  url: [
    host: System.get_env("PHOENIX_HOST") || "localhost", 
    port: if(config_env() == :prod, do: 443, else: http_port),
    scheme: if(config_env() == :prod, do: "https", else: "http")
  ],
  force_ssl: [rewrite_on: [:x_forwarded_proto]]

# -------------------------------------------------
# Guardian runtime config
# -------------------------------------------------
config :phoenix_app, PhoenixApp.Auth.Guardian,
  secret_key: guardian_secret

# -------------------------------------------------
# Redis
# -------------------------------------------------
config :phoenix_app, :redis_url,
  System.get_env("REDIS_URL") || if(config_env() == :dev, do: "redis://localhost:6379/0", else: "redis://redis:6379/0")

config :phoenix_app, :enable_redis,
  System.get_env("ENABLE_REDIS", "false") == "true"

# -------------------------------------------------
# Swoosh / Mailer (dynamic runtime config)
# If SMTP_HOST is provided, use authenticated SMTP (recommended for prod).
# Otherwise, fall back to Local adapter (preview emails without sending).
#
# For Namecheap Private Email, use these settings:
#   SMTP_HOST=mail.privateemail.com
#   SMTP_PORT=587 (for STARTTLS) or 465 (for SSL/TLS)
#   SMTP_USER=your-email@yourdomain.com (full email address)
#   SMTP_PASS=your-password
#   FROM_EMAIL=your-email@yourdomain.com (same as SMTP_USER)
#   FROM_NAME=PhxLive (or your preferred sender name)
#
# Note: Namecheap requires authentication and the FROM_EMAIL must match
# an email address configured in your Namecheap Private Email account.
# -------------------------------------------------
smtp_host = System.get_env("SMTP_HOST") || ""
smtp_port = System.get_env("SMTP_PORT")
smtp_user = System.get_env("SMTP_USER")
smtp_pass = System.get_env("SMTP_PASS")
smtp_verify = System.get_env("SMTP_VERIFY", "true") == "true"

if smtp_host != "" do
  # Use SMTP relay; defaults target STARTTLS on 587. Set SMTP_PORT if different.
  parsed_port = (smtp_port && String.to_integer(smtp_port)) || 587
  {ssl?, tls_mode} =
    case parsed_port do
      465 -> {true, :never}   # Implicit SSL
      _ -> {false, :always}   # Require STARTTLS on submission port
    end

  tls_options_base =
    if smtp_verify do
      [
        verify: :verify_peer,
        cacertfile: "/etc/ssl/certs/ca-certificates.crt",
        server_name_indication: to_charlist(smtp_host),
        depth: 10
      ]
    else
      [verify: :verify_none]
    end

  config :phoenix_app, PhoenixApp.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: parsed_port,
    username: smtp_user,
    password: smtp_pass,
    auth: :always,
    tls: tls_mode,
    ssl: ssl?,
  retries: 2,
  no_mx_lookups: false,
  tls_options: tls_options_base
else
  # No SMTP configured: use Logger adapter (cluster-safe, just logs emails)
  # Note: Swoosh.Adapters.Local uses global processes which cause conflicts in clustered deployments
  config :phoenix_app, PhoenixApp.Mailer,
    adapter: Swoosh.Adapters.Logger,
    level: :info
end

# -------------------------------------------------
# CORS
# -------------------------------------------------
config :cors_plug,
  origin:
    String.split(
      System.get_env("CORS_ALLOWED_ORIGINS") || "http://localhost:3000,http://localhost:4000",
      ","
    ),
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# -------------------------------------------------
# Clustering (libcluster)
# -------------------------------------------------
if System.get_env("KUBERNETES_SERVICE_HOST") do
  config :libcluster,
    topologies: [
      k8s: [
        strategy: Cluster.Strategy.Kubernetes,
        config: [
          mode: :ip,
          kubernetes_node_basename: "phoenix_app",
          kubernetes_selector: "app=phoenix-web",
          kubernetes_namespace: System.get_env("POD_NAMESPACE") || "default",
          polling_interval: 3_000
        ]
      ]
    ]
end
