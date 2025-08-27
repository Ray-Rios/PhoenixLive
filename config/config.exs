import Config

config :phoenix_app,
  ecto_repos: [PhoenixApp.Repo],
  generators: [timestamp_type: :utc_datetime]

config :phoenix_app, PhoenixAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PhoenixAppWeb.ErrorHTML, json: PhoenixAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PhoenixApp.PubSub,
  live_view: [signing_salt: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"]

config :phoenix_app, PhoenixApp.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Guardian configuration removed - using session-based auth instead

import_config "#{config_env()}.exs"