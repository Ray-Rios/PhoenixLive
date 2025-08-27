import Config

config :phoenix_app, PhoenixAppWeb.Endpoint,
  # Uncomment for production HTTP/HTTPS
  # http: [ip: {0, 0, 0, 0}, port: 80],
  # https: [
  #   ip: {0, 0, 0, 0},
  #   port: 443,
  #   cipher_suite: :strong,
  #   keyfile: System.get_env("SSL_KEY_PATH"),
  #   certfile: System.get_env("SSL_CERT_PATH")
  # ],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

config :phoenix_app, PhoenixApp.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true

# Redis configuration for production
config :phoenix_app, :redis_url, System.get_env("REDIS_URL") || "redis://localhost:6379"

# Mail configuration for production
config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_RELAY"),
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :always,
  auth: :always