defmodule Phxlive.PluginsTest do
  # Not async: the active set is cached in :persistent_term, shared by all tests.
  use Phxlive.DataCase, async: false

  alias Phxlive.Plugins

  setup do
    Application.put_env(:phxlive, :extra_plugins, [Phxlive.Test.FixturePlugin, Phxlive.Test.RefusingPlugin])
    on_exit(fn -> Application.put_env(:phxlive, :extra_plugins, [Phxlive.Test.FixturePlugin]) end)
    Plugins.refresh_cache()
    :ok
  end

  test "installed plugins are listed, inactive by default" do
    assert Phxlive.Test.FixturePlugin in Plugins.installed()

    assert %{name: "Fixture", version: "1.2.3", active?: false, game: %{slug: "fixture_plugin"}} =
             Enum.find(Plugins.list(), &(&1.slug == "fixture_plugin"))

    refute Plugins.active?("fixture_plugin")
    assert Plugins.admin_nav() == []
    assert Plugins.active_games() == []
  end

  test "activate turns everything on, runs the hook, and registers the game" do
    assert {:ok, Phxlive.Test.FixturePlugin} = Plugins.activate("fixture_plugin")
    assert_received {:fixture_hook, :activated}

    assert Plugins.active?("fixture_plugin")
    assert [%{label: "Fixture"}] = Plugins.admin_nav()
    assert [%{slug: "fixture_plugin", name: "Fixture Game"}] = Plugins.active_games()
    assert %{is_active: true, name: "Fixture Game"} = Phxlive.Games.get_game_by_slug("fixture_plugin")

    # Persisted, not just cached.
    :persistent_term.erase({Phxlive.Plugins, :active})
    assert Plugins.active?("fixture_plugin")
  end

  test "deactivate turns it off and disables the game; data is kept" do
    {:ok, _} = Plugins.activate("fixture_plugin")
    assert {:ok, _} = Plugins.deactivate("fixture_plugin")
    assert_received {:fixture_hook, :deactivated}

    refute Plugins.active?("fixture_plugin")
    assert Plugins.admin_nav() == []
    assert %{is_active: false} = Phxlive.Games.get_game_by_slug("fixture_plugin")
  end

  test "a refusing hook leaves the plugin inactive" do
    assert {:error, {:hook_failed, :missing_configuration}} = Plugins.activate("refusing_plugin")
    refute Plugins.active?("refusing_plugin")
  end

  test "unknown plugins can't be activated, and rows for uninstalled plugins are ignored" do
    assert {:error, :not_installed} = Plugins.activate("nope")

    now = DateTime.utc_now()
    for slug <- ["fixture_plugin", "uninstalled"] do
      Repo.insert!(%Phxlive.Plugins.State{slug: slug, active: true, inserted_at: now, updated_at: now})
    end

    assert Plugins.refresh_cache() == MapSet.new(["fixture_plugin"])
  end

  test "defaults apply until an admin toggles; a saved choice then wins" do
    Application.put_env(:phxlive, :default_active_plugins, ["fixture_plugin"])
    on_exit(fn -> Application.put_env(:phxlive, :default_active_plugins, []) end)

    Plugins.refresh_cache()
    assert Plugins.active?("fixture_plugin")

    admin = user_fixture(role: "admin")
    {:ok, _} = Plugins.deactivate("fixture_plugin", admin)
    refute Plugins.active?("fixture_plugin")
    assert %{active: false, changed_by_id: id} = Repo.get(Phxlive.Plugins.State, "fixture_plugin")
    assert id == admin.id

    # Still off after the cache is rebuilt, despite the default.
    :persistent_term.erase({Phxlive.Plugins, :active})
    refute Plugins.active?("fixture_plugin")
  end

  test "the gate plug 404s inactive plugins and passes active ones" do
    conn = Plug.Test.conn(:get, "/api/games/fixture_plugin/ping")
    opts = PhxliveWeb.Plugs.PluginActive.init(slug: "fixture_plugin")

    assert %{status: 404, halted: true} = PhxliveWeb.Plugs.PluginActive.call(conn, opts)

    {:ok, _} = Plugins.activate("fixture_plugin")
    assert %{halted: false} = PhxliveWeb.Plugs.PluginActive.call(conn, opts)
  end
end

defmodule Phxlive.PluginDefinitionTest do
  use ExUnit.Case, async: true

  test "use Phxlive.Plugin fills in defaults" do
    mod = Phxlive.Test.RefusingPlugin
    assert mod.slug() == "refusing_plugin"
    assert mod.version() == "0.0.0"
    assert mod.routes() == nil
    assert mod.children() == []
    assert mod.game() == nil
  end

  test "invalid slugs are a compile error" do
    for bad <- ["Web-Lobby", "9lives", "web lobby", ""] do
      assert_raise ArgumentError, ~r/plugin slug/, fn ->
        Code.eval_string("""
        defmodule Phxlive.Test.BadSlug#{System.unique_integer([:positive])} do
          use Phxlive.Plugin, slug: #{inspect(bad)}, name: "Bad"
        end
        """)
      end
    end
  end

  test "routes DSL stores both blocks and the namespace" do
    routes = Phxlive.Test.FixtureWeb.Routes
    assert routes.__namespace__() == Phxlive.Test.FixtureWeb
    assert {:get, _, ["/ping", _, :show]} = routes.__api_routes__()
    assert {:live, _, ["/", _, :index]} = routes.__browser_routes__()
  end
end
