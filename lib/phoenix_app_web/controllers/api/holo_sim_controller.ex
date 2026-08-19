defmodule PhoenixAppWeb.Api.HoloSimController do
  @moduledoc """
  Holo-sim API — `/api/games/:game_slug/holosims`.

  Authorised the same way as the rest of the games API: a player's Guardian
  bearer token, or a trusted game server presenting the server API key and
  naming the user it acted for.

  Every access decision delegates to `HoloSims.can_access?/2`. Nothing in this
  module re-derives the rules — a second implementation would eventually drift
  from the first, and the drift would be a security hole rather than a bug.
  """

  use PhoenixAppWeb, :controller

  alias PhoenixApp.Games
  alias PhoenixApp.Games.HoloSims
  alias PhoenixApp.Games.InstanceLauncher

  plug PhoenixAppWeb.Plugs.GamesApiKeyOrAuth

  # ---------------------------------------------------------------------
  # Player endpoints
  # ---------------------------------------------------------------------

  # GET /holosims — mine, shared with me, and public
  def index(conn, %{"game_slug" => slug} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params) do
      json(conn, %{
        success: true,
        owned: Enum.map(HoloSims.list_owned(game.id, user_id), &sim_json(&1, user_id)),
        shared: Enum.map(HoloSims.list_shared(game.id, user_id), &sim_json(&1, user_id)),
        public: Enum.map(HoloSims.list_public(game.id), &sim_json(&1, user_id)),
        slots: HoloSims.slot_usage(game.id, user_id)
      })
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # POST /holosims
  def create(conn, %{"game_slug" => slug} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params) do
      attrs =
        params
        |> Map.take(["name", "description", "visibility", "kind", "spec", "template_id", "visitors_can_build"])

      case HoloSims.create_sim(game.id, user_id, attrs) do
        {:ok, sim} ->
          conn |> put_status(:created) |> json(%{success: true, sim: sim_json(sim, user_id)})

        {:error, :slot_limit, message} ->
          error(conn, 409, message)

        {:error, changeset} ->
          error(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # GET /holosims/:id — includes the spec, so it is gated on access
  def show(conn, %{"id" => id} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id) do
      json(conn, %{
        success: true,
        sim: sim_json(sim, user_id),
        spec: sim.spec,
        members: if(sim.owner_user_id == user_id, do: members_json(sim.id), else: nil),
        has_saved_state: HoloSims.get_state(sim.id) != nil
      })
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # PUT /holosims/:id
  def update(conn, %{"id" => id} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id),
         :ok <- require_edit(sim, user_id) do
      attrs = Map.take(params, [
          "name",
          "description",
          "visibility",
          "kind",
          "spec",
          "template_id",
          "visitors_can_build"
        ])

      case HoloSims.update_sim(sim, attrs) do
        {:ok, updated} -> json(conn, %{success: true, sim: sim_json(updated, user_id)})
        {:error, changeset} -> error(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # DELETE /holosims/:id
  def delete(conn, %{"id" => id} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id),
         :ok <- require_owner(sim, user_id) do
      {:ok, _} = HoloSims.delete_sim(sim)
      json(conn, %{success: true})
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # ---------------------------------------------------------------------
  # Members
  # ---------------------------------------------------------------------

  # POST /holosims/:id/members
  def add_member(conn, %{"id" => id} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id),
         :ok <- require_owner(sim, user_id),
         {:ok, invitee} <- fetch_required(params, "user_id") do
      case HoloSims.invite_member(sim, invitee, user_id, params["role"] || "viewer") do
        {:ok, member} ->
          conn |> put_status(:created) |> json(%{success: true, member: member_json(member)})

        {:error, :already_owner, message} ->
          error(conn, 409, message)

        {:error, changeset} ->
          error(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # DELETE /holosims/:id/members/:user_id
  #
  # The owner may remove anyone; a member may remove themselves. That second
  # case matters - being unable to leave someone else's sim is the kind of thing
  # that turns into a support ticket.
  def remove_member(conn, %{"id" => id, "member_user_id" => target} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id) do
      if sim.owner_user_id == user_id or target == user_id do
        case HoloSims.remove_member(sim.id, target) do
          {:ok, _} -> json(conn, %{success: true})
          {:error, :not_found} -> error(conn, 404, "That player is not a member")
        end
      else
        error(conn, 403, "Only the owner can remove other members")
      end
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # POST /holosims/:id/accept
  def accept(conn, %{"id" => id} = params) do
    with {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params) do
      case HoloSims.accept_invite(id, user_id) do
        {:ok, member} -> json(conn, %{success: true, member: member_json(member)})
        {:error, :not_found} -> error(conn, 404, "No invitation found")
        {:error, changeset} -> error(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # ---------------------------------------------------------------------
  # Launch
  # ---------------------------------------------------------------------

  # POST /holosims/:id/launch
  #
  # Asks for a running instance of this sim. Returns `ready` with an address, or
  # `pending` while a pod comes up.
  #
  # INSTANCES ARE SHARED. One sim, one instance, however many players are in it.
  # So a launch is really "join, starting one first if nobody has": if an
  # instance is already live, everyone who passes the access check gets the same
  # address. That is what makes public sims social rather than a hundred lonely
  # copies of the same world.
  #
  # There is deliberately NO cap on how many instances one account can be
  # responsible for. An earlier draft refused a second launch while the player's
  # first was still running, which had an obvious bug: leaving a popular public
  # sim that others were still enjoying would lock the owner out of their own
  # library. Occupancy already bounds cost - an empty pod shuts down, a busy one
  # is busy because people are in it - so the only thing left worth limiting is
  # the rate of starts.
  def launch(conn, %{"id" => id} = params) do
    with {:ok, game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id) do
      case Games.get_instance_for_sim(game.id, id) do
        # Already running - join it. No second pod, no waiting.
        %{} = server ->
          json(conn, launch_json(:ready, sim, server))

        nil ->
          case HoloSims.launch_allowed?(game.id, user_id) do
            :ok -> begin_launch(conn, game, sim, user_id)
            {:error, :rate_limited, message} -> error(conn, 429, message)
          end
      end
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # GET /holosims/:id/status - poll while the door animation plays
  def status(conn, %{"id" => id} = params) do
    with {:ok, game} <- fetch_game(params["game_slug"]),
         {:ok, user_id} <- resolve_user_id(conn, params),
         {:ok, sim} <- HoloSims.get_sim_for_user(id, user_id) do
      case Games.get_instance_for_sim(game.id, id) do
        nil -> json(conn, %{success: true, status: "pending", holo_sim_id: sim.id})
        server -> json(conn, launch_json(:ready, sim, server))
      end
    else
      {:error, :not_found} -> error(conn, 404, "Holo-sim not found")
      {:error, :forbidden} -> error(conn, 403, "You do not have access to this Holo-sim")
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # M5: create a Kubernetes Job. Nothing else about launching moved - the client
  # already polls /status, the access check already guarded the door, and the
  # instance still announces itself by heartbeat.
  #
  # The M4 path is kept as the fallback, not as dead code: outside a cluster, or
  # before an instance image exists, the hub records the intent and reports
  # `pending` so a server started by hand with -HoloSimId= is still found by the
  # next poll. That is the development loop, and it must keep working.
  defp begin_launch(conn, _game, sim, user_id) do
    {:ok, sim} = HoloSims.record_launch(sim)

    result =
      if InstanceLauncher.available?() do
        InstanceLauncher.launch(%{id: sim.game_id}, sim, user_id)
      else
        {:ok, :manual}
      end

    case result do
      {:ok, :manual} ->
        conn
        |> put_status(202)
        |> json(%{
          success: true,
          status: "pending",
          holo_sim_id: sim.id,
          message: "Instance requested. Poll /status until it reports ready."
        })

      {:ok, started} when started in [:started, :already_starting] ->
        conn
        |> put_status(202)
        |> json(%{
          success: true,
          status: "pending",
          holo_sim_id: sim.id,
          message: "Instance starting. Poll /status until it reports ready."
        })

      {:error, reason} ->
        # 503, not 500. The request was valid and the player did nothing wrong -
        # the cluster could not start a process right now, and a retry is a
        # reasonable thing for the client to do.
        conn
        |> put_status(503)
        |> json(%{
          success: false,
          status: "failed",
          holo_sim_id: sim.id,
          error: launch_error_message(reason)
        })
    end
  end

  defp launch_error_message(:no_free_port),
    do: "No instance capacity available right now. Try again shortly."

  defp launch_error_message(:no_image_configured),
    do: "Instance orchestration is not configured on this server."

  defp launch_error_message(_), do: "Could not start an instance. Try again shortly."

  defp launch_json(:ready, sim, server) do
    %{
      success: true,
      status: "ready",
      holo_sim_id: sim.id,
      address: "#{server.host}:#{server.port}",
      host: server.host,
      port: server.port,
      map_name: server.map_name,
      current_players: server.current_players,
      max_players: server.max_players
    }
  end

  # ---------------------------------------------------------------------
  # Server-only
  # ---------------------------------------------------------------------

  # GET /holosims/:id/access/:target_user_id
  #
  # THE SECURITY BOUNDARY for per-sim instances.
  #
  # With one server process per sim, a player who learns another sim's host:port
  # could otherwise connect straight to it. The instance server calls this in
  # PreLoginAsync and refuses anyone it says no to. Server API key only - a
  # player token must never be able to ask this question about other people, and
  # must never be able to answer it about themselves.
  def check_access(conn, %{"id" => id, "target_user_id" => target} = params) do
    with :ok <- require_server_auth(conn),
         {:ok, _game} <- fetch_game(params["game_slug"]) do
      case HoloSims.get_sim(id) do
        nil ->
          error(conn, 404, "Holo-sim not found")

        sim ->
          json(conn, %{
            success: true,
            allowed: HoloSims.can_access?(sim, target),
            is_owner: sim.owner_user_id == target,
            visibility: sim.visibility,
            spec: sim.spec,
            # The instance enforces this in-game: a visitor with build rights
            # off can interact but cannot leave a permanent mark.
            visitors_can_build: sim.visitors_can_build,
            can_persist: HoloSims.can_persist?(sim, target),
            state: (HoloSims.get_state(id) || %{state: %{}}).state
          })
      end
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # PUT /holosims/:id/state - instance server checkpoints the world
  #
  # One row per sim: a shared instance holds one world, so there is one state.
  # Whether a given player's session may cause that write is decided by
  # HoloSims.can_persist?/2, which honours the owner's visitors_can_build
  # setting.
  def save_state(conn, %{"id" => id} = params) do
    with :ok <- require_server_auth(conn),
         {:ok, _game} <- fetch_game(params["game_slug"]),
         {:ok, target} <- fetch_required(params, "user_id") do
      state = params["state"] || %{}

      case HoloSims.get_sim(id) do
        nil ->
          error(conn, 404, "Holo-sim not found")

        sim ->
          # Re-check access on write. A pod that has outlived a revoked
          # invitation must not keep writing into someone else's sim.
          cond do
            not HoloSims.can_access?(sim, target) ->
              error(conn, 403, "That user no longer has access to this Holo-sim")

            true ->
              case HoloSims.save_state(sim, target, state) do
                {:ok, _} -> json(conn, %{success: true})
                {:error, :cannot_persist, message} -> error(conn, 403, message)
                {:error, changeset} -> error(conn, 422, changeset_errors(changeset))
              end
          end
      end
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  # ---------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------

  defp fetch_game(slug) do
    case Games.get_game_by_slug(slug) do
      nil -> {:error, 404, "Unknown game: #{slug}"}
      game -> if game.is_active, do: {:ok, game}, else: {:error, 403, "Game is not active"}
    end
  end

  defp resolve_user_id(conn, params) do
    case conn.assigns[:games_auth_mode] do
      :player_token ->
        {:ok, Guardian.Plug.current_resource(conn).id}

      :server_api_key ->
        case params["user_id"] do
          nil -> {:error, 400, "user_id is required when authenticating via server API key"}
          user_id -> {:ok, user_id}
        end
    end
  end

  defp require_server_auth(conn) do
    case conn.assigns[:games_auth_mode] do
      :server_api_key -> :ok
      _ -> {:error, 403, "This endpoint requires a server API key"}
    end
  end

  defp require_owner(sim, user_id) do
    if sim.owner_user_id == user_id, do: :ok, else: {:error, 403, "Only the owner can do that"}
  end

  defp require_edit(sim, user_id) do
    cond do
      sim.owner_user_id != user_id -> {:error, 403, "Only the owner can edit this Holo-sim"}
      sim.is_locked -> {:error, 423, "This Holo-sim is locked pending moderation"}
      true -> :ok
    end
  end

  defp fetch_required(params, key) do
    case params[key] do
      nil -> {:error, 400, "#{key} is required"}
      "" -> {:error, 400, "#{key} is required"}
      value -> {:ok, value}
    end
  end

  # The spec is deliberately NOT included in list responses. It is the largest
  # field by far and the door list only needs names and metadata; sending a
  # hundred specs to render a menu would be wasteful. `show` returns it.
  defp sim_json(sim, viewer_id) do
    %{
      id: sim.id,
      name: sim.name,
      description: sim.description,
      visibility: sim.visibility,
      kind: sim.kind,
      template_id: sim.template_id,
      is_published: sim.is_published,
      is_locked: sim.is_locked,
      is_owner: sim.owner_user_id == viewer_id,
      visitors_can_build: sim.visitors_can_build,
      owner_user_id: sim.owner_user_id,
      last_launched_at: sim.last_launched_at,
      launch_count: sim.launch_count,
      inserted_at: sim.inserted_at,
      updated_at: sim.updated_at
    }
  end

  defp members_json(sim_id) do
    Enum.map(HoloSims.list_members(sim_id), &member_json/1)
  end

  defp member_json(member) do
    %{
      user_id: member.user_id,
      role: member.role,
      invited_by_user_id: member.invited_by_user_id,
      invited_at: member.invited_at,
      accepted_at: member.accepted_at
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp error(conn, status, message) do
    conn |> put_status(status) |> json(%{success: false, message: message})
  end
end
