import Config

# ----------------------------
# Endpoint
# ----------------------------
config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  url: [host: System.get_env("PHOENIX_HOST") || "rio-tek.com", port: 443, scheme: "https"],
  check_origin: [
    "https://rio-tek.com",
    "https://www.rio-tek.com"
  ],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  server: true,
  secret_key_base: (System.get_env("SECRET_KEY_BASE") ||
    raise("SECRET_KEY_BASE is missing. Generate with `mix phx.gen.secret`")),
  live_view: [signing_salt: (System.get_env("LIVE_VIEW_SIGNING_SALT") ||
    raise("LIVE_VIEW_SIGNING_SALT is missing"))]

# CORS origins for production
config :cors_plug,
  origin: [
    "https://rio-tek.com",
    "https://www.rio-tek.com"
  ],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since"]
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
