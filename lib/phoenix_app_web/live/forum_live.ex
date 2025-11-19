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
        can_create_more_channels: length(user_owned_channels) < 5
      )
      |> allow_upload(:forum_attachment,
        accept: ~w(.jpg .jpeg .png .gif .webp .pdf .mp4 .mp3 .wav .zip),
        max_entries: 5,
        max_file_size: 25_000_000
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

  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    user = socket.assigns.current_user

    # Ensure channel exists
    channel = Forum.get_channel!(channel_id)

    # Only owner or admin-like roles can delete a channel
    if channel.owner_id == user.id or Map.get(user, :is_admin, false) or Map.get(user, :role) in ["admin", "gm"] do
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

  def handle_event("toggle_uploads", _params, socket) do
    {:noreply, assign(socket, show_attachments: !socket.assigns.show_attachments)}
  end

  def handle_event("cancel_upload", _params, socket) do
    {:noreply, assign(socket, show_attachments: false)}
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
        <div class="p-4 border-b border-gray-200 dark:border-gray-700">
          <h1 class="text-2xl font-bold text-gray-800 dark:text-gray-200">#<%= @current_channel.name %></h1>
          <p class="text-sm text-gray-500 dark:text-gray-400"><%= @current_channel.description %></p>
        </div>

        <div id="messages" class="flex-1 p-4 overflow-y-auto">
          <%= for message <- @messages do %>
            <div class="flex items-start mb-4">
              <%!-- Safely build an avatar URL: if the user has an uploaded file, provide it to Arc; otherwise use the default image --%>
              <img src={if message.user && Map.get(message.user, :avatar_file) do
                PhoenixApp.Avatar.url({message.user.avatar_file, message.user}, :thumb)
              else
                PhoenixApp.Avatar.default_url(:thumb)
              end} class="w-10 h-10 rounded-full mr-4" />
              <div class="flex-1">
                <div class="flex items-baseline">
                  <span class="font-bold text-gray-800 dark:text-gray-200 mr-2"><%= message.user.name || message.user.email %></span>
                  <span class="text-xs text-gray-500 dark:text-gray-400"><%= Calendar.strftime(message.inserted_at, "%H:%M") %></span>
                </div>
                <p class="text-gray-700 dark:text-gray-300"><%= message.content %></p>
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
          <form phx-submit="send_message">
            <div class="flex">
              <input name="message" type="text" placeholder="Type a message..." class="flex-1 p-2 border rounded-l-md" />
              <button type="submit" class="bg-blue-500 text-white p-2 rounded-r-md hover:bg-blue-600">Send</button>
            </div>
          </form>
        </div>
      </div>
    </div>
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
end