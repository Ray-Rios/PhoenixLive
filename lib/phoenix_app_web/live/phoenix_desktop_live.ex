defmodule PhoenixAppWeb.PhoenixDesktopLive do
  @moduledoc """
  Global Phoenix Desktop environment (taskbar + windows).
  
  This LiveComponent provides a persistent desktop environment with taskbar and windows.
  """
  use PhoenixAppWeb, :live_component
  alias Phoenix.PubSub

  def update(assigns, socket) do
    # Subscribe to desktop updates for real-time collaboration
    if connected?(socket) do
      PubSub.subscribe(PhoenixApp.PubSub, "desktop:public")
      
      # Subscribe to user-specific invite notifications
      if assigns[:current_user] do
        PubSub.subscribe(PhoenixApp.PubSub, "user:#{assigns.current_user.id}:invites")
      end
    end
    
    # Load pending invites count for notification badge
    pending_invite_count = if assigns[:current_user] do
      PhoenixApp.Forum.count_pending_invites(assigns.current_user.id)
    else
      0
    end
    
    # TEMPORARILY DISABLED: Window persistence causing database errors
    # Restore saved windows on mount
    # windows = if socket.assigns[:windows] do
    #   socket.assigns.windows
    # else
    #   restore_saved_windows(assigns[:current_user])
    # end
    
    socket = socket
    |> assign(assigns)
    |> assign_new(:windows, fn -> [] end)
    |> assign_new(:next_z_index, fn -> 1 end)
    |> assign_new(:show_start_menu, fn -> false end)
    |> assign_new(:show_notifications, fn -> false end)
    |> assign_new(:show_audio_panel, fn -> false end)
    |> assign_new(:show_calendar, fn -> false end)
    |> assign_new(:calendar_notes, fn -> 
       if assigns[:current_user] do
         try do
           PhoenixApp.Calendar.list_notes(assigns.current_user.id)
           |> Map.new(fn note -> {Date.to_string(note.date), note.content} end)
         rescue
           _ -> %{}
         end
       else
         %{}
       end
    end)
    |> assign_new(:selected_date, fn -> nil end)
    |> assign_new(:pending_invites, fn -> [] end)
    |> assign(:pending_invite_count, pending_invite_count)
    |> assign_new(:taskbar_visible, fn -> true end)
    |> allow_upload(:files, 
         accept: :any, 
         max_entries: 5, 
         max_file_size: get_max_file_size(assigns[:current_user]),
         auto_upload: true,
         progress: &handle_progress/3
       )
    |> allow_upload(:calendar_attachment,
         accept: :any,
         max_entries: 5,
         max_file_size: 50_000_000,
         auto_upload: false
       )

    {:ok, socket}
  end

  defp handle_progress(:files, entry, socket) do
    if entry.done? do
      window_id = socket.assigns[:upload_window_id]
      if window_id do
        window = Enum.find(socket.assigns.windows, &(&1.id == window_id))
        if window do
          dest_path = get_real_path(window.current_path, socket.assigns.current_user)
          
          # Check quota if uploading to user drive
          quota_ok = cond do
            String.starts_with?(window.current_path, "root://") ->
              socket.assigns.current_user.role in ["admin", "gm"]
            
            String.starts_with?(window.current_path, "user://") ->
              check_quota(socket.assigns.current_user, entry.client_size) == :ok
            
            true ->
              true # Public drive has no quota? Or maybe it should. For now assume public is free.
          end

          if quota_ok do
            consume_uploaded_entries(socket, :files, fn %{path: path}, _entry ->
              dest = Path.join(dest_path, entry.client_name)
              File.cp!(path, dest)
              {:ok, dest}
            end)
            
            send(self(), {:refresh_window, window_id})
          end
        end
      end
    end
    {:noreply, socket}
  end

  defp get_max_file_size(user) do
    case user do
      nil -> 0
      %{role: "admin"} -> 1_000_000_000 # 1GB
      %{role: "editor"} -> 50_000_000 # 50MB
      _ -> 20_000_000 # 20MB (Member)
    end
  end

  # ==================== EVENT HANDLERS ====================

  def handle_event("toggle_start_menu", _params, socket) do
    {:noreply, assign(socket, show_start_menu: !socket.assigns.show_start_menu, show_notifications: false, show_audio_panel: false, show_calendar: false)}
  end

  def handle_event("toggle_notifications", _params, socket) do
    # Load fresh invites when opening panel
    {show_notifications, pending_invites} = if !socket.assigns.show_notifications && socket.assigns.current_user do
      invites = PhoenixApp.Forum.list_pending_invites_for_user(socket.assigns.current_user.id)
      {true, invites}
    else
      {false, []}
    end
    
    {:noreply, assign(socket, show_notifications: show_notifications, pending_invites: pending_invites, show_audio_panel: false, show_calendar: false)}
  end

  def handle_event("toggle_audio_panel", _params, socket) do
    {:noreply, assign(socket, show_audio_panel: !socket.assigns.show_audio_panel, show_notifications: false, show_start_menu: false, show_calendar: false)}
  end

  def handle_event("toggle_calendar", _params, socket) do
    {:noreply, assign(socket, show_calendar: !socket.assigns.show_calendar, show_notifications: false, show_start_menu: false, show_audio_panel: false, selected_date: nil)}
  end

  def handle_event("select_date", %{"day" => day}, socket) do
    # Construct date string YYYY-MM-DD
    today = Date.utc_today()
    date_str = "#{today.year}-#{String.pad_leading(to_string(today.month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")}"
    
    {:noreply, assign(socket, selected_date: date_str)}
  end

  def handle_event("save_note", %{"note" => note}, socket) do
    if socket.assigns.selected_date && socket.assigns.current_user do
      date = Date.from_iso8601!(socket.assigns.selected_date)
      
      # Handle uploads
      uploaded_files = consume_uploaded_entries(socket, :calendar_attachment, fn %{path: path}, entry ->
        # Save to user's drive (user://uploads/)
        user_upload_path = get_real_path("user://uploads/", socket.assigns.current_user)
        if !File.exists?(user_upload_path), do: File.mkdir_p!(user_upload_path)
        
        dest = Path.join(user_upload_path, entry.client_name)
        File.cp!(path, dest)
        {:ok, entry.client_name}
      end)
      
      # Append uploaded filenames to note
      updated_note = if Enum.empty?(uploaded_files) do
        note
      else
        files_list = Enum.map(uploaded_files, fn name -> "- [File] #{name}" end) |> Enum.join("\n")
        if note == "", do: "Attachments:\n" <> files_list, else: note <> "\n\nAttachments:\n" <> files_list
      end

      # Save to DB
      PhoenixApp.Calendar.save_note(socket.assigns.current_user.id, date, updated_note)
      
      notes = Map.put(socket.assigns.calendar_notes, socket.assigns.selected_date, updated_note)
      {:noreply, assign(socket, calendar_notes: notes, selected_date: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_note_input", _params, socket) do
    {:noreply, assign(socket, selected_date: nil)}
  end

  def handle_event("toggle_notification_sound", _params, socket) do
    if socket.assigns.current_user do
      new_value = !socket.assigns.current_user.notification_sound_enabled
      
      case PhoenixApp.Accounts.update_audio_preferences(socket.assigns.current_user, %{notification_sound_enabled: new_value}) do
        {:ok, updated_user} ->
          {:noreply, assign(socket, current_user: updated_user)}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update audio preferences")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_volume", %{"volume" => volume_str}, socket) do
    if socket.assigns.current_user do
      volume = String.to_float(volume_str) / 100.0
      
      case PhoenixApp.Accounts.update_audio_preferences(socket.assigns.current_user, %{master_volume: volume}) do
        {:ok, updated_user} ->
          {:noreply, 
           socket
           |> assign(current_user: updated_user)
           |> push_event("volume_changed", %{volume: volume})}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update volume")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("test_sound", _params, socket) do
    if socket.assigns.current_user do
      volume = socket.assigns.current_user.master_volume || 0.5
      sound_path = "/uploads/public/audio/Blaster Master SFX (3).wav"
      {:noreply, push_event(socket, "play_sound", %{path: sound_path, volume: volume})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("accept_invite", %{"invite_id" => invite_id}, socket) do
    require Logger
    Logger.info("Desktop: accept_invite called invite_id=#{invite_id} user=#{socket.assigns.current_user && socket.assigns.current_user.id}")
    require Logger
    # invite_id is a UUID string, keep it as-is
    Logger.info("Accepting invite #{invite_id} for user #{socket.assigns.current_user.id}")
    
    case PhoenixApp.Forum.accept_channel_invite(invite_id, socket.assigns.current_user.id) do
      {:ok, _member} ->
        Logger.info("Successfully accepted invite #{invite_id}")
        # Reload invites and count
        pending_invites = PhoenixApp.Forum.list_pending_invites_for_user(socket.assigns.current_user.id)
        pending_invite_count = length(pending_invites)
        
        {:noreply,
         socket
         |> assign(pending_invites: pending_invites, pending_invite_count: pending_invite_count)
         |> put_flash(:info, "✓ Joined channel successfully!")}
      
      {:error, reason} ->
        Logger.error("Failed to accept invite #{invite_id}: #{inspect(reason)}")
        message = case reason do
          :not_found -> "Invite not found"
          :forbidden -> "You don't have permission to accept this invite"
          :invite_expired -> "This invite has expired"
          :already_member -> "You're already a member of this channel"
          _ -> "Failed to accept invite: #{inspect(reason)}"
        end
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("schedule_meeting", %{"title" => title}, socket) do
    # In a real implementation, this would create a database record
    # For now, we'll just simulate success
    
    {:noreply, 
     socket
     |> assign(show_calendar: false)
     |> put_flash(:info, "Meeting '#{title}' scheduled successfully in channel!")}
  end

  def handle_event("decline_invite", %{"invite_id" => invite_id}, socket) do
    require Logger
    Logger.info("Desktop: decline_invite called invite_id=#{invite_id} user=#{socket.assigns.current_user && socket.assigns.current_user.id}")
    require Logger
    # invite_id is a UUID string, keep it as-is
    Logger.info("Declining invite #{invite_id} for user #{socket.assigns.current_user.id}")
    
    case PhoenixApp.Forum.decline_invite(invite_id, socket.assigns.current_user.id) do
      {:ok, _} ->
        Logger.info("Successfully declined invite #{invite_id}")
        # Reload invites and count
        pending_invites = PhoenixApp.Forum.list_pending_invites_for_user(socket.assigns.current_user.id)
        pending_invite_count = length(pending_invites)
        
        {:noreply, assign(socket, pending_invites: pending_invites, pending_invite_count: pending_invite_count)}
      
      {:error, reason} ->
        Logger.error("Failed to decline invite #{invite_id}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to decline invite")}
    end
  end

  def handle_event("open_app", %{"app" => app}, socket) do
    require Logger
    Logger.info("Opening app: #{app}")
    
    window_id = Ecto.UUID.generate()
    user = socket.assigns.current_user
    
    # TEMPORARILY DISABLED: Load saved layout if available (causing DB errors)
    # saved_layout = if user do
    #   PhoenixApp.Desktop.get_window_layout(user.id, app)
    # else
    #   nil
    # end
    
    new_window = case app do
      "file_manager" ->
        # Load file manager with drive view
        is_admin = user && user.is_admin
        
        # Start at root showing available drives
        drives = get_available_drives(user)

        %{
          id: window_id,
          title: "File Manager",
          app: "file_manager",
          x: 150,
          y: 150,
          width: 800,
          height: 600,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          current_path: "/",
          current_items: drives,
          breadcrumbs: [],
          search_query: "",
          filter: "all",
          view_mode: "grid",
          current_page: 1,
          page_size: 20,
          is_admin: is_admin || false,
          user_id: user && user.id
        }
      
      "text_editor" ->
        %{
          id: window_id,
          title: "Text Editor",
          app: "text_editor",
          x: 200,
          y: 200,
          width: 700,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          content: ""
        }
      
      "terminal" ->
        %{
          id: window_id,
          title: "Terminal",
          app: "terminal",
          x: 250,
          y: 250,
          width: 800,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          history: [],
          current_directory: "~"
        }
      
      "calculator" ->
        %{
          id: window_id,
          title: "Calculator",
          app: "calculator",
          x: 300,
          y: 300,
          width: 350,
          height: 450,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          display: "0",
          memory: 0
        }
      
      "notepad" ->
        %{
          id: window_id,
          title: "Notepad",
          app: "notepad",
          x: 350,
          y: 150,
          width: 600,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          content: ""
        }
      
      "media_player" ->
        %{
          id: window_id,
          title: "Media Player",
          app: "media_player",
          x: 400,
          y: 200,
          width: 600,
          height: 400,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index,
          current_track: nil,
          playing: false
        }
      
      "settings" ->
        %{
          id: window_id,
          title: "Settings",
          app: "settings",
          x: 450,
          y: 250,
          width: 700,
          height: 500,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index
        }
      
      _ ->
        %{
          id: window_id,
          title: "Unknown App",
          app: "unknown",
          x: 100,
          y: 100,
          width: 400,
          height: 300,
          minimized: false,
          maximized: false,
          z_index: socket.assigns.next_z_index
        }
    end
    
    {:noreply, 
     socket
     |> assign(:windows, [new_window | socket.assigns.windows])
     |> assign(:next_z_index, socket.assigns.next_z_index + 1)
     |> assign(:show_start_menu, false)}
  end

  def handle_event("close_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      # TEMPORARILY DISABLED: Save window state before closing
      # window_to_close = Enum.find(socket.assigns.windows, &(&1.id == id))
      # if window_to_close && socket.assigns.current_user do
      #   save_window_state(socket.assigns.current_user.id, window_to_close)
      # end
      
      windows = Enum.reject(socket.assigns.windows, &(&1.id == id))
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("focus_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          %{window | z_index: socket.assigns.next_z_index}
        else
          window
        end
      end)
    
    {:noreply, 
     socket
     |> assign(:windows, windows)
     |> assign(:next_z_index, socket.assigns.next_z_index + 1)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("minimize_window", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          updated_window = %{window | minimized: !window.minimized}
          
          # Save state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) when event in ["toggle_maximize", "maximize_window", "restore_window"] do
    with id when not is_nil(id) <- get_window_id(params) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == id do
          updated_window = %{window | maximized: !window.maximized}
          
          # Save state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_window_position", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      windows = 
        Enum.map(socket.assigns.windows, fn window ->
          if window.id == id do
            updated_window = %{window | x: params["x"], y: params["y"]}
            
            # TEMP DISABLED: Persist to database if user is authenticated
            # if socket.assigns.current_user do
            #   Task.start(fn ->
            #     PhoenixApp.Desktop.save_window_layout(
            #       socket.assigns.current_user.id,
            #       window.app,
            #       %{x: params["x"], y: params["y"], width: window.width, height: window.height}
            #     )
            #   end)
            # end
            
            updated_window
          else
            window
          end
        end)
      
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_window_size", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      windows = 
        Enum.map(socket.assigns.windows, fn window ->
          if window.id == id do
            updated_window = %{window | width: params["width"], height: params["height"]}
            
            # TEMP DISABLED: Persist to database if user is authenticated
            # if socket.assigns.current_user do
            #   Task.start(fn ->
            #     PhoenixApp.Desktop.save_window_layout(
            #       socket.assigns.current_user.id,
            #       window.app,
            #       %{x: window.x, y: window.y, width: params["width"], height: params["height"]}
            #     )
            #   end)
            # end
            
            updated_window
          else
            window
          end
        end)
      
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_window_layout", params, socket) do
    with id when not is_nil(id) <- get_window_id(params) do
      windows = 
        Enum.map(socket.assigns.windows, fn window ->
          if window.id == id do
            updated_window = %{window | 
              width: params["width"], 
              height: params["height"],
              x: params["x"],
              y: params["y"]
            }
            
            # TEMP DISABLED: Persist to database if user is authenticated
            # if socket.assigns.current_user do
            #   Task.start(fn ->
            #     PhoenixApp.Desktop.save_window_layout(
            #       socket.assigns.current_user.id,
            #       window.app,
            #       %{x: params["x"], y: params["y"], width: params["width"], height: params["height"]}
            #     )
            #   end)
            # end
            
            updated_window
          else
            window
          end
        end)
      
      {:noreply, assign(socket, :windows, windows)}
    else
      _ -> {:noreply, socket}
    end
  end

  # ==================== FILE MANAGER HANDLERS ====================

  def handle_event("change_view_mode", %{"mode" => mode, "window_id" => window_id}, socket) do
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          updated_window = %{window | view_mode: mode}
          
          # Save view mode preference
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("navigate_to", %{"path" => path, "window_id" => window_id}, socket) do
    user = socket.assigns.current_user
    
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          # Handle drive navigation
          items = cond do
            path == "/" ->
              get_available_drives(user)
            
            String.starts_with?(path, "public://") ->
              get_public_drive_contents(path, user)
            
            String.starts_with?(path, "user://") ->
              get_user_drive_contents(path, user)
            
            String.starts_with?(path, "root://") ->
              get_root_drive_contents(path, user)
            
            true ->
              []
          end
          
          breadcrumbs = build_breadcrumbs(path)
          
          updated_window = %{window | 
            current_path: path, 
            current_items: items,
            breadcrumbs: breadcrumbs,
            current_page: 1
          }
          
          # Save navigation state
          if socket.assigns.current_user do
            # TEMP DISABLED: save_window_state(socket.assigns.current_user.id, updated_window)
          end
          
          updated_window
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_event("navigate_back", %{"window_id" => window_id}, socket) do
    user = socket.assigns.current_user
    
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          parent_path = get_parent_path(window.current_path)
          
          items = cond do
            parent_path == "/" ->
              get_available_drives(user)
            
            String.starts_with?(parent_path, "public://") ->
              get_public_drive_contents(parent_path, user)
            
            String.starts_with?(parent_path, "user://") ->
              get_user_drive_contents(parent_path, user)
            
            String.starts_with?(parent_path, "root://") ->
              get_root_drive_contents(parent_path, user)
            
            true ->
              []
          end
          
          breadcrumbs = build_breadcrumbs(parent_path)
          
          %{window | 
            current_path: parent_path,
            current_items: items,
            breadcrumbs: breadcrumbs,
            current_page: 1
          }
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  # ==================== UPLOAD HANDLERS ====================

  def handle_event("validate_upload", params, socket) do
    window_id = params["window_id"]
    {:noreply, assign(socket, :upload_window_id, window_id)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("save_upload", %{"window_id" => window_id}, socket) do
    # Find the window to get the current path
    window = Enum.find(socket.assigns.windows, &(&1.id == window_id))
    
    if window do
      dest_path = get_real_path(window.current_path, socket.assigns.current_user)
      
      if dest_path do
        consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
          dest = Path.join(dest_path, entry.client_name)
          File.cp!(path, dest)
          {:ok, dest}
        end)
        
        # Refresh window contents
        # We can just trigger a navigate_to event to refresh
        send(self(), {:refresh_window, window_id})
      end
    end
    
    {:noreply, socket}
  end

  # ==================== HELPERS ====================

  defp get_window_id(params) do
    Map.get(params, "window_id") || Map.get(params, "id")
  end

  defp build_breadcrumbs(path) do
    case path do
      "/" -> []
      "public://" -> [%{name: "Public Drive", path: "public://"}]
      "user://" <> _ ->
        [%{name: "User Drive", path: "user://"}]
      "root://" <> _ ->
        [%{name: "System Root", path: "root://"}]
      _ ->
        # Build breadcrumb trail from path segments
        segments = String.split(path, "/", trim: true)
        Enum.with_index(segments, fn segment, idx ->
          accumulated_path = Enum.take(segments, idx + 1) |> Enum.join("/")
          %{name: segment, path: "/" <> accumulated_path}
        end)
    end
  end

  defp get_parent_path(path) do
    case path do
      "/" -> "/"
      path ->
        path
        |> String.split("/")
        |> Enum.drop(-1)
        |> case do
          [] -> "/"
          segments -> Enum.join(segments, "/")
        end
    end
  end

  # ==================== PUBSUB HANDLERS ====================

  def handle_info({:refresh_window, window_id}, socket) do
    # Refresh the window content by re-fetching items
    windows = 
      Enum.map(socket.assigns.windows, fn window ->
        if window.id == window_id && window.app == "file_manager" do
          items = cond do
            window.current_path == "/" ->
              get_available_drives(socket.assigns.current_user)
            
            String.starts_with?(window.current_path, "public://") ->
              get_public_drive_contents(window.current_path, socket.assigns.current_user)
            
            String.starts_with?(window.current_path, "user://") ->
              get_user_drive_contents(window.current_path, socket.assigns.current_user)
            
            String.starts_with?(window.current_path, "root://") ->
              get_root_drive_contents(window.current_path, socket.assigns.current_user)
            
            true ->
              []
          end
          
          %{window | current_items: items}
        else
          window
        end
      end)
    
    {:noreply, assign(socket, :windows, windows)}
  end

  def handle_info({:new_invite, _invite}, socket) do
    # Update invite count when new invite arrives
    pending_invite_count = if socket.assigns.current_user do
      PhoenixApp.Forum.count_pending_invites(socket.assigns.current_user.id)
    else
      0
    end
    
    # Play notification sound if enabled
    socket = if socket.assigns.current_user && socket.assigns.current_user.notification_sound_enabled do
      volume = socket.assigns.current_user.master_volume || 0.5
      sound_path = "/uploads/public/audio/Blaster Master SFX (3).wav"
      push_event(socket, "play_sound", %{path: sound_path, volume: volume})
    else
      socket
    end
    
    {:noreply, assign(socket, pending_invite_count: pending_invite_count)}
  end

  # ==================== RENDER ====================

  defp render_window_content(assigns, window) do
    case window.app do
      "file_manager" ->
        assigns = assign(assigns, :window, window)
        ~H"""
        <PhoenixAppWeb.Components.Window.file_manager_content 
          window={@window}
          current_user={@current_user}
          uploads={@uploads}
          target={@myself}
        />
        """
      "terminal" ->
        ~H"""
        <div class="p-4 font-mono text-sm text-green-400 bg-black h-full">
          <div>Terminal Emulator</div>
          <div class="mt-2">$ <span class="animate-pulse">_</span></div>
        </div>
        """
      "calculator" ->
        ~H"""
        <div class="p-4 bg-gray-900 h-full flex flex-col">
          <div class="text-right text-2xl text-white mb-4 p-2 glass-dark rounded">0</div>
          <div class="grid grid-cols-4 gap-2 flex-1">
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">7</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">8</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">9</button>
            <button class="bg-blue-600 hover:bg-blue-500 text-white rounded p-2">÷</button>
            
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">4</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">5</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">6</button>
            <button class="bg-blue-600 hover:bg-blue-500 text-white rounded p-2">×</button>
            
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">1</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">2</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">3</button>
            <button class="bg-blue-600 hover:bg-blue-500 text-white rounded p-2">-</button>
            
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">0</button>
            <button class="bg-gray-700 hover:bg-gray-600 text-white rounded p-2">.</button>
            <button class="bg-green-600 hover:bg-green-500 text-white rounded p-2">=</button>
            <button class="bg-blue-600 hover:bg-blue-500 text-white rounded p-2">+</button>
          </div>
        </div>
        """
      "notepad" ->
        ~H"""
        <div class="h-full">
          <textarea class="w-full h-full bg-white text-black p-4 font-mono resize-none border-0 focus:outline-none" placeholder="Start typing..."></textarea>
        </div>
        """
      _ ->
        ~H"""
        <div class="p-4 text-center text-gray-400">
          <p>Application content not available</p>
        </div>
        """
    end
  end

  def render(assigns) do
    ~H"""
    <div id="phoenix-desktop" class="pointer-events-none" phx-hook="AudioHook" data-volume={@current_user && @current_user.master_volume || 0.5}>
      <!-- Windows layer - positioned above page content -->
      <div class="fixed inset-0 z-40 pointer-events-none">
        <%= for window <- @windows do %>
          <div class="pointer-events-auto" style={"z-index: #{window.z_index}"}>
            <PhoenixAppWeb.Components.Window.desktop_window window={window} current_user={@current_user} target={@myself}>
              <%= render_window_content(assigns, window) %>
            </PhoenixAppWeb.Components.Window.desktop_window>
          </div>
        <% end %>
      </div>
      
                  <!-- Taskbar - always visible at bottom -->
      <div class="pointer-events-auto">
        <PhoenixAppWeb.Components.Taskbar.taskbar 
          current_user={@current_user}
          open_windows={@windows}
          show_start_menu={@show_start_menu}
          show_notifications={@show_notifications}
          show_audio_panel={@show_audio_panel}
          show_calendar={@show_calendar}
          pending_invite_count={@pending_invite_count}
          calendar_notes={@calendar_notes}
          selected_date={@selected_date}
          target={@myself}
          uploads={@uploads}
        />
      </div>

      <!-- Notification Panel -->
      <div class="pointer-events-auto">
        <PhoenixAppWeb.Components.NotificationPanel.notification_panel
          show={@show_notifications}
          pending_invites={@pending_invites}
          current_user={@current_user}
          target={@myself}
        />
      </div>
    </div>
    """
  end

  defp get_available_drives(user) do
    drives = [
      %{
        id: "public",
        name: "Public Drive",
        description: "Shared files for all users",
        type: :drive,
        icon: "🌐",
        path: "public://",
        size: "Shared",
        modified: DateTime.utc_now()
      }
    ]
    
    if user do
      drives = drives ++ [
        %{
          id: "user_#{user.id}",
          name: "#{user.name || user.email}'s Drive",
          description: "Personal storage space",
          type: :drive,
          icon: "💾",
          path: "user://#{user.id}",
          size: "Personal",
          modified: DateTime.utc_now()
        }
      ]
      
      if user.role in ["admin", "gm"] do
        drives ++ [
          %{
            id: "admin_root",
            name: "System Root",
            description: "Full system access",
            type: :drive,
            icon: "⚡",
            path: "root://",
            size: "System",
            modified: DateTime.utc_now()
          }
        ]
      else
        drives
      end
    else
      drives
    end
  end

  defp get_public_drive_contents(path, user) do
    real_path = get_real_path(path, user)
    list_contents(real_path, path)
  end

  defp get_user_drive_contents(path, user) do
    real_path = get_real_path(path, user)
    
    # Ensure directory exists
    if !File.exists?(real_path) do
      File.mkdir_p!(real_path)
    end
    
    list_contents(real_path, path)
  end

  defp get_root_drive_contents(path, user) do
    if user.role in ["admin", "gm"] do
      real_path = get_real_path(path, user)
      list_contents(real_path, path)
    else
      []
    end
  end

  defp get_real_path(path, user) do
    base_path = 
      cond do
        File.exists?("/app/uploads") -> "/app/uploads"
        File.exists?("uploads") -> Path.expand("uploads")
        true -> Application.app_dir(:phoenix_app, "priv/static/uploads")
      end
    
    cond do
      path == "root://" && user && user.role in ["admin", "gm"] ->
        base_path
        
      String.starts_with?(path, "root://") && user && user.role in ["admin", "gm"] ->
        subpath = String.replace_prefix(path, "root://", "")
        Path.join(base_path, subpath)
        
      path == "public://" ->
        Path.join(base_path, "public")
      
      String.starts_with?(path, "public://") ->
        subpath = String.replace_prefix(path, "public://", "")
        Path.join([base_path, "public", subpath])
        
      path == "user://" && user ->
        Path.join([base_path, "users", "#{user.id}"])
        
      String.starts_with?(path, "user://") && user ->
        subpath = String.replace_prefix(path, "user://", "")
        Path.join([base_path, "users", "#{user.id}", subpath])
        
      true -> nil
    end
  end

  defp list_contents(real_path, virtual_root) do
    if real_path && File.exists?(real_path) && File.dir?(real_path) do
      case File.ls(real_path) do
        {:ok, files} ->
          files
          |> Enum.map(fn file ->
            full_path = Path.join(real_path, file)
            stat = File.stat!(full_path)
            type = if stat.type == :directory, do: :folder, else: :file
            
            # Virtual path for navigation
            virtual_path = 
              if String.ends_with?(virtual_root, "//") do
                virtual_root <> file
              else
                virtual_root <> "/" <> file
              end

            %{
              id: Base.encode64(virtual_path),
              name: file,
              type: type,
              icon: get_file_icon(file, type),
              path: virtual_path,
              size: if(type == :folder, do: "-", else: format_size(stat.size)),
              modified: stat.mtime |> NaiveDateTime.from_erl!()
            }
          end)
          |> Enum.sort_by(&{&1.type != :folder, &1.name})
        _ -> []
      end
    else
      []
    end
  end

  defp get_file_icon(_name, :folder), do: "📁"
  defp get_file_icon(name, :file) do
    ext = Path.extname(name) |> String.downcase()
    case ext do
      ".jpg" -> "🖼️"
      ".png" -> "🖼️"
      ".gif" -> "🖼️"
      ".pdf" -> "📕"
      ".txt" -> "📄"
      ".mp3" -> "🎵"
      ".wav" -> "🎵"
      ".mp4" -> "🎬"
      ".zip" -> "📦"
      _ -> "📄"
    end
  end

  defp format_size(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 1)} KB"
      size < 1024 * 1024 * 1024 -> "#{Float.round(size / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  defp check_quota(user, file_size) do
    # Calculate current usage
    user_path = get_real_path("user://", user)
    current_usage = get_dir_size(user_path)
    
    limit = case user.role do
      "admin" -> :infinity
      "editor" -> 10 * 1024 * 1024 * 1024 # 10GB
      _ -> 1 * 1024 * 1024 * 1024 # 1GB
    end
    
    if limit == :infinity do
      :ok
    else
      if current_usage + file_size > limit do
        {:error, "Quota exceeded"}
      else
        :ok
      end
    end
  end
  
  defp get_dir_size(path) do
    if File.exists?(path) do
      path
      |> File.ls!()
      |> Enum.map(fn file -> 
        p = Path.join(path, file)
        if File.dir?(p), do: get_dir_size(p), else: File.stat!(p).size
      end)
      |> Enum.sum()
    else
      0
    end
  end
end
