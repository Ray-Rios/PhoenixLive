import Config

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
# Endpoint config
# -------------------------------------------------
http_port = String.to_integer(System.get_env("PORT") || "4000")
config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: http_port],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: live_view_salt],
  server: true

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
# Swoosh / Mailer
# -------------------------------------------------
config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST") || "mailhog",
  port: String.to_integer(System.get_env("SMTP_PORT") || "1025"),
  username: System.get_env("SMTP_USER"),
  password: System.get_env("SMTP_PASS"),
  tls: :never,
  retries: 1

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
