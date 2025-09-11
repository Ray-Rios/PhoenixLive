import Config

# ----------------------------
# Endpoint
# ----------------------------
config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: (System.get_env("SECRET_KEY_BASE") ||
    raise("SECRET_KEY_BASE is missing. Generate with `mix phx.gen.secret`")),
  live_view: [signing_salt: (System.get_env("LIVE_VIEW_SIGNING_SALT") ||
    raise("LIVE_VIEW_SIGNING_SALT is missing"))]

# ----------------------------
# Guardian (prod)
# ----------------------------
config :phoenix_app, PhoenixApp.Auth.Guardian,
  secret_key: (System.get_env("GUARDIAN_SECRET_KEY") ||
    raise("GUARDIAN_SECRET_KEY is missing. Generate with `mix guardian.gen.secret`"))

# ----------------------------
# Redis & Mail
# ----------------------------
config :phoenix_app, :redis_url,
  System.get_env("REDIS_URL") || "redis://redis:6379/0"

config :phoenix_app, :enable_redis, 
  System.get_env("ENABLE_REDIS", "false") == "true"

config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST") || "smtp.yourprovider.com",
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  username: System.get_env("SMTP_USER"),
  password: System.get_env("SMTP_PASS"),
  tls: :if_available,
  retries: 3
