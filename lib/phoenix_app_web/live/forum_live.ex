defmodule PhoenixAppWeb.ForumLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Forum
  alias PhoenixApp.Content.Media
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      # Get system channels (non-user-created)
      system_channels = Forum.list_channels()
      
      # Ensure we have at least a default channel
      default_channel = if Enum.empty?(system_channels) do
        Forum.get_or_create_default_channel()
      else
        List.first(system_channels)
      end

      # Get user-created channels
      user_owned_channels = Forum.list_user_owned_channels(user.id)
      user_member_channels = Forum.list_user_member_channels(user.id)
      public_user_channels = Forum.list_public_user_channels()

      # Subscribe to channel updates
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "chat:channels")

      socket = assign(socket,
        system_channels: if(Enum.empty?(system_channels), do: [default_channel], else: system_channels),
        user_owned_channels: user_owned_channels,
        user_member_channels: user_member_channels,
        public_user_channels: public_user_channels,
        # Add missing assigns expected by template
        public_channels: public_user_channels,
        user_channels: user_owned_channels ++ user_member_channels,
        current_channel: default_channel,
        messages: Forum.list_messages(default_channel.id),
        current_message: "",
        online_users: %{},
        typing_users: MapSet.new(),
        show_create_channel_form: false,
        channel_form: to_form(Forum.change_channel(%Forum.Channel{})),
        page_title: "Forum - #{default_channel.name}",
        show_channel_modal: false,
        editing_channel: nil,
        message_attachments: [],
        show_attachments: false,
        active_stream: nil,
        show_delete_channel_confirm: false,
        can_create_more_channels: length(user_owned_channels) < 5
      )
      |> allow_upload(:forum_attachment,
        accept: ~w(.jpg .jpeg .png .gif .webp .pdf .mp4 .webm .mov .avi .mp3 .wav .ogg .m4a .flac .zip .tar .gz),
        max_entries: 5,
        max_file_size: 100_000_000,  # 100MB for video files
        auto_upload: false  # Manual upload control
      )
      
      # Subscribe to the default channel
      PubSub.subscribe(PhoenixApp.PubSub, "channel:#{default_channel.id}")

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def handle_params(%{"channel_id" => channel_id}, _uri, socket) do
    channel = Forum.get_channel!(channel_id)
    messages = Forum.list_messages(channel_id)
    active_stream = Forum.get_active_stream(channel_id)
    
    # Unsubscribe from previous channel
    if socket.assigns[:current_channel] do
      PubSub.unsubscribe(PhoenixApp.PubSub, "channel:#{socket.assigns.current_channel.id}")
    end
    
    # Subscribe to new channel
    PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel_id}")
    
    {:noreply, assign(socket,
      current_channel: channel,
      messages: messages,
      active_stream: active_stream,
      page_title: "Chat - #{channel.name}"
    )}
  end

  def handle_params(_params, _uri, socket) do
    if socket.assigns[:current_channel] do
      channel = socket.assigns.current_channel
      messages = Forum.list_messages(channel.id)
      
      # Subscribe to channel updates
      PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel.id}")
      
      {:noreply, assign(socket, messages: messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => content} = _params, socket) when content != "" do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel

    # Handle file uploads first
    uploaded_files = consume_uploaded_entries(socket, :forum_attachment, fn %{path: path}, entry ->
      # Use centralized upload module
      case PhoenixApp.Uploads.upload_file(user, path, entry, context: "forum") do
        {:ok, url_path} ->
          case Media.create_media(user, %{
            "filename" => Path.basename(url_path),
            "original_filename" => entry.client_name,
            "file_type" => determine_file_type(entry.client_type),
            "mime_type" => entry.client_type,
            "file_size" => entry.client_size,
            "file_path" => PhoenixApp.Uploads.url_to_path(url_path),
            "url" => url_path,
            "is_public" => !channel.is_private
          }) do
            {:ok, media} -> {:ok, media}
            {:error, _} -> {:error, "media_db_error"}
          end
        
        {:error, reason} ->
          {:error, reason}
      end
    end)

    # Create message with attachments
    message_attrs = %{content: content}
    message_attrs = if length(uploaded_files) > 0 do
      Map.put(message_attrs, "attachments", Enum.map(uploaded_files, & &1.id))
    else
      message_attrs
    end

    case Forum.create_message(user, channel.id, message_attrs) do
      {:ok, _message} ->
        {:noreply, assign(socket, current_message: "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    # Broadcast typing indicator
    if String.length(message) > 0 do
      PubSub.broadcast(PhoenixApp.PubSub, "channel:#{socket.assigns.current_channel.id}", 
        {:user_typing, socket.assigns.current_user.id})
    end
    
    {:noreply, assign(socket, current_message: message)}
  end

  def handle_event("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    message = Forum.get_message!(message_id)
    
    if message.user_id == socket.assigns.current_user.id do
      case Forum.update_message(message, %{content: content}) do
        {:ok, _updated_message} ->
          {:noreply, put_flash(socket, :info, "Message updated")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update message")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only edit your own messages")}
    end
  end

  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    message = Forum.get_message!(message_id)
    
    if message.user_id == socket.assigns.current_user.id do
      case Forum.delete_message(message) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Message deleted")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete message")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own messages")}
    end
  end

  def handle_event("toggle_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    message = Forum.get_message!(message_id)
    user = socket.assigns.current_user
    
    Forum.add_reaction(message, user, emoji)
    {:noreply, socket}
  end

  def handle_event("toggle_create_channel", _params, socket) do
    {:noreply, assign(socket, show_create_channel_form: !socket.assigns.show_create_channel_form)}
  end

  def handle_event("save_channel", %{"channel" => channel_params}, socket) do
    user = socket.assigns.current_user
    
    case Forum.create_user_channel(user, channel_params) do
      {:ok, channel} ->
        # Subscribe to the new channel
        PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel.id}")
        
        socket = assign(socket,
          show_create_channel_form: false,
          current_channel: channel,
          messages: [],
          page_title: "Forum - #{channel.name}"
        )
        
        {:noreply, push_navigate(socket, to: "/forum/#{channel.id}")}
        
      {:error, changeset} ->
        {:noreply, assign(socket, channel_form: to_form(changeset))}
    end
  end

  def handle_event("switch_channel", %{"channel_id" => channel_id}, socket) do
    # Unsubscribe from the old channel
    PubSub.unsubscribe(PhoenixApp.PubSub, "channel:#{socket.assigns.current_channel.id}")
    
    # Fetch new channel data
    channel = Forum.get_channel!(channel_id)
    messages = Forum.list_messages(channel_id)
    
    # Subscribe to the new channel
    PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel.id}")
    
    socket = assign(socket,
      current_channel: channel,
      messages: messages,
      page_title: "Forum - #{channel.name}"
    )
    
    {:noreply, push_navigate(socket, to: "/forum/#{channel.id}")}
  end

  # Channel CRUD Events
  def handle_event("show_create_channel", _params, socket) do
    user = socket.assigns.current_user
    
    if user && (user.is_admin || user.role in ["admin", "gm", "editor"]) do
      {:noreply, assign(socket, show_create_channel_form: true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to create channels.")}
    end
  end

  def handle_event("hide_create_channel", _params, socket) do
    {:noreply, assign(socket, show_create_channel_form: false, channel_form: to_form(Forum.change_channel(%Forum.Channel{})))}
  end

  def handle_event("validate_channel", %{"channel" => channel_params}, socket) do
    changeset = 
      %Forum.Channel{}
      |> Forum.change_channel(channel_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, channel_form: to_form(changeset, action: :validate))}
  end

  def handle_event("create_channel", %{"channel" => channel_params}, socket) do
    user = socket.assigns.current_user
    
    # Check if user has permission to create channels
    if user && (user.is_admin || user.role in ["admin", "gm", "editor"]) do
      case Forum.create_channel(channel_params) do
        {:ok, channel} ->
          system_channels = Forum.list_channels()

          {:noreply,
           socket
           |> assign(show_create_channel_form: false, channel_form: to_form(Forum.change_channel(%Forum.Channel{})))
           |> assign(system_channels: system_channels)
           |> put_flash(:info, "Channel '#{channel.name}' created successfully!")}

        {:error, changeset} ->
          {:noreply, assign(socket, channel_form: to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> assign(show_create_channel_form: false)
       |> put_flash(:error, "You don't have permission to create channels. Contact an admin.")}
    end
  end

  def handle_event("show_delete_channel_confirm", _params, socket) do
    {:noreply, assign(socket, show_delete_channel_confirm: true)}
  end

  def handle_event("cancel_delete_channel", _params, socket) do
    {:noreply, assign(socket, show_delete_channel_confirm: false)}
  end

  def handle_event("confirm_delete_channel", _params, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel

    # Only owner or admin-like roles can delete a channel
    if (Map.has_key?(channel, :owner_id) && channel.owner_id == user.id) or Map.get(user, :is_admin, false) or Map.get(user, :role) in ["admin", "gm"] do
      case Forum.delete_channel(channel) do
        {:ok, _} ->
          # Refresh channel lists
          system_channels = Forum.list_channels()
          user_owned_channels = Forum.list_user_owned_channels(user.id)
          user_member_channels = Forum.list_user_member_channels(user.id)
          public_user_channels = Forum.list_public_user_channels()

          # Navigate to default channel
          default = if Enum.empty?(system_channels) do
            Forum.get_or_create_default_channel()
          else
            List.first(system_channels)
          end

          {:noreply, 
           socket
           |> assign(
             system_channels: if(Enum.empty?(system_channels), do: [default], else: system_channels),
             user_owned_channels: user_owned_channels,
             user_member_channels: user_member_channels,
             public_user_channels: public_user_channels,
             public_channels: public_user_channels,
             user_channels: user_owned_channels ++ user_member_channels,
             current_channel: default,
             messages: Forum.list_messages(default.id),
             show_delete_channel_confirm: false
           )
           |> put_flash(:info, "Channel '#{channel.name}' deleted successfully. All messages and files have been removed.")
           |> push_navigate(to: ~p"/forum/#{default.id}")}

        {:error, _} ->
          {:noreply, 
           socket
           |> assign(show_delete_channel_confirm: false)
           |> put_flash(:error, "Failed to delete channel")}
      end
    else
      {:noreply, 
       socket
       |> assign(show_delete_channel_confirm: false)
       |> put_flash(:error, "You don't have permission to delete this channel")}
    end
  end

  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    user = socket.assigns.current_user

    # Ensure channel exists
    channel = Forum.get_channel!(channel_id)

    # Only owner or admin-like roles can delete a channel
    if (Map.has_key?(channel, :owner_id) && channel.owner_id == user.id) or Map.get(user, :is_admin, false) or Map.get(user, :role) in ["admin", "gm"] do
      case Forum.delete_channel(channel) do
        {:ok, _} ->
          # Refresh lists and switch to default channel if needed
          user_owned_channels = Forum.list_user_owned_channels(user.id)
          user_member_channels = Forum.list_user_member_channels(user.id)
          public_user_channels = Forum.list_public_user_channels()

          socket = assign(socket,
            user_owned_channels: user_owned_channels,
            user_member_channels: user_member_channels,
            public_user_channels: public_user_channels
          )

          # If deleted channel was current, navigate to default
          if socket.assigns.current_channel.id == channel.id do
            default = Forum.get_or_create_default_channel()
            {:noreply, socket |> assign(current_channel: default, messages: Forum.list_messages(default.id)) |> push_navigate(to: ~p"/forum/#{default.id}")}
          else
            {:noreply, put_flash(socket, :info, "Channel deleted")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete channel")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete this channel")}
    end
  end

  # User-Created Channel Events
  def handle_event("show_create_user_channel", _params, socket) do
    if socket.assigns.can_create_more_channels do
      {:noreply, assign(socket, show_create_channel_form: true, creating_user_channel: true)}
    else
      {:noreply, put_flash(socket, :error, "You've reached the maximum of 5 channels")}
    end
  end

  def handle_event("create_user_channel", %{"channel" => channel_params}, socket) do
    user = socket.assigns.current_user
    
    # Add owner_id and user_created flag
    channel_params = Map.merge(channel_params, %{
      "owner_id" => user.id,
      "is_user_created" => true
    })
    
    case Forum.create_user_channel(channel_params) do
      {:ok, channel} ->
        user_owned_channels = Forum.list_user_owned_channels(user.id)
        
        {:noreply,
         socket
         |> assign(
           show_create_channel_form: false,
           creating_user_channel: false,
           user_owned_channels: user_owned_channels,
           can_create_more_channels: length(user_owned_channels) < 5
         )
         |> put_flash(:info, "Channel '#{channel.name}' created!")
         |> push_navigate(to: ~p"/forum/#{channel.id}")}
      
      {:error, %Ecto.Changeset{} = changeset} ->
        error_msg = if changeset.errors[:owner_id] do
          "You can only create up to 5 channels"
        else
          "Failed to create channel"
        end
        {:noreply, assign(socket, channel_form: to_form(changeset)) |> put_flash(:error, error_msg)}
    end
  end

  def handle_event("join_channel_with_invite", %{"code" => code}, socket) do
    user = socket.assigns.current_user
    
    case Forum.use_channel_invite(code, user.id) do
      {:ok, _member} ->
        user_member_channels = Forum.list_user_member_channels(user.id)
        
        {:noreply,
         socket
         |> assign(user_member_channels: user_member_channels)
         |> put_flash(:info, "Successfully joined channel!")}
      
      {:error, reason} ->
        message = case reason do
          :invalid_invite -> "Invalid invite code"
          :invite_expired -> "This invite has expired"
          :already_member -> "You're already a member"
          _ -> "Failed to join channel"
        end
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  # Streaming Events
  def handle_event("start_stream", %{"type" => stream_type}, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel
    
    case Forum.start_stream(%{
      channel_id: channel.id,
      streamer_id: user.id,
      stream_type: stream_type,
      title: "#{user.name || user.email}'s Stream"
    }) do
      {:ok, session} ->
        {:noreply, assign(socket, active_stream: session)}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start stream")}
    end
  end

  def handle_event("end_stream", %{"session_id" => session_id}, socket) do
    case Forum.end_stream(session_id) do
      {:ok, _} ->
        {:noreply, assign(socket, active_stream: nil)}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to end stream")}
    end
  end

  def handle_event("validate_message", _params, socket) do
    # Just validate, don't do anything
    {:noreply, socket}
  end

  def handle_event("toggle_uploads", _params, socket) do
    {:noreply, assign(socket, show_attachments: !socket.assigns.show_attachments)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :forum_attachment, ref)}
  end

  def handle_event("upload_files", _params, socket) do
    # Handle file uploads
    {:noreply, assign(socket, show_attachments: false)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(100)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_updated, updated_message}, socket) do
    messages = Enum.map(socket.assigns.messages, fn message ->
      if message.id == updated_message.id, do: updated_message, else: message
    end)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_deleted, message_id}, socket) do
    messages = Enum.filter(socket.assigns.messages, &(&1.id != message_id))
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:channel_created, channel}, socket) do
    user = socket.assigns.current_user
    
    cond do
      channel.is_public ->
        {:noreply, assign(socket, public_user_channels: socket.assigns.public_user_channels ++ [channel])}
      
      channel.owner_id == user.id ->
        {:noreply, assign(socket, user_owned_channels: socket.assigns.user_owned_channels ++ [channel])}
        
      Forum.is_channel_member?(channel.id, user.id) ->
        {:noreply, assign(socket, user_member_channels: socket.assigns.user_member_channels ++ [channel])}
        
      true ->
        {:noreply, socket}
    end
  end
  
  def handle_info({:channel_updated, updated_channel}, socket) do
    # Update channel in all relevant lists
    update_channel_in_list = fn list ->
      Enum.map(list, fn channel ->
        if channel.id == updated_channel.id, do: updated_channel, else: channel
      end)
    end
    
    socket = socket
    |> assign(system_channels: update_channel_in_list.(socket.assigns.system_channels))
    |> assign(user_owned_channels: update_channel_in_list.(socket.assigns.user_owned_channels))
    |> assign(user_member_channels: update_channel_in_list.(socket.assigns.user_member_channels))
    |> assign(public_user_channels: update_channel_in_list.(socket.assigns.public_user_channels))
    
    # Update current channel if it's the one being edited
    socket = if socket.assigns.current_channel.id == updated_channel.id do
      assign(socket, current_channel: updated_channel, page_title: "Forum - #{updated_channel.name}")
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_info({:channel_deleted, channel_id}, socket) do
    # Remove channel from all lists
    remove_channel_from_list = fn list ->
      Enum.filter(list, &(&1.id != channel_id))
    end
    
    socket = socket
    |> assign(system_channels: remove_channel_from_list.(socket.assigns.system_channels))
    |> assign(user_owned_channels: remove_channel_from_list.(socket.assigns.user_owned_channels))
    |> assign(user_member_channels: remove_channel_from_list.(socket.assigns.user_member_channels))
    |> assign(public_user_channels: remove_channel_from_list.(socket.assigns.public_user_channels))
    
    # If the deleted channel is the current one, switch to default
    if socket.assigns.current_channel.id == channel_id do
      default_channel = Forum.get_or_create_default_channel()
      
      # Subscribe to default channel
      PubSub.subscribe(PhoenixApp.PubSub, "channel:#{default_channel.id}")
      
      socket = assign(socket,
        current_channel: default_channel,
        messages: Forum.list_messages(default_channel.id),
        page_title: "Forum - #{default_channel.name}"
      )
      
      {:noreply, push_navigate(socket, to: "/forum/#{default_channel.id}")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_typing, user_id}, socket) do
    if user_id != socket.assigns.current_user.id do
      typing_users = MapSet.put(socket.assigns.typing_users, user_id)
      
      # Remove typing indicator after 3 seconds
      Process.send_after(self(), {:stop_typing, user_id}, 3000)
      
      {:noreply, assign(socket, typing_users: typing_users)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:stop_typing, user_id}, socket) do
    typing_users = MapSet.delete(socket.assigns.typing_users, user_id)
    {:noreply, assign(socket, typing_users: typing_users)}
  end

  def handle_info({:stream_started, session}, socket) do
    {:noreply, assign(socket, active_stream: session)}
  end

  def handle_info(:stream_ended, socket) do
    {:noreply, assign(socket, active_stream: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="w-full h-full flex flex-row">
      <div class="w-1/4 h-full bg-gray-100 dark:bg-gray-800 p-4 overflow-y-auto">
        <div class="mb-4">
          <h2 class="text-lg font-semibold text-gray-800 dark:text-gray-200">System Channels</h2>
          <ul>
            <%= for channel <- @system_channels do %>
              <li class="my-1">
                <a href="#" phx-click="switch_channel" phx-value-channel_id={channel.id} class={"block p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700 #{active_channel_class(channel, @current_channel)}"}>
                  # <%= channel.name %>
                </a>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="mb-4">
          <h2 class="text-lg font-semibold text-gray-800 dark:text-gray-200">Your Channels</h2>
          <ul>
            <%= for channel <- @user_owned_channels do %>
              <li class="my-1">
                <a href="#" phx-click="switch_channel" phx-value-channel_id={channel.id} class={"block p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700 #{active_channel_class(channel, @current_channel)}"}>
                  # <%= channel.name %>
                </a>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="mb-4">
          <h2 class="text-lg font-semibold text-gray-800 dark:text-gray-200">Public Channels</h2>
          <ul>
            <%= for channel <- @public_channels do %>
              <li class="my-1">
                <a href="#" phx-click="switch_channel" phx-value-channel_id={channel.id} class={"block p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700 #{active_channel_class(channel, @current_channel)}"}>
                  # <%= channel.name %>
                </a>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="mt-4">
          <button phx-click="toggle_create_channel" class="w-full bg-green-500 text-white p-2 rounded-md hover:bg-green-600">
            Create Channel
          </button>
        </div>

        <%= if @show_create_channel_form do %>
          <div class="mt-4 p-4 bg-white dark:bg-gray-700 rounded-md shadow-md">
            <h3 class="text-lg font-semibold mb-2 text-gray-800 dark:text-gray-200">New Channel</h3>
            <.form for={@channel_form} phx-submit="save_channel">
              <div class="mb-2">
                <.input field={@channel_form[:name]} type="text" placeholder="Channel Name" class="w-full p-2 border rounded-md" />
              </div>
              <div class="mb-2">
                <.input field={@channel_form[:is_public]} type="checkbox" label="Public" class="mr-2" />
              </div>
              <button type="submit" class="w-full bg-blue-500 text-white p-2 rounded-md hover:bg-blue-600">Save</button>
            </.form>
          </div>
        <% end %>
      </div>

      <div class="w-3/4 h-full flex flex-col bg-white dark:bg-gray-900">
        <div class="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-800 dark:text-gray-200">#<%= @current_channel.name %></h1>
            <p class="text-sm text-gray-500 dark:text-gray-400"><%= @current_channel.description %></p>
          </div>
          
          <%= if @current_user && (@current_user.is_admin || @current_user.role in ["admin", "gm"] || (Map.has_key?(@current_channel, :owner_id) && @current_channel.owner_id == @current_user.id)) do %>
            <button 
              phx-click="show_delete_channel_confirm" 
              class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-sm rounded transition-colors flex items-center gap-2"
              title="Delete Channel"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
              Delete Channel
            </button>
          <% end %>
        </div>

        <div id="messages" class="flex-1 p-4 overflow-y-auto">
          <%= for message <- @messages do %>
            <div class="flex items-start mb-4">
              <div class="mr-4">
                <%= avatar_tag(message.user, size_class: "w-10 h-10") %>
              </div>
              <div class="flex-1">
                <div class="flex items-baseline">
                  <span class="font-bold text-gray-800 dark:text-gray-200 mr-2"><%= message.user.name || message.user.email %></span>
                  <span class="text-xs text-gray-500 dark:text-gray-400"><%= Calendar.strftime(message.inserted_at, "%H:%M") %></span>
                </div>
                <p class="text-gray-700 dark:text-gray-300"><%= message.content %></p>
                
                <%!-- Display attachments using media preview component --%>
                <%= if message.attachments && length(message.attachments) > 0 do %>
                  <div class="mt-2 space-y-2">
                    <%= for attachment <- message.attachments do %>
                      <PhoenixAppWeb.Components.MediaPreview.media_preview attachment={attachment} />
                    <% end %>
                  </div>
                <% end %>
                
                <div class="flex mt-1">
                  <%= for {emoji, count} <- group_reactions(message.reactions) do %>
                    <div class="flex items-center mr-2 p-1 bg-gray-200 dark:bg-gray-700 rounded-full">
                      <span class="text-sm"><%= emoji %></span>
                      <span class="text-xs text-gray-600 dark:text-gray-400 ml-1"><%= count %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <div class="p-4 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700">
          <form phx-submit="send_message" phx-change="validate_message">
            <%!-- File upload previews --%>
            <%= if length(@uploads.forum_attachment.entries) > 0 do %>
              <div class="mb-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div class="text-xs text-gray-600 dark:text-gray-400 mb-2 font-medium">
                  Attachments (<%= length(@uploads.forum_attachment.entries) %>/5)
                </div>
                <div class="space-y-2">
                  <%= for entry <- @uploads.forum_attachment.entries do %>
                    <div class="flex items-center justify-between p-2 bg-white dark:bg-gray-600 rounded">
                      <div class="flex items-center flex-1 min-w-0 mr-2">
                        <svg class="w-4 h-4 text-gray-500 dark:text-gray-300 flex-shrink-0 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path>
                        </svg>
                        <span class="text-sm text-gray-700 dark:text-gray-200 truncate"><%= entry.client_name %></span>
                      </div>
                      <div class="flex items-center space-x-2 flex-shrink-0">
                        <div class="w-16 bg-gray-200 dark:bg-gray-500 rounded-full h-1.5">
                          <div class="bg-blue-500 h-1.5 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                        </div>
                        <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700 text-xs">✕</button>
                      </div>
                    </div>
                    <%= for err <- upload_errors(@uploads.forum_attachment, entry) do %>
                      <p class="text-xs text-red-500 mt-1"><%= error_to_string(err) %></p>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
            
            <div class="flex items-end space-x-2">
              <div class="flex-1">
                <textarea 
                  name="message" 
                  placeholder="Type a message..." 
                  class="w-full p-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                  rows="2"
                  phx-keydown="typing"
                  phx-debounce="1000"
                ></textarea>
              </div>
              <div class="flex flex-col space-y-1">
                <label for={@uploads.forum_attachment.ref} class="cursor-pointer bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 p-2 rounded-md transition-colors" title="Attach files">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path>
                  </svg>
                  <.live_file_input upload={@uploads.forum_attachment} class="sr-only" />
                </label>
                <button type="submit" class="bg-blue-500 text-white p-2 rounded-md hover:bg-blue-600 transition-colors">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                  </svg>
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%!-- Delete Channel Confirmation Modal --%>
    <%= if @show_delete_channel_confirm do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center pointer-events-auto">
        <div class="absolute inset-0 bg-black/50" phx-click="cancel_delete_channel"></div>
        <div class="relative bg-gray-800 rounded-xl shadow-xl p-6 max-w-md w-full mx-4 border border-red-500/50">
          <div class="flex items-start mb-4">
            <div class="flex-shrink-0">
              <svg class="h-10 w-10 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-white mb-2">Delete Channel</h3>
              <p class="text-gray-300 text-sm mb-4">
                Are you sure you want to delete <span class="font-bold text-white">#<%= @current_channel.name %></span>?
              </p>
              <p class="text-red-400 text-sm font-medium">
                ⚠️ This will permanently delete:
              </p>
              <ul class="text-gray-300 text-sm mt-2 ml-4 space-y-1">
                <li>• All messages in this channel</li>
                <li>• All uploaded files and attachments</li>
                <li>• All reactions and threads</li>
              </ul>
              <p class="text-red-400 text-sm font-bold mt-3">
                This action cannot be undone!
              </p>
            </div>
          </div>
          
          <div class="flex justify-end gap-3">
            <button 
              phx-click="cancel_delete_channel" 
              class="px-4 py-2 bg-gray-600 hover:bg-gray-500 text-white rounded transition-colors"
            >
              Cancel
            </button>
            <button 
              phx-click="confirm_delete_channel" 
              class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded transition-colors font-medium"
            >
              Delete Permanently
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp group_reactions(reactions) do
    Enum.group_by(reactions, &(&1.emoji))
    |> Enum.map(fn {emoji, reactions} -> {emoji, length(reactions)} end)
  end

  defp active_channel_class(channel, current_channel) do
    if channel.id == current_channel.id do
      "bg-blue-500 text-white"
    else
      "text-gray-600 dark:text-gray-400"
    end
  end

  defp determine_file_type(mime_type) when is_binary(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      mime_type == "application/pdf" -> "pdf"
      String.ends_with?(mime_type, "zip") -> "zip"
      true -> "file"
    end
  end

  # Helper for upload errors
  defp error_to_string(:too_large), do: "File is too large (max 100MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end