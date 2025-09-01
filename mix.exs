defmodule PhoenixApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {PhoenixApp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.17.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.17"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:joken, "~> 2.5"},
      {:guardian, "~> 2.3"},
      {:plug_cowboy, "~> 2.5"},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:redix, "~> 1.2"},
      {:bcrypt_elixir, "~> 3.0"},
      # E-commerce & Payments
      {:stripity_stripe, "~> 3.0"},
      {:decimal, "~> 2.0"},
      # File uploads
      {:arc, "~> 0.11"},
      {:arc_ecto, "~> 0.11"},
      # 2FA
      {:pot, "~> 1.0"},
      {:qr_code, "~> 3.1"},
      # File handling
      {:mime, "~> 2.0"},
      # Caching
      {:cachex, "~> 3.4"},
      # Additional utilities
      {:uuid, "~> 1.1"},
      {:cors_plug, "~> 3.0"},
      {:tz, "~> 0.24"},
      {:httpoison, "~> 2.0"}
    ]
  end

  defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
    "ecto.reset": ["ecto.drop", "ecto.setup"],
    test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],

    # Frontend asset tasks using npm instead of mix tailwind
    "assets.setup": ["cmd --cd assets npm install"],
    "assets.build": ["cmd --cd assets npm run build"],
    "assets.deploy": ["cmd --cd assets npm run deploy", "phx.digest"]
  ]
  end
end