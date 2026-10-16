defmodule PhxliveWeb.GamesLive do
  @moduledoc """
  /games - the games list: one card per active plugin game
  (`Phxlive.Plugins.active_games/0`), each linking to the plugin's page.

  The RaysSpaceSim launcher card is temporary: it moves into that game's own
  plugin in milestone 3 (PHXLIVE.md §12).
  """
  use PhxliveWeb, :live_view

  on_mount {PhxliveWeb.UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Phxlive.PubSub, Phxlive.Plugins.topic())

    {:ok, assign(socket, page_title: "Games", games: Phxlive.Plugins.active_games(), rss_release: rss_live_release())}
  end

  # An admin activated or deactivated a plugin.
  @impl true
  def handle_info(:plugins_changed, socket), do: {:noreply, assign(socket, games: Phxlive.Plugins.active_games())}
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Sent by the desktop taskbar in the app layout; nothing to do here.
  @impl true
  def handle_event(event, _params, socket) when event in ["toggle_calendar", "toggle_start_menu", "open_app"],
    do: {:noreply, socket}

  # The live launcher release, or nil (no release yet, or the games database
  # unreachable - the page must still render either way).
  defp rss_live_release do
    with %{} = game <- Phxlive.Games.get_game_by_slug("rays-space-sim"),
         %{} = release <- Phxlive.Games.Releases.live_release(game.id),
         %{"sha256" => _} <- release.manifest["launcher"] do
      release
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp format_gb(nil), do: "?"
  defp format_gb(bytes) when bytes >= 1_073_741_824, do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"
  defp format_gb(bytes), do: "#{div(bytes, 1_048_576)} MB"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed top-[30px] inset-x-0 bottom-0 z-40 overflow-y-auto bg-black">
      <div class="max-w-5xl mx-auto px-6 py-16">
        <h1 class="text-3xl font-bold text-white mb-2">Games</h1>
        <p class="text-gray-400 mb-10">Pick a game to play.</p>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <%!-- Plugin pages are in their own live_session, so this is a full page load. --%>
          <.link
            :for={game <- @games}
            navigate={game.path}
            class="block text-left glass-dark rounded-lg p-6 border border-gray-700 hover:border-blue-400 transition-colors duration-300"
          >
            <div class="text-4xl mb-3">{Map.get(game, :icon, "🎮")}</div>
            <div class="text-xl font-semibold text-white">{game.name}</div>
            <p class="text-sm text-gray-400 mt-2">{game.description}</p>
          </.link>

          <%= if @rss_release do %>
            <%!-- A plain link, not navigate: it is a file download served by
                  LauncherDownloadController, outside LiveView. --%>
            <a
              href={~p"/games/rays-space-sim/launcher"}
              class="block text-left glass-dark rounded-lg p-6 border border-gray-700 hover:border-blue-400 transition-colors duration-300"
            >
              <div class="text-4xl mb-3">🚀</div>
              <div class="text-xl font-semibold text-white">RaysSpaceSim</div>
              <p class="text-sm text-gray-400 mt-2">
                Download the Windows launcher. It installs the game, keeps it up to date and signs you in.
              </p>
              <p class="text-xs text-gray-500 mt-3">
                Build {@rss_release.build_id} · {format_gb(@rss_release.total_bytes)} · Windows 10/11
              </p>
            </a>
          <% end %>
        </div>

        <p :if={@games == [] and is_nil(@rss_release)} class="text-gray-500">
          No games are available yet.
          <%= if @current_user.role == "admin" do %>
            Activate one on <.link navigate={~p"/admin/plugins"} class="text-blue-400 hover:underline">Plugins</.link>.
          <% end %>
        </p>
      </div>
    </div>
    """
  end
end
