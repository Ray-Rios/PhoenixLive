defmodule WebLobby.PluginTest do
  # Not async: activation changes the node-wide active-plugin cache.
  use Phxlive.DataCase, async: false
  import Phoenix.ConnTest

  @endpoint PhxliveWeb.Endpoint

  setup do
    Phxlive.Plugins.refresh_cache()
    on_exit(fn -> :persistent_term.erase({Phxlive.Plugins, :active}) end)
    :ok
  end

  test "is discovered from plugins/web_lobby" do
    assert WebLobby.Plugin in Phxlive.Plugins.installed()
    assert %{slug: "web_lobby", path: "/games/web_lobby"} = Phxlive.Plugins.game_info(WebLobby.Plugin)
  end

  test "its page answers 404 until activated, then asks visitors to sign in" do
    refute Phxlive.Plugins.active?("web_lobby")
    assert build_conn() |> get("/games/web_lobby") |> response(404)

    {:ok, _} = Phxlive.Plugins.activate("web_lobby")
    assert %{is_active: true} = Phxlive.Games.get_game_by_slug("web_lobby")

    conn = build_conn() |> get("/games/web_lobby")
    assert conn.status == 302
    assert [%{slug: "web_lobby"}] = Phxlive.Plugins.active_games()
  end
end
