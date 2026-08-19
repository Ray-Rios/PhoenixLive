defmodule PhoenixAppWeb.AdminLive.RaysSpaceSim do
  @moduledoc """
  Live operations for RaysSpaceSim: what is running, who is on it, and the
  controls to do something about it.

  ## Two things this screen must not lie about

  **Freshness.** A roster is a snapshot taken at `last_heartbeat_at`, not a live
  feed. A server that died two minutes ago still has its last roster in the
  database, and showing those names without showing the age would invent players
  who left. Every roster row here is rendered against its server's staleness.

  **Delivery.** The hub cannot call into an instance; commands ride back on the
  next heartbeat. So a button here means *queued*, not *done* - and a command
  aimed at a server that has stopped heartbeating will sit undelivered forever.
  That is why pending commands are surfaced per server rather than the button
  just flashing green.
  """

  use PhoenixAppWeb, :live_view

  alias PhoenixApp.Games
  alias PhoenixApp.Games.HoloSims
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  @game_slug "raysspacesim"
  @refresh_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_ms, self(), :refresh)
    end

    {:ok, load(socket)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_event("refresh", _params, socket), do: {:noreply, load(socket)}

  def handle_event("drain", %{"id" => server_id}, socket) do
    {:noreply, issue(socket, server_id, "drain", %{}, "server.drain")}
  end

  def handle_event("shutdown", %{"id" => server_id}, socket) do
    {:noreply,
     issue(socket, server_id, "shutdown", %{"reason" => "Shut down by an administrator."},
       "server.shutdown")}
  end

  def handle_event("kick", %{"id" => server_id, "user-id" => user_id} = params, socket) do
    payload = %{
      "user_id" => user_id,
      "reason" => "You were removed by an administrator."
    }

    {:noreply,
     issue(socket, server_id, "kick", payload, "server.kick", %{
       "player" => params["player-name"],
       "user_id" => user_id
     })}
  end

  def handle_event("reap", _params, socket) do
    {:ok, count} = Games.mark_stale_servers_offline()

    log_action(socket, "servers.reap_stale", nil, nil, %{"marked_offline" => count})

    {:noreply,
     socket
     |> put_flash(:info, "Marked #{count} stale server(s) offline.")
     |> load()}
  end

  # -------------------------------------------------------------------------

  defp issue(socket, server_id, command, payload, action, extra_details \\ %{}) do
    case Games.queue_server_command(server_id, command, payload, socket.assigns.current_user.id) do
      {:ok, _} ->
        log_action(socket, action, "server", server_id, extra_details)

        socket
        # "Queued", never "done". See the moduledoc - this is the honest word,
        # and the difference becomes visible the first time someone presses a
        # button on an instance that has already died.
        |> put_flash(:info, "#{command} queued. It runs on that server's next heartbeat.")
        |> load()

      {:error, changeset} ->
        socket
        |> put_flash(:error, "Could not queue #{command}: #{inspect(changeset.errors)}")
        |> load()
    end
  end

  defp log_action(socket, action, subject_type, subject_id, details) do
    user = socket.assigns.current_user

    Games.log_admin_action(%{
      "actor_user_id" => user.id,
      "actor_email" => Map.get(user, :email),
      "action" => action,
      "subject_type" => subject_type,
      "subject_id" => subject_id,
      "details" => details
    })
  end

  # SURVIVES AN UNMIGRATED DATABASE.
  #
  # This is an operations page, and "the games database has no schema" is
  # exactly the kind of thing it should be able to TELL you. Letting a
  # Postgrex.Error escape mount/3 turns the one screen that could explain the
  # problem into a 500 that explains nothing.
  defp load(socket) do
    do_load(socket)
  rescue
    e in [Postgrex.Error, DBConnection.ConnectionError] ->
      assign(socket,
        game: nil,
        db_error: Exception.message(e),
        servers: [],
        players: [],
        audit: [],
        page_title: "RaysSpaceSim"
      )
  end

  defp do_load(socket) do
    case Games.get_game_by_slug(@game_slug) do
      nil ->
        assign(socket,
          game: nil,
          db_error: nil,
          servers: [],
          players: [],
          audit: [],
          page_title: "RaysSpaceSim"
        )

      game ->
        servers = game.id |> Games.list_servers_for_admin() |> Enum.map(&decorate/1)

        assign(socket,
          game: game,
          db_error: nil,
          servers: servers,
          players: players_across(servers),
          audit: Games.list_admin_actions(25),
          page_title: "RaysSpaceSim"
        )
    end
  end

  # Everything the template needs, computed once here rather than in the markup.
  defp decorate(server) do
    stale? = Games.server_stale?(server)

    %{
      record: server,
      stale?: stale?,
      # An instance is a server bound to a sim; a world server is not.
      instance?: not is_nil(server.holo_sim_id),
      sim: sim_for(server),
      # Only trusted when the heartbeat is recent - see the moduledoc. A stale
      # server's roster still exists in the database; rendering it would invent
      # players who left minutes ago.
      players: if(stale?, do: [], else: Games.server_players(server)),
      pending: Games.list_server_commands(server.id, 10) |> Enum.filter(&is_nil(&1.delivered_at))
    }
  end

  defp sim_for(%{holo_sim_id: nil}), do: nil
  defp sim_for(%{holo_sim_id: id}), do: HoloSims.get_sim(id)

  # Flattened "who is online, and where" - the question a per-server count
  # cannot answer, and the reason the roster exists at all.
  defp players_across(servers) do
    Enum.flat_map(servers, fn s ->
      Enum.map(s.players, fn p ->
        %{
          name: p["name"] || "(unnamed)",
          user_id: p["user_id"],
          character_id: p["character_id"],
          server_id: s.record.id,
          server_name: s.record.name,
          where: if(s.sim, do: s.sim.name, else: "World server")
        }
      end)
    end)
  end

  defp status_label(%{stale?: true}), do: {"Stale", "bg-amber-900/40 text-amber-300"}

  defp status_label(%{record: %{status: "online"}}), do: {"Online", "bg-green-900/40 text-green-300"}

  defp status_label(%{record: %{status: "draining"}}),
    do: {"Draining", "bg-blue-900/40 text-blue-300"}

  defp status_label(_), do: {"Offline", "bg-gray-800 text-gray-400"}

  defp ago(nil), do: "never"

  defp ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      s when s < 60 -> "#{s}s ago"
      s when s < 3600 -> "#{div(s, 60)}m ago"
      s when s < 86_400 -> "#{div(s, 3600)}h ago"
      s -> "#{div(s, 86_400)}d ago"
    end
  end

  defp short(nil), do: "-"
  defp short(id), do: id |> to_string() |> String.slice(0, 8)

  @impl true
  def render(assigns) do
    ~H"""
    <AdminSidebar.admin_layout current_path="/admin/raysspacesim">
      <div class="mb-8 flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold text-white">RaysSpaceSim</h1>
          <p class="mt-2 text-sm text-gray-400">
            Live instances, who is on them, and instance controls
          </p>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="reap"
            class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
          >
            Mark stale offline
          </button>
          <button
            phx-click="refresh"
            class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      <%= if @db_error do %>
        <div class="dark-glass shadow rounded-lg p-6 mb-8 border border-red-900/50">
          <p class="text-red-300 font-medium">The games database is not usable.</p>
          <pre class="mt-3 text-xs text-gray-400 whitespace-pre-wrap"><%= @db_error %></pre>
          <p class="mt-4 text-sm text-gray-400">
            If this says a relation does not exist, the games repo has no schema yet.
            Find out which of the three causes it is:
          </p>
          <pre class="mt-2 text-xs text-gray-300">bin/phoenix_app eval "PhoenixApp.Release.status()"</pre>
          <p class="mt-2 text-sm text-gray-400">Then run:</p>
          <pre class="mt-2 text-xs text-gray-300">bin/phoenix_app eval "PhoenixApp.Release.setup()"</pre>
        </div>
      <% end %>

      <%= if is_nil(@game) and is_nil(@db_error) do %>
        <div class="dark-glass shadow rounded-lg p-6 mb-8">
          <p class="text-amber-300 font-medium">No game registered with slug "raysspacesim".</p>
          <p class="mt-2 text-sm text-gray-400">
            The schema is there but the row is not. Nothing can heartbeat until it
            exists - a server registering against an unknown slug is refused.
          </p>
        </div>
      <% end %>

      <%= if @game do %>
        <!-- Counters -->
        <div class="grid grid-cols-1 sm:grid-cols-4 gap-4 mb-8">
          <div class="dark-glass shadow rounded-lg p-5">
            <div class="text-xs uppercase tracking-wide text-gray-500">Players online</div>
            <div class="mt-1 text-3xl font-bold text-white"><%= length(@players) %></div>
          </div>
          <div class="dark-glass shadow rounded-lg p-5">
            <div class="text-xs uppercase tracking-wide text-gray-500">Holo-sim instances</div>
            <div class="mt-1 text-3xl font-bold text-white">
              <%= Enum.count(@servers, &(&1.instance? and not &1.stale?)) %>
            </div>
          </div>
          <div class="dark-glass shadow rounded-lg p-5">
            <div class="text-xs uppercase tracking-wide text-gray-500">World servers</div>
            <div class="mt-1 text-3xl font-bold text-white">
              <%= Enum.count(@servers, &(not &1.instance? and not &1.stale?)) %>
            </div>
          </div>
          <div class="dark-glass shadow rounded-lg p-5">
            <div class="text-xs uppercase tracking-wide text-gray-500">Stale</div>
            <div class="mt-1 text-3xl font-bold text-amber-300">
              <%= Enum.count(@servers, & &1.stale?) %>
            </div>
          </div>
        </div>

        <!-- Servers -->
        <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-white mb-4">Servers</h3>

            <%= if @servers == [] do %>
              <p class="text-sm text-gray-400">
                Nothing has heartbeated yet. Start one with
                <code class="text-gray-300">Scripts\run_holosim_server.bat &lt;id&gt;</code>.
              </p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead>
                    <tr class="text-left text-gray-500 uppercase text-xs tracking-wide">
                      <th class="py-2 pr-4">Server</th>
                      <th class="py-2 pr-4">Running</th>
                      <th class="py-2 pr-4">Status</th>
                      <th class="py-2 pr-4">Players</th>
                      <th class="py-2 pr-4">Heartbeat</th>
                      <th class="py-2 pr-4">Queued</th>
                      <th class="py-2">Controls</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-800">
                    <%= for s <- @servers do %>
                      <% {label, classes} = status_label(s) %>
                      <tr class="text-gray-300">
                        <td class="py-3 pr-4">
                          <div class="text-white"><%= s.record.name %></div>
                          <div class="text-xs text-gray-500">
                            <%= s.record.host %>:<%= s.record.port %>
                          </div>
                        </td>
                        <td class="py-3 pr-4">
                          <%= if s.sim do %>
                            <div class="text-white"><%= s.sim.name %></div>
                            <div class="text-xs text-gray-500"><%= s.sim.visibility %></div>
                          <% else %>
                            <span class="text-gray-500">World</span>
                          <% end %>
                        </td>
                        <td class="py-3 pr-4">
                          <span class={"px-2 py-1 rounded text-xs font-medium #{classes}"}>
                            <%= label %>
                          </span>
                        </td>
                        <td class="py-3 pr-4">
                          <%= s.record.current_players %>/<%= s.record.max_players %>
                        </td>
                        <td class="py-3 pr-4"><%= ago(s.record.last_heartbeat_at) %></td>
                        <td class="py-3 pr-4">
                          <%= if s.pending == [] do %>
                            <span class="text-gray-600">-</span>
                          <% else %>
                            <span class="text-amber-300" title="Queued, not yet collected">
                              <%= Enum.map_join(s.pending, ", ", & &1.command) %>
                            </span>
                          <% end %>
                        </td>
                        <td class="py-3">
                          <div class="flex gap-2">
                            <button
                              phx-click="drain"
                              phx-value-id={s.record.id}
                              class="px-2 py-1 rounded text-xs bg-blue-900/40 text-blue-300 hover:bg-blue-900/70"
                              title="Refuse new joins; exits once empty"
                            >
                              Drain
                            </button>
                            <button
                              phx-click="shutdown"
                              phx-value-id={s.record.id}
                              data-confirm="Save and shut down this server now?"
                              class="px-2 py-1 rounded text-xs bg-red-900/40 text-red-300 hover:bg-red-900/70"
                            >
                              Shut down
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <p class="mt-4 text-xs text-gray-500">
                Controls are queued and collected on the server's next heartbeat, so a
                stale server will never run them.
              </p>
            <% end %>
          </div>
        </div>

        <!-- Players -->
        <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-white mb-4">Players online</h3>

            <%= if @players == [] do %>
              <p class="text-sm text-gray-400">Nobody is on a server with a recent heartbeat.</p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead>
                    <tr class="text-left text-gray-500 uppercase text-xs tracking-wide">
                      <th class="py-2 pr-4">Character</th>
                      <th class="py-2 pr-4">User</th>
                      <th class="py-2 pr-4">Where</th>
                      <th class="py-2 pr-4">Server</th>
                      <th class="py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-800">
                    <%= for p <- @players do %>
                      <tr class="text-gray-300">
                        <td class="py-3 pr-4 text-white"><%= p.name %></td>
                        <td class="py-3 pr-4 font-mono text-xs"><%= short(p.user_id) %></td>
                        <td class="py-3 pr-4"><%= p.where %></td>
                        <td class="py-3 pr-4 text-gray-500"><%= p.server_name %></td>
                        <td class="py-3">
                          <button
                            phx-click="kick"
                            phx-value-id={p.server_id}
                            phx-value-user-id={p.user_id}
                            phx-value-player-name={p.name}
                            data-confirm={"Remove #{p.name} from #{p.where}?"}
                            class="px-2 py-1 rounded text-xs bg-red-900/40 text-red-300 hover:bg-red-900/70"
                          >
                            Kick
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Audit -->
        <div class="dark-glass shadow rounded-lg overflow-hidden">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-white mb-4">Admin actions</h3>

            <%= if @audit == [] do %>
              <p class="text-sm text-gray-400">Nothing yet.</p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead>
                    <tr class="text-left text-gray-500 uppercase text-xs tracking-wide">
                      <th class="py-2 pr-4">When</th>
                      <th class="py-2 pr-4">Who</th>
                      <th class="py-2 pr-4">Action</th>
                      <th class="py-2">Detail</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-800">
                    <%= for a <- @audit do %>
                      <tr class="text-gray-300">
                        <td class="py-2 pr-4 text-gray-500"><%= ago(a.inserted_at) %></td>
                        <td class="py-2 pr-4"><%= a.actor_email || short(a.actor_user_id) %></td>
                        <td class="py-2 pr-4 font-mono text-xs text-white"><%= a.action %></td>
                        <td class="py-2 text-xs text-gray-500">
                          <%= if a.details in [nil, %{}], do: "-", else: inspect(a.details) %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </AdminSidebar.admin_layout>
    """
  end
end
