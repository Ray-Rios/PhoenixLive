defmodule PhoenixAppWeb.Api.GamesController do
  @moduledoc """
  Generic multiplayer game data API - `/api/games/:game_slug/characters`.

  Reusable across RaysSpaceSim and future titles. A request is authorized
  either as the player themselves (Guardian bearer token) or as a trusted
  dedicated game server (`X-API-Key: GAMES_SERVER_API_KEY`, must pass
  `user_id` explicitly since there's no session in that mode).
  """

  use PhoenixAppWeb, :controller
  alias PhoenixApp.Games

  plug PhoenixAppWeb.Plugs.GamesApiKeyOrAuth

  # GET /api/games/:game_slug/characters
  def list_characters(conn, %{"game_slug" => slug} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params) do
      characters = Games.list_characters(game.id, user_id)
      json(conn, %{success: true, characters: Enum.map(characters, &character_json/1)})
    else
      {:error, status, message} -> error_response(conn, status, message)
    end
  end

  # POST /api/games/:game_slug/characters
  def create_character(conn, %{"game_slug" => slug} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params) do
      attrs = %{
        "game_id" => game.id,
        "user_id" => user_id,
        "name" => params["name"],
        "stats" => params["stats"] || %{},
        "settings" => params["settings"] || %{}
      }

      case Games.create_character(attrs) do
        {:ok, character} ->
          conn
          |> put_status(:created)
          |> json(%{success: true, character: character_json(character)})

        {:error, changeset} ->
          error_response(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error_response(conn, status, message)
    end
  end

  # GET /api/games/:game_slug/characters/:id
  def get_character(conn, %{"game_slug" => slug, "id" => id} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params),
         %Games.GameCharacter{} = character <- Games.get_owned_character(game.id, user_id, id) do
      json(conn, %{success: true, character: character_json(character)})
    else
      {:error, status, message} -> error_response(conn, status, message)
      nil -> error_response(conn, 404, "Character not found")
    end
  end

  # PUT /api/games/:game_slug/characters/:id
  def update_character(conn, %{"game_slug" => slug, "id" => id} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params),
         %Games.GameCharacter{} = character <- Games.get_owned_character(game.id, user_id, id) do
      attrs =
        %{}
        |> maybe_put("name", params["name"])
        |> maybe_put("stats", params["stats"])
        |> maybe_put("settings", params["settings"])
        |> Map.put("last_played_at", DateTime.utc_now() |> DateTime.truncate(:second))

      case Games.update_character(character, attrs) do
        {:ok, updated} -> json(conn, %{success: true, character: character_json(updated)})
        {:error, changeset} -> error_response(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error_response(conn, status, message)
      nil -> error_response(conn, 404, "Character not found")
    end
  end

  # DELETE /api/games/:game_slug/characters/:id
  def delete_character(conn, %{"game_slug" => slug, "id" => id} = params) do
    with {:ok, game} <- fetch_game(slug),
         {:ok, user_id} <- resolve_user_id(conn, params),
         %Games.GameCharacter{} = character <- Games.get_owned_character(game.id, user_id, id) do
      {:ok, _} = Games.delete_character(character)
      json(conn, %{success: true})
    else
      {:error, status, message} -> error_response(conn, status, message)
      nil -> error_response(conn, 404, "Character not found")
    end
  end

  # ---------------------------------------------------------------------
  # Server registry
  # ---------------------------------------------------------------------

  # GET /api/games/:game_slug/servers
  #
  # Readable by any authenticated player. Returns only servers with a recent
  # heartbeat and free capacity, least-loaded first, so a client that just
  # takes the head of the list gets a sensible answer.
  def list_servers(conn, %{"game_slug" => slug} = params) do
    with {:ok, game} <- fetch_game(slug) do
      opts =
        []
        |> maybe_opt(:region, params["region"])
        |> maybe_opt(:version, params["version"])
        |> Keyword.put(:include_full, params["include_full"] == "true")

      servers = Games.list_available_servers(game.id, opts)

      json(conn, %{
        success: true,
        servers: Enum.map(servers, &server_json/1),
        recommended: servers |> List.first() |> server_json()
      })
    else
      {:error, status, message} -> error_response(conn, status, message)
    end
  end

  # POST /api/games/:game_slug/servers/heartbeat
  #
  # Server API key ONLY. A player token must never be able to write here: a
  # forged registration would advertise an attacker-controlled server to every
  # player browsing the list, which is phishing rather than cheating.
  def heartbeat_server(conn, %{"game_slug" => slug} = params) do
    with :ok <- require_server_auth(conn),
         {:ok, game} <- fetch_game(slug),
         {:ok, host} <- fetch_required(params, "host"),
         {:ok, port} <- fetch_required(params, "port") do
      attrs = %{
        "game_id" => game.id,
        "host" => host,
        "port" => port,
        "name" => params["name"] || "#{host}:#{port}",
        "region" => params["region"] || "unknown",
        "status" => params["status"] || "online",
        "current_players" => params["current_players"] || 0,
        "max_players" => params["max_players"] || 64,
        "map_name" => params["map_name"],
        "version" => params["version"],
        "metadata" => params["metadata"] || %{}
      }

      case Games.register_server(attrs) do
        {:ok, server} -> json(conn, %{success: true, server: server_json(server)})
        {:error, changeset} -> error_response(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error_response(conn, status, message)
    end
  end

  # POST /api/games/:game_slug/servers/offline - graceful shutdown.
  def deregister_server(conn, %{"game_slug" => slug} = params) do
    with :ok <- require_server_auth(conn),
         {:ok, game} <- fetch_game(slug),
         {:ok, host} <- fetch_required(params, "host"),
         {:ok, port} <- fetch_required(params, "port") do
      case Games.mark_server_offline(game.id, host, port) do
        {:ok, server} -> json(conn, %{success: true, server: server_json(server)})
        {:error, :not_found} -> error_response(conn, 404, "Server not registered")
        {:error, changeset} -> error_response(conn, 422, changeset_errors(changeset))
      end
    else
      {:error, status, message} -> error_response(conn, status, message)
    end
  end

  # ---------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------

  defp require_server_auth(conn) do
    case conn.assigns[:games_auth_mode] do
      :server_api_key -> :ok
      _ -> {:error, 403, "This endpoint requires a server API key"}
    end
  end

  defp fetch_required(params, key) do
    case params[key] do
      nil -> {:error, 400, "#{key} is required"}
      "" -> {:error, 400, "#{key} is required"}
      value -> {:ok, value}
    end
  end

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, _key, ""), do: opts
  defp maybe_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp server_json(nil), do: nil

  defp server_json(server) do
    %{
      id: server.id,
      name: server.name,
      host: server.host,
      port: server.port,
      address: "#{server.host}:#{server.port}",
      region: server.region,
      status: server.status,
      current_players: server.current_players,
      max_players: server.max_players,
      map_name: server.map_name,
      version: server.version,
      last_heartbeat_at: server.last_heartbeat_at,
      metadata: server.metadata
    }
  end

  defp fetch_game(slug) do
    case Games.get_game_by_slug(slug) do
      nil -> {:error, 404, "Unknown game: #{slug}"}
      game -> if game.is_active, do: {:ok, game}, else: {:error, 403, "Game is not active"}
    end
  end

  # Player token mode: user_id comes from the authenticated resource.
  # Server API key mode: user_id must be supplied explicitly by the trusted server.
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp character_json(character) do
    %{
      id: character.id,
      game_id: character.game_id,
      name: character.name,
      stats: character.stats,
      settings: character.settings,
      last_played_at: character.last_played_at,
      inserted_at: character.inserted_at,
      updated_at: character.updated_at
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp error_response(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{success: false, message: message})
  end
end
