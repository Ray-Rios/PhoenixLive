import Config

config :phoenix_app, PhoenixApp.Auth.Guardian,
  issuer: "phoenix_app",
  secret_key: "iTYKvanE1HgOWaWB3lu_SAcTBxeYJXBnY_lNMHzEAP3Wrpz9z0l98-V3DxJcJiQk" # replace with `mix guardian.gen.secret`

config :phoenix_app, PhoenixApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "phoenix_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0y1z2",
  watchers: [
    # Use npm for Tailwind
    npm: ["run", "watch", "--prefix", "assets"],
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]


config :phoenix_app, PhoenixAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/phoenix_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix_app, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :swoosh, :api_client, false

# Redis configuration
config :phoenix_app, :redis_url, "redis://localhost:6379"

# Mail configuration for development
config :phoenix_app, PhoenixApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "localhost",
  port: 1025,
  username: nil,
  password: nil,
  tls: :never,
  retries: 1