import Config

# ----------------------------
# Guardian (dev)
# ----------------------------
config :phoenix_app, PhoenixApp.Auth.Guardian,
  issuer: "phoenix_app",
  # Secret picked up from runtime.exs
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_guardian_secret_placeholder"

# ----------------------------
# Endpoint
# ----------------------------
config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_placeholder",
  watchers: [
    npm: ["run", "watch", cd: Path.expand("../assets", __DIR__)]
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/phoenix_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# ----------------------------
# Dev routes & logging
# ----------------------------
config :phoenix_app, dev_routes: true
config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :swoosh, :api_client, false

# ----------------------------
# Redis & Mail (dev)
# ----------------------------
config :phoenix_app, :redis_url,
  System.get_env("REDIS_URL") || "redis://localhost:6379"

config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST") || "mailhog",
  port: String.to_integer(System.get_env("SMTP_PORT") || "1025"),
  username: System.get_env("SMTP_USER"),
  password: System.get_env("SMTP_PASS"),
  tls: :never,
  retries: 1
