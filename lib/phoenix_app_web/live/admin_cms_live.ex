defmodule PhoenixAppWeb.AdminCmsLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Repo
  alias PhoenixApp.Game.{GameSession, GameEvent, PlayerStats, WorldState}
  import Ecto.Query

  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      page_title: "Game CMS Admin",
      active_tab: "sessions",
      game_sessions: list_game_sessions(),
      game_events: list_game_events(),
      player_stats: list_player_stats(),
      world_state: list_world_state()
    )}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("delete_session", %{"id" => id}, socket) do
    case Repo.get(GameSession, id) do
      nil -> {:noreply, socket}
      session ->
        Repo.delete(session)
        {:noreply, assign(socket, game_sessions: list_game_sessions())}
    end
  end

  def handle_event("delete_event", %{"id" => id}, socket) do
    case Repo.get(GameEvent, id) do
      nil -> {:noreply, socket}
      event ->
        Repo.delete(event)
        {:noreply, assign(socket, game_events: list_game_events())}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <div class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <h1 class="text-3xl font-bold text-gray-900">Game Platform CMS</h1>
            <div class="text-sm text-gray-500">
              Admin Dashboard
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <!-- Tabs -->
        <div class="border-b border-gray-200 mb-6">
          <nav class="-mb-px flex space-x-8">
            <button 
              phx-click="switch_tab" 
              phx-value-tab="sessions"
              class={"#{if @active_tab == "sessions", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm"}
            >
              Game Sessions (#{length(@game_sessions)})
            </button>
            <button 
              phx-click="switch_tab" 
              phx-value-tab="events"
              class={"#{if @active_tab == "events", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm"}
            >
              Game Events (#{length(@game_events)})
            </button>
            <button 
              phx-click="switch_tab" 
              phx-value-tab="stats"
              class={"#{if @active_tab == "stats", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm"}
            >
              Player Stats (#{length(@player_stats)})
            </button>
            <button 
              phx-click="switch_tab" 
              phx-value-tab="world"
              class={"#{if @active_tab == "world", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm"}
            >
              World State (#{length(@world_state)})
            </button>
          </nav>
        </div>

        <!-- Content -->
        <div class="bg-white shadow rounded-lg">
          <%= case @active_tab do %>
            <% "sessions" -> %>
              <%= render_sessions(assigns) %>
            <% "events" -> %>
              <%= render_events(assigns) %>
            <% "stats" -> %>
              <%= render_stats(assigns) %>
            <% "world" -> %>
              <%= render_world(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_sessions(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Game Sessions</h3>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Level</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Score</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Health</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Active</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Last Heartbeat</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for session <- @game_sessions do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= String.slice(to_string(session.user_id), 0, 8) %>...</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= session.level %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= session.score %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= session.health %></td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{if session.is_active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                    <%= if session.is_active, do: "Active", else: "Inactive" %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= if session.last_heartbeat, do: Calendar.strftime(session.last_heartbeat, "%Y-%m-%d %H:%M"), else: "Never" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button phx-click="delete_session" phx-value-id={session.id} class="text-red-600 hover:text-red-900">Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_events(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Game Events</h3>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Event Type</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Player ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Processed</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for event <- @game_events do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= event.event_type %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= String.slice(to_string(event.player_id), 0, 8) %>...</td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{if event.processed, do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
                    <%= if event.processed, do: "Processed", else: "Pending" %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= if event.server_timestamp, do: Calendar.strftime(event.server_timestamp, "%Y-%m-%d %H:%M"), else: "N/A" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button phx-click="delete_event" phx-value-id={event.id} class="text-red-600 hover:text-red-900">Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_stats(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Player Statistics</h3>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total Score</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Games Played</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Highest Level</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Playtime (min)</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for stats <- @player_stats do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= String.slice(to_string(stats.user_id), 0, 8) %>...</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= stats.total_score %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= stats.games_played %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= stats.highest_level %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= div(stats.total_playtime, 60) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_world(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">World State Objects</h3>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">World ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Object ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Position</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Active</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for world <- @world_state do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= world.world_id %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= world.object_id %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= world.object_type %></td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= "#{world.position["x"]}, #{world.position["y"]}, #{world.position["z"]}" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{if world.is_active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                    <%= if world.is_active, do: "Active", else: "Inactive" %>
                  </span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp list_game_sessions do
    from(s in GameSession, order_by: [desc: s.inserted_at], limit: 50)
    |> Repo.all()
  end

  defp list_game_events do
    from(e in GameEvent, order_by: [desc: e.server_timestamp], limit: 50)
    |> Repo.all()
  end

  defp list_player_stats do
    from(p in PlayerStats, order_by: [desc: p.total_score], limit: 50)
    |> Repo.all()
  end

  defp list_world_state do
    from(w in WorldState, order_by: [desc: w.inserted_at], limit: 50)
    |> Repo.all()
  end
end