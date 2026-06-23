defmodule PhoenixAppWeb.DesktopLive do
  @moduledoc """
  Character creation and login hub hosted on the desktop route.
  """
  use PhoenixAppWeb, :live_view
  require Logger
  alias PhoenixApp.Game
  alias Phoenix.PubSub
  alias PhoenixAppWeb.Presence

  @max_move_speed 30.0
  @interest_radius 2000.0
  @chat_radius 64.0
  @collision_radius 1.1
  @min_dt_seconds 0.04
  @position_persist_interval_ms 1000
  @presence_broadcast_interval_ms 100
  @remote_position_broadcast_interval_ms 100

  on_mount {PhoenixAppWeb.UserAuth, :require_authenticated_user}

  def handle_params(%{"ch" => character_id}, _uri, socket) do
    if connected?(socket) do
      case Game.character_login_payload(socket.assigns.current_user.id, character_id) do
        {:ok, payload} ->
          socket = socket |> leave_zone_presence() |> join_zone_presence(payload)

          {:noreply,
           socket
           |> assign(
             current_character_payload: payload,
             current_character_runtime: payload,
             world_mode?: true,
             last_world_update_ms: System.monotonic_time(:millisecond)
           )
           |> push_event("zone_presence_state", %{online_characters: socket.assigns.zone_online_characters})
           |> push_event("character_login_ready", payload)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    if socket.assigns.world_mode? do
      socket =
        socket
        |> leave_world()
        |> push_event("zone_presence_state", %{online_characters: []})
        |> push_event("world_logged_out", %{})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    characters = Game.list_user_characters(current_user.id)
    available_models = Game.list_models()

    {:ok,
     assign(socket,
       page_title: "Character Hub",
       characters: characters,
       selected_character_id: nil,
       current_character_payload: nil,
      current_character_runtime: nil,
       world_mode?: false,
       has_characters?: characters != [],
       scene_characters: to_scene_characters(characters),
       current_zone_topic: nil,
      current_presence_key: nil,
       zone_online_characters: [],
       last_world_update_ms: nil,
      last_position_persist_ms: nil,
      last_presence_update_ms: nil,
      last_remote_broadcast_ms: nil,
       scene_model_paths: Enum.map(available_models, & &1.model_path),
        available_models: available_models,
       create_form: to_form(%{"name" => "", "character_type" => "", "model_path" => ""}, as: "character")
     )}
  end

  def handle_event("validate_character", %{"character" => params}, socket) do
    {:noreply, assign(socket, create_form: to_form(params, as: "character"))}
  end

  def handle_event("create_character", %{"character" => params}, socket) do
    Logger.info("desktop_live:create_character user_id=#{socket.assigns.current_user.id} name=#{inspect(params["name"])} type=#{inspect(params["character_type"])} model=#{inspect(params["model_path"])}")

    case Game.create_character(socket.assigns.current_user.id, params) do
      {:ok, _character} ->
        characters = Game.list_user_characters(socket.assigns.current_user.id)
        Logger.info("desktop_live:create_character success user_id=#{socket.assigns.current_user.id} character_count=#{length(characters)}")

        {:noreply,
         socket
         |> assign(
           characters: characters,
           has_characters?: true,
           scene_characters: to_scene_characters(characters),
           create_form: to_form(%{"name" => "", "character_type" => "", "model_path" => ""}, as: "character")
         )
         |> put_flash(:info, "Character created and approved.")}

      {:error, :character_limit_reached} ->
        Logger.warning("desktop_live:create_character limit_reached user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "You already have the maximum of 16 characters.")}

      {:error, :invalid_model_path} ->
        Logger.warning("desktop_live:create_character invalid_model user_id=#{socket.assigns.current_user.id} model=#{inspect(params["model_path"])}")
        {:noreply, put_flash(socket, :error, "Selected model is not valid.")}

      {:error, :default_zone_missing} ->
        Logger.error("desktop_live:create_character missing_default_zone user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "Lobby zone is missing. Please run migrations/seeds.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("desktop_live:create_character changeset_error user_id=#{socket.assigns.current_user.id} errors=#{inspect(changeset.errors)}")
        {:noreply,
         socket
         |> assign(create_form: to_form(changeset, as: "character"))
         |> put_flash(:error, "Please fix the highlighted character fields.")}
    end
  end

  def handle_event("select_character", %{"character_id" => character_id}, socket) do
    character = Game.get_character_for_user(socket.assigns.current_user.id, character_id)

    if character do
      Logger.info("desktop_live:select_character user_id=#{socket.assigns.current_user.id} character_id=#{character.id} name=#{character.name}")
      {:noreply, assign(socket, selected_character_id: character.id, scene_characters: to_scene_characters(socket.assigns.characters))}
    else
      Logger.warning("desktop_live:select_character not_found user_id=#{socket.assigns.current_user.id} character_id=#{character_id}")
      {:noreply, put_flash(socket, :error, "Could not select that character.")}
    end
  end

  def handle_event("three_ui_creator_focus", _params, socket) do
    {:noreply, put_flash(socket, :info, "Use the creation form below to make a character.")}
  end

  def handle_event("three_ui_create_character", params, socket) do
    normalized_params = normalize_three_ui_create_params(params, socket.assigns.scene_model_paths)
    Logger.info("desktop_live:three_ui_create_character user_id=#{socket.assigns.current_user.id} params=#{inspect(normalized_params)}")

    case Game.create_character(socket.assigns.current_user.id, normalized_params) do
      {:ok, _character} ->
        characters = Game.list_user_characters(socket.assigns.current_user.id)
        Logger.info("desktop_live:three_ui_create_character success user_id=#{socket.assigns.current_user.id} character_count=#{length(characters)}")

        {:noreply,
         socket
         |> assign(
           characters: characters,
           has_characters?: true,
           scene_characters: to_scene_characters(characters),
           create_form: to_form(%{"name" => "", "character_type" => "", "model_path" => ""}, as: "character")
         )
         |> put_flash(:info, "Character created from 3D interface.")}

      {:error, :character_limit_reached} ->
        Logger.warning("desktop_live:three_ui_create_character limit_reached user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "You already have the maximum of 16 characters.")}

      {:error, :invalid_model_path} ->
        Logger.warning("desktop_live:three_ui_create_character invalid_model user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "3D selection used an invalid model.")}

      {:error, %Ecto.Changeset{} = _changeset} ->
        Logger.warning("desktop_live:three_ui_create_character invalid_input user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "3D create input is invalid. Use name/type at least 2 characters.")}

      {:error, :default_zone_missing} ->
        Logger.error("desktop_live:three_ui_create_character missing_default_zone user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "Lobby zone is missing. Please run migrations/seeds.")}
    end
  end

  def handle_event("login_character", _params, socket) do
    selected_character_id = socket.assigns.selected_character_id
    Logger.info("desktop_live:login_character user_id=#{socket.assigns.current_user.id} selected_character_id=#{inspect(selected_character_id)}")

    case selected_character_id && Game.character_login_payload(socket.assigns.current_user.id, selected_character_id) do
      {:ok, payload} ->
        socket = socket |> leave_zone_presence() |> join_zone_presence(payload)
        Logger.info("desktop_live:login_character success user_id=#{socket.assigns.current_user.id} character_id=#{payload.character_id} zone=#{payload.zone.slug}")

        {:noreply,
         socket
         |> assign(
           current_character_payload: payload,
           current_character_runtime: payload,
           world_mode?: true,
           last_world_update_ms: System.monotonic_time(:millisecond)
         )
         |> push_event("zone_presence_state", %{online_characters: socket.assigns.zone_online_characters})
         |> push_event("character_login_ready", payload)
         |> push_patch(to: ~p"/desktop?ch=#{payload.character_id}")}

      _ ->
        Logger.warning("desktop_live:login_character missing_selection user_id=#{socket.assigns.current_user.id}")
        {:noreply, put_flash(socket, :error, "Select a character before logging in.")}
    end
  end

  def handle_event("logout_character", _params, socket) do
    {:noreply,
     socket
     |> leave_world()
     |> push_event("zone_presence_state", %{online_characters: []})
     |> push_event("world_logged_out", %{})
     |> push_patch(to: ~p"/desktop")}
  end

  def handle_event("delete_character", %{"character_id" => character_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Game.delete_character_for_user(user_id, character_id) do
      {:ok, character} ->
        characters = Game.list_user_characters(user_id)
        selected_character_id = if socket.assigns.selected_character_id == character.id, do: nil, else: socket.assigns.selected_character_id

        Logger.info("desktop_live:delete_character success user_id=#{user_id} character_id=#{character.id} remaining=#{length(characters)}")

        {:noreply,
         socket
         |> assign(
           characters: characters,
           selected_character_id: selected_character_id,
           has_characters?: characters != [],
           scene_characters: to_scene_characters(characters)
         )
         |> put_flash(:info, "Character deleted.")}

      {:error, :not_found} ->
        Logger.warning("desktop_live:delete_character not_found user_id=#{user_id} character_id=#{character_id}")
        {:noreply, put_flash(socket, :error, "Character not found.")}

      {:error, reason} ->
        Logger.warning("desktop_live:delete_character failed user_id=#{user_id} character_id=#{character_id} reason=#{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Could not delete character.")}
    end
  end

  def handle_event("toggle_calendar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_start_menu", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("open_app", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("world_position_update", params, socket) do
    with %{"x" => raw_x, "y" => raw_y, "z" => raw_z, "heading" => raw_heading} <- stringify_keys(params),
         {:ok, x} <- to_float(raw_x),
         {:ok, y} <- to_float(raw_y),
         {:ok, z} <- to_float(raw_z),
         {:ok, heading} <- to_float(raw_heading),
         %{} = current_character <- current_character(socket),
         :ok <- validate_ground_bounds(y),
         :ok <- validate_move_speed(socket, current_character.position, x, y, z),
         :ok <- validate_player_collision(socket.assigns.zone_online_characters || [], current_character.character_id, x, z) do
      topic = socket.assigns.current_zone_topic
      now_ms = System.monotonic_time(:millisecond)

      last_presence_ms = socket.assigns.last_presence_update_ms || (now_ms - @presence_broadcast_interval_ms - 1)
      should_broadcast = not is_nil(topic) and now_ms - last_presence_ms >= @presence_broadcast_interval_ms

      if should_broadcast do
        presence_updated_at = System.system_time(:millisecond)

        Presence.update(self(), topic, current_character.character_id, fn meta ->
          Map.merge(meta, %{x: x, y: y, z: z, heading: heading, updated_at: presence_updated_at})
        end)
      end

      if not is_nil(topic) do
        PubSub.broadcast(PhoenixApp.PubSub, topic, {:zone_position_update, %{
          character_id: current_character.character_id,
          character_name: current_character.name,
          character_type: current_character.character_type,
          model_path: current_character.model_path,
          user_id: socket.assigns.current_user.id,
          x: x,
          y: y,
          z: z,
          heading: heading
        }})
      end

      last_persist_ms = socket.assigns.last_position_persist_ms || (now_ms - @position_persist_interval_ms - 1)
      should_persist = now_ms - last_persist_ms >= @position_persist_interval_ms

      if should_persist do
        persist_character_position_async(socket.assigns.current_user.id, current_character, x, y, z, heading)
      end

      {:noreply,
       assign(socket,
         current_character_runtime:
           Map.put(current_character, :position, %{
             x: x,
             y: y,
             z: z,
             heading: heading
           }),
         last_world_update_ms: now_ms,
         last_presence_update_ms: if(should_broadcast, do: now_ms, else: last_presence_ms),
         last_position_persist_ms: if(should_persist, do: now_ms, else: last_persist_ms)
       )}
    else
      {:error, :invalid_move} ->
        Logger.warning("desktop_live:world_position_update_REJECTED invalid_move character_id=#{inspect(current_character(socket) && current_character(socket).character_id)}")
        {:noreply, push_authoritative_correction(socket)}

      other ->
        Logger.warning("desktop_live:world_position_update_REJECTED other=#{inspect(other)} character_id=#{inspect(current_character(socket) && current_character(socket).character_id)}")
        {:noreply, socket}
    end
  end

  def handle_event("world_chat_message", %{"message" => raw_message}, socket) do
    message = raw_message |> to_string() |> String.trim()

    cond do
      message == "" ->
        {:noreply, socket}

      String.length(message) > 220 ->
        {:noreply, put_flash(socket, :error, "Chat message is too long.")}

      is_nil(socket.assigns.current_zone_topic) or is_nil(current_character(socket)) ->
        {:noreply, socket}

      true ->
        current = current_character(socket)

        payload = %{
          character_id: current.character_id,
          character_name: current.name,
          message: message,
          x: current.position.x,
          y: current.position.y,
          z: current.position.z,
          sent_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        PubSub.broadcast(PhoenixApp.PubSub, socket.assigns.current_zone_topic, {:zone_chat_message, payload})
        {:noreply, socket}
    end
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    case socket.assigns.current_zone_topic do
      nil ->
        {:noreply, socket}

      topic ->
        zone_online_characters =
          topic
          |> list_zone_online_characters()
          |> visible_zone_online_characters(current_character(socket))

        {:noreply,
         socket
         |> assign(zone_online_characters: zone_online_characters)
         |> push_event("zone_presence_state", %{online_characters: zone_online_characters})}
    end
  end

  def handle_info({:zone_chat_message, payload}, socket) do
    if within_chat_radius?(socket, payload) do
      {:noreply, push_event(socket, "zone_chat_message", payload)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:zone_position_update, payload}, socket) do
    current = current_character(socket)

    cond do
      is_nil(current) ->
        {:noreply, socket}

      payload.character_id == current.character_id ->
        {:noreply, socket}

      true ->
        {:noreply, push_event(socket, "zone_position_update", payload)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    _socket = leave_zone_presence(socket)
    :ok
  end

  defp join_zone_presence(socket, payload) do
    zone_id = payload.zone.id
    topic = "presence:zone:#{zone_id}"

    presence_key = payload.character_id

    if connected?(socket) do
      if socket.assigns.current_zone_topic do
        previous_topic = socket.assigns.current_zone_topic
        PubSub.unsubscribe(PhoenixApp.PubSub, previous_topic)
        if socket.assigns.current_presence_key do
          Presence.untrack(self(), previous_topic, socket.assigns.current_presence_key)
        end

        # Cleanup legacy presence keys from earlier versions that tracked by user_id.
        Presence.untrack(self(), previous_topic, socket.assigns.current_user.id)
      end

      PubSub.subscribe(PhoenixApp.PubSub, topic)

      Presence.track(self(), topic, presence_key, %{
        user_id: socket.assigns.current_user.id,
        character_id: payload.character_id,
        character_name: payload.name,
        character_type: payload.character_type,
        model_path: payload.model_path,
        x: payload.position.x,
        y: payload.position.y,
        z: payload.position.z,
        heading: payload.position.heading,
        updated_at: System.system_time(:millisecond),
        joined_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      Logger.info("desktop_live:join_zone_presence user_id=#{socket.assigns.current_user.id} character_id=#{payload.character_id} topic=#{topic}")

    end

    socket = assign(socket, current_presence_key: presence_key)

    zone_online_characters =
      topic
      |> list_zone_online_characters()
      |> visible_zone_online_characters(payload)

    assign(socket, current_zone_topic: topic, zone_online_characters: zone_online_characters)

  end

  defp leave_zone_presence(socket) do
    case socket.assigns.current_zone_topic do
      nil ->
        socket

      topic ->
        if socket.assigns.current_presence_key do
          Presence.untrack(self(), topic, socket.assigns.current_presence_key)
        end

        PubSub.unsubscribe(PhoenixApp.PubSub, topic)
        socket
    end
  end

  defp leave_world(socket) do
    socket
    |> leave_zone_presence()
    |> assign(
      world_mode?: false,
      current_character_payload: nil,
      current_character_runtime: nil,
      current_zone_topic: nil,
      current_presence_key: nil,
      zone_online_characters: [],
      last_world_update_ms: nil,
      last_presence_update_ms: nil,
      last_remote_broadcast_ms: nil,
      last_position_persist_ms: nil
    )
  end

  defp list_zone_online_characters(topic) do
    topic
    |> Presence.list()
    |> Enum.flat_map(fn {_key, %{metas: metas}} -> metas end)
    |> Enum.reject(&is_nil(&1[:character_id]))
    |> Enum.reduce(%{}, fn meta, acc ->
      character_id = meta[:character_id]

      case Map.get(acc, character_id) do
        nil ->
          Map.put(acc, character_id, meta)

        existing_meta ->
          if presence_meta_updated_at(meta) >= presence_meta_updated_at(existing_meta) do
            Map.put(acc, character_id, meta)
          else
            acc
          end
      end
    end)
    |> Map.values()
    |> Enum.map(fn meta ->
      %{
        character_id: meta[:character_id],
        character_name: meta[:character_name],
        character_type: meta[:character_type],
        model_path: meta[:model_path],
        user_id: meta[:user_id],
        x: meta[:x] || 0.0,
        y: meta[:y] || 0.0,
        z: meta[:z] || 0.0,
        heading: meta[:heading] || 0.0
      }
    end)
  end

  defp presence_meta_updated_at(meta), do: meta[:updated_at] || 0

  defp visible_zone_online_characters(characters, nil), do: characters

  defp visible_zone_online_characters(characters, current_character_payload) do
    cx = current_character_payload.position.x || 0.0
    cz = current_character_payload.position.z || 0.0

    Enum.filter(characters, fn character ->
      dx = (character.x || 0.0) - cx
      dz = (character.z || 0.0) - cz
      :math.sqrt(dx * dx + dz * dz) <= @interest_radius
    end)
  end

  defp within_interest_radius?(current_character_payload, position_payload) do
    cx = current_character_payload.position.x || 0.0
    cz = current_character_payload.position.z || 0.0

    dx = (position_payload.x || 0.0) - cx
    dz = (position_payload.z || 0.0) - cz

    :math.sqrt(dx * dx + dz * dz) <= @interest_radius
  end

  defp validate_ground_bounds(y) do
    if y < -1.0 or y > 25.0, do: {:error, :invalid_move}, else: :ok
  end

  defp validate_move_speed(socket, current_position, x, y, z) do
    last_ms = socket.assigns.last_world_update_ms || System.monotonic_time(:millisecond)
    now_ms = System.monotonic_time(:millisecond)
    dt = max((now_ms - last_ms) / 1000.0, @min_dt_seconds)

    dx = x - (current_position.x || 0.0)
    dy = y - (current_position.y || 0.0)
    dz = z - (current_position.z || 0.0)

    speed = :math.sqrt(dx * dx + dy * dy + dz * dz) / dt

    if speed > @max_move_speed, do: {:error, :invalid_move}, else: :ok
  end

  defp validate_player_collision(online_characters, character_id, x, z) do
    blocked? =
      online_characters
      |> Enum.reject(&(&1.character_id == character_id))
      |> Enum.any?(fn other ->
        dx = (other.x || 0.0) - x
        dz = (other.z || 0.0) - z
        :math.sqrt(dx * dx + dz * dz) < @collision_radius
      end)

    if blocked?, do: {:error, :invalid_move}, else: :ok
  end

  defp push_authoritative_correction(socket) do
    current = current_character(socket)

    if current do
      push_event(socket, "world_position_corrected", %{
        x: current.position.x,
        y: current.position.y,
        z: current.position.z,
        heading: current.position.heading
      })
    else
      socket
    end
  end

  defp persist_character_position_async(user_id, current_character, x, y, z, heading) do
    Task.start(fn ->
      case Game.update_character_spawn(user_id, current_character.character_id, %{
             "last_zone_id" => current_character.zone.id,
             "last_x" => x,
             "last_y" => y,
             "last_z" => z,
             "last_heading" => heading
           }) do
        {:ok, _character} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "desktop_live:world_position_persist_failed user_id=#{user_id} character_id=#{current_character.character_id} reason=#{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  defp within_chat_radius?(socket, payload) do
    case current_character(socket) do
      nil ->
        false

      current ->
        dx = (payload[:x] || payload["x"] || 0.0) - (current.position.x || 0.0)
        dz = (payload[:z] || payload["z"] || 0.0) - (current.position.z || 0.0)
        :math.sqrt(dx * dx + dz * dz) <= @chat_radius
    end
  end

  defp current_character(socket) do
    socket.assigns.current_character_runtime || socket.assigns.current_character_payload
  end

  defp to_float(value) when is_float(value), do: {:ok, value}
  defp to_float(value) when is_integer(value), do: {:ok, value * 1.0}

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _rest} -> {:ok, parsed}
      :error -> {:error, :invalid_move}
    end
  end

  defp to_float(_value), do: {:error, :invalid_move}

  defp to_scene_characters(characters) do
    Enum.map(characters, fn character ->
      %{
        id: character.id,
        name: character.name,
        character_type: character.character_type
      }
    end)
  end

  defp scene_state(assigns) do
    cond do
      assigns.world_mode? and assigns.current_character_payload != nil -> "world"
      !assigns.has_characters? -> "intro"
      is_nil(assigns.selected_character_id) -> "selection"
      true -> "ready"
    end
  end

  defp stringify_keys(params) do
    Map.new(params, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end

  defp normalize_three_ui_create_params(params, available_model_paths) do
    name =
      params
      |> Map.get("name", Map.get(params, :name, ""))
      |> to_string()
      |> String.trim()

    character_type =
      params
      |> Map.get("character_type", Map.get(params, :character_type, ""))
      |> to_string()
      |> String.trim()

    model_path =
      params
      |> Map.get("model_path", Map.get(params, :model_path, ""))
      |> to_string()
      |> String.trim()

    fallback_name = "Traveler#{System.unique_integer([:positive]) |> Integer.to_string() |> String.slice(-6, 6)}"
    fallback_type = "AA"
    fallback_model = List.first(available_model_paths) || ""

    %{
      "name" => if(String.length(name) >= 2, do: name, else: fallback_name),
      "character_type" => if(String.length(character_type) >= 2, do: character_type, else: fallback_type),
      "model_path" => if(model_path != "", do: model_path, else: fallback_model)
    }
  end
  
  def render(assigns) do
    ~H"""
    <div class="fixed top-[30px] inset-x-0 bottom-0 z-40 overflow-hidden">
        <div
          id="desktop-character-scene"
          class="absolute inset-0 w-full h-full"
          phx-hook="DesktopCharacterUIScene"
          data-ui-state={scene_state(assigns)}
          data-selected-character-id={@selected_character_id}
          data-can-login={to_string(!is_nil(@selected_character_id))}
          data-characters={Jason.encode!(@scene_characters)}
          data-model-paths={Jason.encode!(@scene_model_paths)}
          data-available-models={Jason.encode!(@available_models)}
          data-current-player={Jason.encode!(@current_character_payload)}
          phx-update="ignore"
        ></div>

    </div>
    """
  end
end