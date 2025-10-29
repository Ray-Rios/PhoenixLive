defmodule PhoenixAppWeb.ForumLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Forum
  alias PhoenixApp.Content.Media
  alias Phoenix.PubSub

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      channels = Forum.list_channels()
      
      # Ensure we have at least a default channel
      default_channel = if Enum.empty?(channels) do
        Forum.get_or_create_default_channel()
      else
        List.first(channels)
      end

      # Subscribe to channel updates
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "chat:channels")

      socket = assign(socket,
        channels: if(Enum.empty?(channels), do: [default_channel], else: channels),
        current_channel: default_channel,
        messages: Forum.list_messages(default_channel.id),
        current_message: "",
        online_users: %{},
        typing_users: MapSet.new(),
        show_create_channel: false,
        channel_form: Forum.change_channel(%Forum.Channel{}),
        page_title: "Forum - #{default_channel.name}",
        user_channels: Forum.list_user_channels(user.id),
        public_channels: Forum.list_public_channels(),
        show_channel_modal: false,
        editing_channel: nil,
        message_attachments: [],
        show_attachments: false
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

  def handle_params(%{"channel_id" => channel_id}, _uri, socket) do
    channel = Forum.get_channel!(channel_id)
    messages = Forum.list_messages(channel_id)
    
    # Unsubscribe from previous channel
    if socket.assigns[:current_channel] do
      PubSub.unsubscribe(PhoenixApp.PubSub, "channel:#{socket.assigns.current_channel.id}")
    end
    
    # Subscribe to new channel
    PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel_id}")
    
    {:noreply, assign(socket,
      current_channel: channel,
      messages: messages,
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

  def handle_event("send_message", %{"message" => content} = _params, socket) when content != "" do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel

    # Handle file uploads first
    uploaded_files = consume_uploaded_entries(socket, :forum_attachment, fn %{path: path}, entry ->
      # Save file to user's upload directory
      dest_dir = Path.join(["uploads", "users", user.id, "forum", channel.id])
      File.mkdir_p!(dest_dir)

      filename = "#{System.unique_integer([:positive])}#{Path.extname(entry.client_name)}"
      dest_path = Path.join(dest_dir, filename)

      File.cp!(path, dest_path)

      # Create media record
      {:ok, media} = Media.create_media(user, %{
        "filename" => filename,
        "original_filename" => entry.client_name,
        "file_type" => determine_file_type(entry.client_type),
        "mime_type" => entry.client_type,
        "file_size" => entry.client_size,
        "file_path" => dest_path,
        "url" => "/#{dest_path}",
        "is_public" => !channel.is_private
      })

      media
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

  def handle_event("pin_message", %{"message_id" => message_id}, socket) do
    message = Forum.get_message!(message_id)
    
    case Forum.update_message(message, %{is_pinned: !message.is_pinned}) do
      {:ok, _updated_message} ->
        {:noreply, put_flash(socket, :info, if(message.is_pinned, do: "Message unpinned", else: "Message pinned"))}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to pin message")}
    end
  end

  # Channel CRUD Events
  def handle_event("show_create_channel", _params, socket) do
    user = socket.assigns.current_user
    
    if user && (user.is_admin || user.role in ["admin", "gm", "editor"]) do
      {:noreply, assign(socket, show_create_channel: true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to create channels.")}
    end
  end

  def handle_event("hide_create_channel", _params, socket) do
    {:noreply, assign(socket, show_create_channel: false, channel_form: Forum.change_channel(%Forum.Channel{}))}
  end

  def handle_event("validate_channel", %{"channel" => channel_params}, socket) do
    changeset = 
      %Forum.Channel{}
      |> Forum.change_channel(channel_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, channel_form: changeset)}
  end

  def handle_event("create_channel", %{"channel" => channel_params}, socket) do
    user = socket.assigns.current_user
    
    # Check if user has permission to create channels
    if user && (user.is_admin || user.role in ["admin", "gm", "editor"]) do
      case Forum.create_user_channel(user, channel_params) do
        {:ok, channel} ->
          channels = Forum.list_channels()
          user_channels = Forum.list_user_channels(user.id)
          public_channels = Forum.list_public_channels()

          {:noreply,
           socket
           |> assign(show_create_channel: false, channel_form: Forum.change_channel(%Forum.Channel{}))
           |> assign(channels: channels, user_channels: user_channels, public_channels: public_channels)
           |> put_flash(:info, "Channel '#{channel.name}' created successfully!")}

        {:error, changeset} ->
          {:noreply, assign(socket, channel_form: changeset)}
      end
    else
      {:noreply,
       socket
       |> assign(show_create_channel: false)
       |> put_flash(:error, "You don't have permission to create channels. Contact an admin.")}
    end
  end

  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    channel = Forum.get_channel!(channel_id)
    
    # Don't allow deleting the general channel
    if channel.name == "general" do
      {:noreply, put_flash(socket, :error, "Cannot delete the general channel")}
    else
      case Forum.delete_channel(channel) do
        {:ok, _} ->
          # Redirect to general channel
          general_channel = Forum.get_or_create_default_channel()
          {:noreply, 
           socket
           |> put_flash(:info, "Channel '#{channel.name}' deleted")
           |> push_navigate(to: ~p"/forum/#{general_channel.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete channel")}
      end
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

  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(100)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_updated, message}, socket) do
    messages = Enum.map(socket.assigns.messages, fn msg ->
      if msg.id == message.id, do: message, else: msg
    end)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_deleted, message_id}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:reaction_added, reaction}, socket) do
    messages = Enum.map(socket.assigns.messages, fn msg ->
      if msg.id == reaction.message_id do
        %{msg | reactions: [reaction | msg.reactions]}
      else
        msg
      end
    end)
    {:noreply, assign(socket, messages: messages)}
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

  # Channel PubSub handlers
  def handle_info({:channel_created, _channel}, socket) do
    user = socket.assigns.current_user
    user_channels = Forum.list_user_channels(user.id)
    public_channels = Forum.list_public_channels()

    {:noreply, assign(socket, user_channels: user_channels, public_channels: public_channels)}
  end

  def handle_info({:channel_updated, channel}, socket) do
    user = socket.assigns.current_user
    user_channels = Forum.list_user_channels(user.id)
    public_channels = Forum.list_public_channels()

    current_channel = if socket.assigns.current_channel.id == channel.id, do: channel, else: socket.assigns.current_channel

    {:noreply, assign(socket, user_channels: user_channels, public_channels: public_channels, current_channel: current_channel)}
  end

  def handle_info({:channel_deleted, channel_id}, socket) do
    user = socket.assigns.current_user
    user_channels = Forum.list_user_channels(user.id)
    public_channels = Forum.list_public_channels()

    # If current channel was deleted, redirect to general
    if socket.assigns.current_channel.id == channel_id do
      general_channel = Forum.get_or_create_default_channel()
      {:noreply, socket
               |> assign(user_channels: user_channels, public_channels: public_channels, current_channel: general_channel)
               |> push_navigate(to: ~p"/forum/#{general_channel.id}")}
    else
      {:noreply, assign(socket, user_channels: user_channels, public_channels: public_channels)}
    end
  end



  def render(assigns) do
    ~H"""
    <div class="min-h-screen pointer-events-none">
      <div class="max-w-7xl mx-auto px-4 py-8 pointer-events-auto">
        <div class="auth-glass-panel p-8 rounded-xl">
          <!-- Forum Header -->
          <div class="mb-8">
            <div class="flex justify-between items-center">
              <div>
                <h1 class="text-3xl font-bold text-white mb-2">Community Forum</h1>
                <p class="text-gray-400">Discuss, share, and connect with the community</p>
              </div>
              <%= if @current_user && (@current_user.is_admin || @current_user.role in ["admin", "gm", "editor"]) do %>
                <button
                  phx-click="show_create_channel"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors"
                >
                  📝 Create Channel
                </button>
              <% end %>
            </div>
          </div>

          <!-- Create Channel Modal -->
          <div :if={@show_create_channel} class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div class="bg-gray-800 rounded-lg p-6 w-96 max-w-md mx-4">
              <h3 class="text-white text-lg font-semibold mb-4">Create Channel</h3>

              <.form for={@channel_form} phx-submit="create_channel" phx-change="validate_channel">
                <div class="mb-4">
                  <label class="block text-gray-300 text-sm font-medium mb-2">Channel Name</label>
                  <.input field={@channel_form[:name]}
                          type="text"
                          placeholder="channel-name"
                          class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                </div>

                <div class="mb-4">
                  <label class="block text-gray-300 text-sm font-medium mb-2">Description (Optional)</label>
                  <.input field={@channel_form[:description]}
                          type="text"
                          placeholder="What's this channel about?"
                          class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                </div>

                <div class="mb-4">
                  <label class="block text-gray-300 text-sm font-medium mb-2">Channel Type</label>
                  <.input field={@channel_form[:channel_type]}
                          type="select"
                          options={[{"Public Channel", "public"}, {"Private Channel", "private"}]}
                          class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" />
                </div>

                <div class="flex justify-end space-x-3">
                  <button type="button" phx-click="hide_create_channel"
                          class="px-4 py-2 text-gray-300 hover:text-white transition-colors">
                    Cancel
                  </button>
                  <button type="submit"
                          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors">
                    Create Channel
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <!-- Forum Layout -->
          <div class="grid grid-cols-12 gap-6">
            <!-- Sidebar -->
            <div class="col-span-3">
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-white font-semibold mb-4">Channels</h3>

                <!-- Public Channels -->
                <div class="mb-6">
                  <h4 class="text-gray-400 text-sm font-medium mb-2 uppercase">Public Channels</h4>
                  <div class="space-y-1">
                    <%= for channel <- @public_channels do %>
                      <div class="group flex items-center justify-between px-2 py-1 rounded hover:bg-gray-700 transition-colors">
                        <.link navigate={"/forum/#{channel.id}"}
                               class={["flex items-center flex-1 text-gray-300 hover:text-white transition-colors",
                                      if(@current_channel && @current_channel.id == channel.id, do: "text-white bg-gray-700")]}>
                          <span class="mr-2">#</span>
                          <%= channel.name %>
                        </.link>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Your Channels -->
                <div>
                  <h4 class="text-gray-400 text-sm font-medium mb-2 uppercase">Your Channels</h4>
                  <div class="space-y-1">
                    <%= for channel <- @user_channels do %>
                      <div class="group flex items-center justify-between px-2 py-1 rounded hover:bg-gray-700 transition-colors">
                        <.link navigate={"/forum/#{channel.id}"}
                               class={["flex items-center flex-1 text-gray-300 hover:text-white transition-colors",
                                      if(@current_channel && @current_channel.id == channel.id, do: "text-white bg-gray-700")]}>
                          <span class="mr-2">#</span>
                          <%= channel.name %>
                        </.link>
                        <%= if channel.user_id == @current_user.id do %>
                          <button phx-click="delete_channel" phx-value-channel_id={channel.id}
                                  class="opacity-0 group-hover:opacity-100 text-gray-400 hover:text-red-400 text-sm ml-2"
                                  onclick="return confirm('Are you sure you want to delete this channel?')">
                            ×
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Main Content -->
            <div class="col-span-9">
              <%= if @current_channel do %>
                <!-- Channel Detail View -->
                <div class="bg-gray-800 rounded-lg overflow-hidden">
                  <!-- Channel Header -->
                  <div class="p-4 border-b border-gray-700">
                    <div class="flex items-center justify-between">
                      <div>
                        <h2 class="text-white text-xl font-semibold">#<%= @current_channel.name %></h2>
                        <%= if @current_channel.description do %>
                          <p class="text-gray-400 text-sm mt-1"><%= @current_channel.description %></p>
                        <% end %>
                      </div>
                      <div class="flex items-center space-x-2">
                        <button phx-click="toggle_uploads" class="text-gray-400 hover:text-white px-3 py-1 rounded transition-colors">
                          📎 Uploads
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Messages Area -->
                  <div class="flex-1 overflow-y-auto p-4 space-y-4" style="max-height: 60vh;">
                    <%= for message <- Enum.reverse(@messages) do %>
                      <div class="flex space-x-3">
                        <div class="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm flex-shrink-0"
                             style={"background-color: #{message.user.avatar_color}"}>
                          <%= String.first(message.user.name || message.user.email) %>
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center space-x-2 mb-1">
                            <span class="text-white font-medium"><%= message.user.name || message.user.email %></span>
                            <span class="text-gray-500 text-sm">
                              <%= Calendar.strftime(message.inserted_at, "%m/%d/%Y %H:%M") %>
                            </span>
                            <%= if message.edited_at do %>
                              <span class="text-gray-500 text-xs">(edited)</span>
                            <% end %>
                          </div>
                          <div class="text-gray-300 prose prose-invert max-w-none">
                            <%= message.content %>
                          </div>

                          <!-- Message Attachments -->
                          <%= if message.attachments && length(message.attachments) > 0 do %>
                            <div class="mt-3 space-y-2">
                              <%= for attachment <- message.attachments do %>
                                <div class="flex items-center space-x-3 bg-gray-700 rounded p-3">
                                  <span class="text-2xl"><%= file_type_icon(attachment.file_type) %></span>
                                  <div class="flex-1 min-w-0">
                                    <div class="text-white text-sm font-medium truncate"><%= attachment.original_filename %></div>
                                    <div class="text-gray-400 text-xs"><%= format_bytes(attachment.file_size) %></div>
                                  </div>
                                  <a href={attachment.url} target="_blank" class="text-blue-400 hover:text-blue-300 text-sm">View</a>
                                </div>
                              <% end %>
                            </div>
                          <% end %>

                          <!-- Message Reactions -->
                          <%= if message.reactions && length(message.reactions) > 0 do %>
                            <div class="flex flex-wrap gap-1 mt-2">
                              <%= for {emoji, count} <- group_reactions(message.reactions) do %>
                                <button class="bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded text-sm transition-colors"
                                        phx-click="toggle_reaction" phx-value-message_id={message.id} phx-value-emoji={emoji}>
                                  <%= emoji %> <%= count %>
                                </button>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <!-- Uploads Section -->
                                    <!-- Uploads Section -->
                  <%= if @show_attachments do %>
                    <div class="border-t border-gray-700 p-4">
                      <h4 class="text-white font-medium mb-3">Upload Files</h4>
                      <form phx-submit="upload_files" class="space-y-4">
                        <.live_file_input upload={@uploads.forum_attachment} class="block w-full text-white" />

                        <div class="flex justify-end space-x-2">
                          <button type="button" phx-click="cancel_upload" class="px-4 py-2 text-gray-300 hover:text-white transition-colors">
                            Cancel
                          </button>
                          <button type="submit" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors">
                            Upload
                          </button>
                        </div>
                      </form>
                    </div>
                  <% end %>

                  <!-- Message Input -->
                  <div class="border-t border-gray-700 p-4">
                    <form phx-submit="send_message" class="flex items-end space-x-3">
                      <div class="flex-1">
                        <textarea name="message"
                                  id="message-input"
                                  phx-debounce="300"
                                  placeholder="Type your message... (Press Enter to send, Shift+Enter for new line)"
                                  rows="1"
                                  class="w-full bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none resize-none"
                                  phx-hook="ChatInput"></textarea>
                      </div>
                      <button type="button"
                              phx-click="toggle_uploads"
                              class="text-gray-400 hover:text-white p-3 rounded-lg hover:bg-gray-700 transition-colors">
                        📎
                      </button>
                      <button type="submit"
                              class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors">
                        Send
                      </button>
                    </form>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  defp group_reactions(reactions) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} -> {emoji, length(reactions)} end)
  end

  defp determine_file_type(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      mime_type in ["model/gltf+json", "model/gltf-binary", "application/octet-stream"] -> "3d"
      mime_type in ["application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"] -> "document"
      String.starts_with?(mime_type, "application/") -> "document"
      true -> "other"
    end
  end

  defp file_type_icon("image"), do: "🖼️"
  defp file_type_icon("video"), do: "🎥"
  defp file_type_icon("audio"), do: "🎵"
  defp file_type_icon("3d"), do: "🎲"
  defp file_type_icon("document"), do: "📄"
  defp file_type_icon(_), do: "📁"

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
end