defmodule Phxlive.Test.FixturePlugin do
  @moduledoc "A plugin used only by the test suite (registered via config :extra_plugins)."
  use Phxlive.Plugin,
    slug: "fixture_plugin",
    name: "Fixture",
    version: "1.2.3",
    description: "Exercises the plugin API in tests."

  @impl true
  def game, do: %{name: "Fixture Game", path: "/games/fixture_plugin", description: "A test game"}

  @impl true
  def admin_nav, do: [%{label: "Fixture", path: "/admin/fixture", icon: "🧪"}]

  # Hooks run in the caller's process, so tests can observe them.
  @impl true
  def on_activate do
    send(self(), {:fixture_hook, :activated})
    :ok
  end

  @impl true
  def on_deactivate do
    send(self(), {:fixture_hook, :deactivated})
    :ok
  end

  @impl true
  def hub_event(event) do
    send(self(), {:fixture_hub_event, event})
    :ok
  end
end

defmodule Phxlive.Test.CrashingPlugin do
  @moduledoc "A plugin whose hub_event raises, to prove one plugin can't break the others."
  use Phxlive.Plugin, slug: "crashing_plugin", name: "Crasher"

  @impl true
  def hub_event(_event), do: raise("boom")
end

defmodule Phxlive.Test.RefusingPlugin do
  @moduledoc "A plugin whose activation hook refuses."
  use Phxlive.Plugin, slug: "refusing_plugin", name: "Refuser"

  @impl true
  def on_activate, do: {:error, :missing_configuration}
end

defmodule Phxlive.Test.FixtureWeb.Routes do
  use Phxlive.Plugin.Routes

  api do
    get "/ping", PingController, :show
  end

  browser do
    live "/", PlayLive, :index
  end

  admin do
    live "/", AdminLive, :index
  end
end
