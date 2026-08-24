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

  require Logger

  alias PhoenixApp.CodeMap
  alias PhoenixApp.Games
  alias PhoenixApp.Games.HoloSims
  alias PhoenixApp.Games.WorldServerLauncher
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  # HYPHENATED, and not the same string as the /admin/raysspacesim route.
  #
  # This is the `games.slug` COLUMN VALUE, seeded by
  # priv/games_repo/migrations/20260809100000_create_games.exs and matched
  # against by every server heartbeat - the plugin sends `rays-space-sim`
  # (UPhxAccountSettings::GameSlug, also set in DefaultGame.ini) and the API
  # refuses a registration whose slug it cannot find.
  #
  # It read "raysspacesim" until 2026-08-22, which is why this page showed
  # "No game registered with slug ..." against a database that had the row all
  # along, and listed no instances for a game that was heartbeating fine.
  @game_slug "rays-space-sim"
  @refresh_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_ms, self(), :refresh)
    end

    {:ok,
     socket
     |> allow_upload(:codemap,
       accept: ~w(.json),
       max_entries: 1,
       # Matches PhoenixApp.CodeMap's own ceiling. Enforced in both places on
       # purpose: this one gives the browser a reason before the bytes move,
       # the other one is the check that is actually load-bearing.
       max_file_size: 8_000_000
     )
     |> load()}
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

  # --- World server orchestration ------------------------------------------
  #
  # THESE SAY "DONE", NOT "QUEUED", and the difference from the buttons above is
  # real rather than cosmetic. A drain or a kick is a message left for a server
  # to collect on its next heartbeat, so the honest word there is "queued". A
  # start or a stop is a synchronous call to the Kubernetes API that has already
  # either succeeded or failed by the time this returns.
  #
  # What is still asynchronous is the RESULT: the API accepting a Deployment
  # does not mean a container is running, which is why the panel shows desired
  # against ready and surfaces the pod's own message rather than declaring
  # victory on the button press.

  # ---------------------------------------------------------------------------
  # Code map
  #
  # THESE BUTTONS DO NOT REGENERATE ANYTHING, AND THE PAGE SAYS SO.
  #
  # Regenerating means parsing the game's headers, and this pod has no game
  # repo - RaysSpaceSim is a separate repository that is not in the web image.
  # `./deploy-game.sh --codemap` is what runs the parser, on a machine that has
  # the source. Wiring a "Regenerate" button here that could only ever fail
  # would be worse than having none.
  #
  # What is genuinely useful from inside the cluster is the other half: saying
  # how stale the snapshot is against the build that is actually running, and
  # taking delivery of a newer one without waiting for a full Phoenix deploy.
  # ---------------------------------------------------------------------------
  def handle_event("codemap_validate", _params, socket), do: {:noreply, socket}

  def handle_event("codemap_cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :codemap, ref)}
  end

  def handle_event("codemap_install", _params, socket) do
    results =
      consume_uploaded_entries(socket, :codemap, fn %{path: path}, _entry ->
        {:ok, CodeMap.install(path)}
      end)

    socket =
      case results do
        [{:ok, from}] ->
          audit(socket, "codemap.install", %{"generated_from" => from})

          put_flash(
            socket,
            :info,
            "Code map replaced with the snapshot of #{from || "an unnamed commit"}."
          )

        [{:error, reason}] ->
          put_flash(socket, :error, reason)

        [] ->
          put_flash(socket, :error, "Choose a codemap.json first.")
      end

    {:noreply, load(socket)}
  end

  def handle_event("codemap_discard", _params, socket) do
    socket =
      case CodeMap.discard() do
        :ok ->
          audit(socket, "codemap.discard", %{})
          put_flash(socket, :info, "Uploaded snapshot removed. Back to the one in the release.")

        {:error, reason} ->
          put_flash(socket, :error, "Could not remove it: #{reason}")
      end

    {:noreply, load(socket)}
  end

  def handle_event("world_start", _params, socket) do
    {:noreply, world_op(socket, :start, "world.start", "Start requested.")}
  end

  def handle_event("world_stop", _params, socket) do
    {:noreply, world_op(socket, :stop, "world.stop", "Scaled to zero.")}
  end

  def handle_event("world_remove", _params, socket) do
    {:noreply,
     world_op(socket, :remove, "world.remove", "Deployment deleted.")}
  end

  def handle_event("world_logs", params, socket) do
    previous? = params["previous"] == "true"

    case WorldServerLauncher.logs(tail_lines: 300, previous: previous?) do
      {:ok, text} ->
        {:noreply,
         assign(socket,
           world_logs: if(String.trim(text) == "", do: "(the pod has produced no output yet)", else: text),
           world_logs_error: nil,
           world_logs_previous: previous?
         )}

      {:error, :no_pod} ->
        {:noreply,
         assign(socket,
           world_logs: nil,
           world_logs_error: "No pod is running. Start the world server first.",
           world_logs_previous: previous?
         )}

      {:error, reason} ->
        {:noreply,
         assign(socket,
           world_logs: nil,
           world_logs_error: describe_error(reason),
           world_logs_previous: previous?
         )}
    end
  end

  def handle_event("world_logs_close", _params, socket) do
    {:noreply, assign(socket, world_logs: nil, world_logs_error: nil)}
  end

  # -------------------------------------------------------------------------

  defp world_op(socket, op, action, success_message) do
    case apply(WorldServerLauncher, op, op_args(op)) do
      {:ok, outcome} ->
        log_action(socket, action, "world_server", nil, %{"outcome" => to_string(outcome)})

        socket
        |> put_flash(:info, "#{success_message} (#{outcome})")
        |> load()

      {:error, reason} ->
        socket
        |> put_flash(:error, "Could not #{op}: #{describe_error(reason)}")
        |> load()
    end
  end

  # start/1 takes options; stop/0 and remove/0 take none.
  defp op_args(:start), do: [[]]
  defp op_args(_), do: []

  # The Kubernetes API's own wording is the useful part - "deployments.apps is
  # forbidden: User ... cannot create resource" names the exact missing RBAC
  # rule, which a generic "operation failed" would throw away.
  defp describe_error(:not_in_cluster),
    do: "Not running inside Kubernetes, so there is nothing to orchestrate."

  defp describe_error(:no_image_configured),
    do: "WORLD_IMAGE is not set, so there is no image to run."

  defp describe_error({:http, status, message}), do: "HTTP #{status}: #{message}"
  defp describe_error(other), do: inspect(other)

  defp assign_world(socket) do
    socket
    |> assign(world: WorldServerLauncher.status())
    |> assign_new(:world_logs, fn -> nil end)
    |> assign_new(:world_logs_error, fn -> nil end)
    |> assign_new(:world_logs_previous, fn -> false end)
  end

  # The badge answers "can I trust this page", not "does a file exist". A map
  # that parses fine but describes a different commit than the one running is
  # the dangerous state - it is confidently wrong - so it reads Stale, not OK.
  defp codemap_label(%{active: nil}), do: {"Missing", "bg-red-900/40 text-red-300"}

  defp codemap_label(%{active: %{readable?: false}}),
    do: {"Unreadable", "bg-red-900/40 text-red-300"}

  defp codemap_label(%{matches_live?: false}), do: {"Stale", "bg-amber-900/40 text-amber-300"}

  defp codemap_label(%{matches_live?: nil}), do: {"Loaded", "bg-gray-800 text-gray-400"}

  defp codemap_label(%{active: %{source: :override}}),
    do: {"Current (uploaded)", "bg-green-900/40 text-green-300"}

  defp codemap_label(_), do: {"Current", "bg-green-900/40 text-green-300"}

  # LiveView's upload errors are atoms. Rendering them raw puts
  # ":too_large" on the screen, which is a symbol, not a sentence.
  defp upload_error_text(:too_large), do: "That file is over the 8 MB limit."

  defp upload_error_text(:not_accepted),
    do: "Only .json is accepted - this wants the codemap.json extract.py wrote."

  defp upload_error_text(:too_many_files), do: "One file at a time."
  defp upload_error_text(other), do: "Upload failed: #{inspect(other)}"

  defp world_label(%{state: :running}), do: {"Running", "bg-green-900/40 text-green-300"}
  defp world_label(%{state: :starting}), do: {"Starting", "bg-blue-900/40 text-blue-300"}
  defp world_label(%{state: :stopped}), do: {"Stopped", "bg-gray-800 text-gray-400"}
  defp world_label(%{state: :absent}), do: {"Not deployed", "bg-gray-800 text-gray-400"}
  defp world_label(%{state: :error}), do: {"Error", "bg-red-900/40 text-red-300"}
  defp world_label(_), do: {"Unknown", "bg-gray-800 text-gray-400"}

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

  # The code map has nothing to do with the games database, so a games database
  # that is down must not be able to block an upload. Everything else on this
  # page is already inside that database's blast radius; this is not, and
  # letting the audit write drag it back in would be a self-inflicted coupling.
  defp audit(socket, action, details) do
    log_action(socket, action, "codemap", nil, details)
    socket
  rescue
    e ->
      Logger.warning("codemap: audit write failed: #{Exception.message(e)}")
      socket
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
  # The cluster half is assigned OUTSIDE the database rescue below, on purpose.
  # A games database that will not answer says nothing about whether the world
  # server is running, and the screen is at its most useful when exactly one of
  # the two is broken - so a Postgres error must not also blank the panel that
  # could tell you the pods are fine.
  defp load(socket) do
    socket
    |> load_games()
    |> assign_world()
    |> assign_codemap()
  end

  # Called on the 5-second tick like everything else here, which it can afford
  # to be: CodeMap.status/0 stats two files and reuses its last parse unless one
  # of them moved. Parsing a megabyte of JSON five times a minute to render a
  # commit hash would be the obvious way to write this and the wrong one.
  defp assign_codemap(socket), do: assign(socket, codemap: CodeMap.status())

  defp load_games(socket) do
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
          <a
            href="/admin/raysspacesim/codebase"
            class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
          >
            Codebase
          </a>
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

      <!-- World server (cluster orchestration) -->
      <% {world_text, world_classes} = world_label(@world) %>
      <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
        <div class="px-4 py-5 sm:p-6">
          <div class="flex justify-between items-start mb-4">
            <div>
              <h3 class="text-lg font-medium text-white">World server</h3>
              <p class="mt-1 text-xs text-gray-500">
                <%= @world.deployment_name %> in namespace <%= @world.namespace || "-" %>
              </p>
            </div>
            <span class={"px-2 py-1 rounded text-xs font-medium #{world_classes}"}>
              <%= world_text %>
            </span>
          </div>

          <%= if @world.available? do %>
            <div class="flex flex-wrap gap-2 mb-4">
              <button
                phx-click="world_start"
                class="bg-green-700 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                <%= if @world.state == :absent, do: "Deploy and start", else: "Start / apply" %>
              </button>
              <button
                phx-click="world_stop"
                disabled={@world.state in [:stopped, :absent]}
                class="bg-gray-700 hover:bg-gray-600 disabled:opacity-40 disabled:hover:bg-gray-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Stop
              </button>
              <button
                phx-click="world_logs"
                class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Tail logs
              </button>
              <button
                phx-click="world_logs"
                phx-value-previous="true"
                title="The container that died, not the one running. The only way to see why something crash-looped."
                class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Crashed container logs
              </button>
              <button
                phx-click="world_remove"
                disabled={@world.state == :absent}
                data-confirm="Delete the Deployment entirely? Start will recreate it from the current configuration."
                class="ml-auto bg-red-900/60 hover:bg-red-800 disabled:opacity-40 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Remove deployment
              </button>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Desired</div>
                <div class="mt-1 text-white"><%= @world.desired %></div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Ready</div>
                <div class="mt-1 text-white"><%= @world.ready %></div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Pods</div>
                <div class="mt-1 text-white"><%= length(@world.pods) %></div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Restarts</div>
                <div class="mt-1 text-white">
                  <%= @world.pods |> Enum.map(& &1.restarts) |> Enum.sum() %>
                </div>
              </div>
            </div>

            <%= if @world.error do %>
              <p class="mt-4 text-sm text-red-300"><%= @world.error %></p>
            <% end %>

            <%= if @world.pods != [] do %>
              <div class="mt-4 overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead>
                    <tr class="text-left text-gray-500 uppercase text-xs tracking-wide">
                      <th class="py-2 pr-4">Pod</th>
                      <th class="py-2 pr-4">Phase</th>
                      <th class="py-2 pr-4">Ready</th>
                      <th class="py-2 pr-4">Restarts</th>
                      <th class="py-2">Detail</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-800">
                    <%= for p <- @world.pods do %>
                      <tr class="text-gray-300">
                        <td class="py-2 pr-4 font-mono text-xs"><%= p.name %></td>
                        <td class="py-2 pr-4"><%= p.phase %></td>
                        <td class="py-2 pr-4">
                          <%= if p.ready?, do: "yes", else: "no" %>
                        </td>
                        <td class="py-2 pr-4"><%= p.restarts %></td>
                        <td class="py-2 text-xs text-amber-300"><%= p.message %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>

            <%= if @world_logs || @world_logs_error do %>
              <div class="mt-6">
                <div class="flex justify-between items-center mb-2">
                  <h4 class="text-sm font-medium text-white">
                    Logs<%= if @world_logs_previous, do: " (previous container)" %>
                  </h4>
                  <button phx-click="world_logs_close" class="text-xs text-gray-400 hover:text-white">
                    Close
                  </button>
                </div>
                <%= if @world_logs_error do %>
                  <p class="text-sm text-red-300"><%= @world_logs_error %></p>
                <% else %>
                  <pre class="bg-black/50 rounded p-3 text-xs text-gray-300 overflow-x-auto max-h-96 overflow-y-auto whitespace-pre"><%= @world_logs %></pre>
                <% end %>
              </div>
            <% end %>
          <% else %>
            <p class="text-sm text-amber-300">
              <%= describe_error(@world.reason) %>
            </p>
            <p class="mt-2 text-sm text-gray-400">
              A world server started by hand still heartbeats in and appears below;
              this panel only controls one running in the cluster.
            </p>
          <% end %>
        </div>
      </div>


      <!-- Code map -->
      <% cm = @codemap %>
      <% active = cm.active %>
      <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
        <div class="px-4 py-5 sm:p-6">
          <div class="flex justify-between items-start mb-4">
            <div>
              <h3 class="text-lg font-medium text-white">Code map</h3>
              <p class="mt-1 text-xs text-gray-500">
                The snapshot behind
                <a href="/admin/raysspacesim/codebase" class="text-gray-400 hover:text-white underline">
                  /admin/raysspacesim/codebase
                </a>
              </p>
            </div>
            <% {cm_text, cm_classes} = codemap_label(cm) %>
            <span class={"px-2 py-1 rounded text-xs font-medium #{cm_classes}"}>
              <%= cm_text %>
            </span>
          </div>

          <%= if active do %>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-5">
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Snapshot of</div>
                <div class="mt-1 text-sm font-mono text-white break-all">
                  <%= active.generated_from || "unknown" %>
                </div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Generated</div>
                <div class="mt-1 text-sm text-gray-300"><%= active.generated_at || "-" %></div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Live build</div>
                <div class="mt-1 text-sm font-mono text-gray-300"><%= cm.live_tag || "-" %></div>
              </div>
              <div>
                <div class="text-xs uppercase tracking-wide text-gray-500">Source</div>
                <div class="mt-1 text-sm text-gray-300">
                  <%= if active.source == :override, do: "uploaded", else: "in the release" %>
                </div>
              </div>
            </div>

            <p class="text-xs text-gray-500 mb-5">
              <%= active.modules %> modules &middot; <%= active.classes %> classes &middot;
              <%= active.functions %> functions &middot; <%= active.properties %> properties &middot;
              <%= active.replicated %> replicated
            </p>

            <%= case cm.matches_live? do %>
              <% false -> %>
                <p class="text-sm text-amber-300 mb-4">
                  This map was parsed from <span class="font-mono"><%= active.game_commit %></span>,
                  but the live image was built from <span class="font-mono"><%= cm.live_tag %></span>.
                  It is describing code that is not what is running.
                </p>
              <% nil -> %>
                <p class="text-sm text-gray-500 mb-4">
                  No live image tag to compare against, so staleness cannot be checked here -
                  read the commit above against the game repo's HEAD.
                </p>
              <% true -> %>
                <p class="text-sm text-gray-400 mb-4">
                  Same commit as the live image. The map matches what is running.
                </p>
            <% end %>

            <%= if active.game_dirty do %>
              <p class="text-sm text-amber-300 mb-4">
                Parsed from a dirty tree, so the commit above does not fully identify it.
              </p>
            <% end %>
          <% else %>
            <p class="text-sm text-amber-300 mb-4">
              No snapshot on disk. <span class="font-mono">/admin/raysspacesim/codebase</span>
              has nothing to render until one arrives.
            </p>
          <% end %>

          <!-- WHY THERE IS NO "REGENERATE" BUTTON -->
          <div class="border-t border-gray-800 pt-4 mt-2">
            <p class="text-xs text-gray-500 mb-3">
              Regenerating parses the game's headers, and this pod has no game repo -
              RaysSpaceSim is a separate repository and is not in the web image. The parser
              runs where the source is:
              <span class="font-mono text-gray-400">./deploy-game.sh --codemap</span>
              (or automatically after every <span class="font-mono text-gray-400">./deploy-game.sh</span> cook).
              That writes <span class="font-mono text-gray-400">priv/codemap/codemap.json</span>,
              which reaches this site on the next <span class="font-mono text-gray-400">./deploy-prod.sh</span>.
              Upload it here instead to skip that wait.
            </p>

            <form phx-submit="codemap_install" phx-change="codemap_validate" class="flex flex-wrap items-center gap-3">
              <.live_file_input
                upload={@uploads.codemap}
                class="text-xs text-gray-400 file:mr-3 file:py-2 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-medium file:bg-gray-700 file:text-white hover:file:bg-gray-600"
              />
              <button
                type="submit"
                disabled={@uploads.codemap.entries == []}
                class="bg-blue-700 hover:bg-blue-600 disabled:opacity-40 disabled:hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Install snapshot
              </button>
              <%= if active && active.source == :override do %>
                <button
                  type="button"
                  phx-click="codemap_discard"
                  class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
                >
                  Revert to the release copy
                </button>
              <% end %>
            </form>

            <%= for entry <- @uploads.codemap.entries do %>
              <div class="mt-3 flex items-center gap-3 text-xs text-gray-400">
                <span class="font-mono"><%= entry.client_name %></span>
                <span><%= entry.progress %>%</span>
                <button
                  type="button"
                  phx-click="codemap_cancel"
                  phx-value-ref={entry.ref}
                  class="text-gray-500 hover:text-red-300"
                >
                  cancel
                </button>
              </div>
              <%= for err <- upload_errors(@uploads.codemap, entry) do %>
                <p class="mt-1 text-xs text-red-300"><%= upload_error_text(err) %></p>
              <% end %>
            <% end %>

            <%= for err <- upload_errors(@uploads.codemap) do %>
              <p class="mt-2 text-xs text-red-300"><%= upload_error_text(err) %></p>
            <% end %>

            <%= if cm.override && not cm.override.readable? do %>
            <p class="mt-4 text-xs text-red-300">
              There is an uploaded snapshot at
              <span class="font-mono"><%= cm.override.path %></span> and it cannot be read
              (<%= cm.override.error %>). The release copy is being served instead.
            </p>
          <% end %>

          <p class="mt-4 text-xs text-gray-600">
            An uploaded snapshot lives in this pod only
            (<span class="font-mono"><%= cm.override_dir %></span>) and the next restart or
            rollout puts the release copy back. That is deliberate: the durable path is
            <span class="font-mono">--codemap</span> then a deploy, and the one persistent
            volume this pod has is served publicly at /uploads, so a code map cannot go
            on it without publishing the codebase.
          </p>
          </div>
        </div>
      </div>

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
