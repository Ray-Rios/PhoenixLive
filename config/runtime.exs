import Config

# -------------------------------------------------
# SECRET_KEY_BASE
# -------------------------------------------------
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    if config_env() == :dev do
      # Dev default if not set
      "dev_secret_key_base_#{:crypto.strong_rand_bytes(16) |> Base.encode64()}"
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
# Cockroach / Postgres Database URL
# -------------------------------------------------
db_username = System.get_env("DB_USERNAME") || "root"
db_password = System.get_env("DB_PASSWORD") || "cockroachDB"
db_host = System.get_env("DB_HOST") || "db"
db_port = String.to_integer(System.get_env("DB_PORT") || "26257")
db_name = System.get_env("DB_NAME") || "phoenixlive_dev"
db_pool = String.to_integer(System.get_env("POOL_SIZE") || "10")

database_url =
  "ecto://#{System.get_env("DB_USERNAME")}:#{System.get_env("DB_PASSWORD")}@" <>
  "#{System.get_env("DB_HOST")}:#{System.get_env("DB_PORT")}/#{System.get_env("DB_NAME")}"

config :phoenixlive, PhoenixLive.Repo,
  url: database_url,
  pool_size: 10,
  timeout: 30_000,
  ownership_timeout: 30_000,
  migration_primary_key: [type: :bigserial]

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
  System.get_env("REDIS_URL") || "redis://redis:6379/0"

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
