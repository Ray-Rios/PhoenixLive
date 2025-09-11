defmodule PhoenixAppWeb.ChatLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Chat
  alias Phoenix.PubSub
  import PhoenixAppWeb.Components.PageWrapper

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      text_channels = Chat.list_text_channels()
      voice_channels = Chat.list_voice_channels()
      default_channel = List.first(text_channels) || Chat.get_or_create_default_channel()
      
      # Subscribe to channel updates
      Phoenix.PubSub.subscribe(PhoenixApp.PubSub, "chat:channels")
      
      {:ok, assign(socket,
        text_channels: text_channels,
        voice_channels: voice_channels,
        current_channel: default_channel,
        messages: [],
        current_message: "",
        online_users: %{},
        typing_users: MapSet.new(),
        show_create_channel: false,
        channel_form: Chat.change_channel(%Chat.Channel{}),
        page_title: "Chat"
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_params(%{"channel_id" => channel_id}, _uri, socket) do
    channel = Chat.get_channel!(channel_id)
    messages = Chat.list_messages(channel_id)
    
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
      messages = Chat.list_messages(channel.id)
      
      # Subscribe to channel updates
      PubSub.subscribe(PhoenixApp.PubSub, "channel:#{channel.id}")
      
      {:noreply, assign(socket, messages: messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("send_message", %{"message" => content}, socket) when content != "" do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel
    
    case Chat.create_message(user, channel.id, %{content: content}) do
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
    message = Chat.get_message!(message_id)
    
    if message.user_id == socket.assigns.current_user.id do
      case Chat.update_message(message, %{content: content}) do
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
    message = Chat.get_message!(message_id)
    
    if message.user_id == socket.assigns.current_user.id do
      case Chat.delete_message(message) do
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
    message = Chat.get_message!(message_id)
    user = socket.assigns.current_user
    
    Chat.add_reaction(message, user, emoji)
    {:noreply, socket}
  end

  def handle_event("pin_message", %{"message_id" => message_id}, socket) do
    message = Chat.get_message!(message_id)
    
    case Chat.update_message(message, %{is_pinned: !message.is_pinned}) do
      {:ok, _updated_message} ->
        {:noreply, put_flash(socket, :info, if(message.is_pinned, do: "Message unpinned", else: "Message pinned"))}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to pin message")}
    end
  end

  # Channel CRUD Events
  def handle_event("show_create_channel", _params, socket) do
    {:noreply, assign(socket, show_create_channel: true)}
  end

  def handle_event("hide_create_channel", _params, socket) do
    {:noreply, assign(socket, show_create_channel: false, channel_form: Chat.change_channel(%Chat.Channel{}))}
  end

  def handle_event("validate_channel", %{"channel" => channel_params}, socket) do
    changeset = 
      %Chat.Channel{}
      |> Chat.change_channel(channel_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, channel_form: changeset)}
  end

  def handle_event("create_channel", %{"channel" => channel_params}, socket) do
    case Chat.create_channel(channel_params) do
      {:ok, channel} ->
        {:noreply, 
         socket
         |> assign(show_create_channel: false, channel_form: Chat.change_channel(%Chat.Channel{}))
         |> put_flash(:info, "Channel '#{channel.name}' created successfully!")
         |> push_navigate(to: ~p"/chat/#{channel.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, channel_form: changeset)}
    end
  end

  def handle_event("delete_channel", %{"channel_id" => channel_id}, socket) do
    channel = Chat.get_channel!(channel_id)
    
    # Don't allow deleting the general channel
    if channel.name == "general" do
      {:noreply, put_flash(socket, :error, "Cannot delete the general channel")}
    else
      case Chat.delete_channel(channel) do
        {:ok, _} ->
          # Redirect to general channel
          general_channel = Chat.get_or_create_default_channel()
          {:noreply, 
           socket
           |> put_flash(:info, "Channel '#{channel.name}' deleted")
           |> push_navigate(to: ~p"/chat/#{general_channel.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete channel")}
      end
    end
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
  def handle_info({:channel_created, channel}, socket) do
    text_channels = if channel.channel_type == "text", do: [channel | socket.assigns.text_channels], else: socket.assigns.text_channels
    voice_channels = if channel.channel_type in ["voice", "video"], do: [channel | socket.assigns.voice_channels], else: socket.assigns.voice_channels
    
    {:noreply, assign(socket, text_channels: text_channels, voice_channels: voice_channels)}
  end

  def handle_info({:channel_updated, channel}, socket) do
    text_channels = Enum.map(socket.assigns.text_channels, fn c -> if c.id == channel.id, do: channel, else: c end)
    voice_channels = Enum.map(socket.assigns.voice_channels, fn c -> if c.id == channel.id, do: channel, else: c end)
    
    current_channel = if socket.assigns.current_channel.id == channel.id, do: channel, else: socket.assigns.current_channel
    
    {:noreply, assign(socket, text_channels: text_channels, voice_channels: voice_channels, current_channel: current_channel)}
  end

  def handle_info({:channel_deleted, channel_id}, socket) do
    text_channels = Enum.reject(socket.assigns.text_channels, &(&1.id == channel_id))
    voice_channels = Enum.reject(socket.assigns.voice_channels, &(&1.id == channel_id))
    
    {:noreply, assign(socket, text_channels: text_channels, voice_channels: voice_channels)}
  end



  def render(assigns) do
    ~H"""
    <.page_with_navbar current_user={@current_user} flash={@flash}>
      <!-- Create Channel Modal -->
    <div :if={@show_create_channel} class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-gray-800 rounded-lg p-6 w-96">
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
          
          <div class="mb-6">
            <label class="block text-gray-300 text-sm font-medium mb-2">Channel Type</label>
            <.input field={@channel_form[:channel_type]} 
                    type="select" 
                    options={[{"Text Channel", "text"}, {"Voice Channel", "voice"}]}
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

    <div class="chat-container">
      
      <!-- Chat Sidebar -->
      <div class="chat-sidebar">
        <div class="p-4 border-b border-gray-700">
          <h2 class="text-white font-bold text-lg">Phoenix Chat</h2>
        </div>
        
        <!-- Text Channels -->
        <div class="p-4">
          <div class="flex items-center justify-between mb-2">
            <div class="text-gray-400 text-xs uppercase font-semibold">Text Channels</div>
            <button phx-click="show_create_channel" class="text-gray-400 hover:text-white text-lg">+</button>
          </div>
          <%= for channel <- @text_channels do %>
            <div class="group flex items-center justify-between px-2 py-1 rounded hover:bg-gray-700 transition-colors">
              <.link navigate={"/chat/#{channel.id}"} 
                     class={["flex items-center flex-1 text-gray-300 hover:text-white transition-colors",
                            if(@current_channel && @current_channel.id == channel.id, do: "text-white")]}>
                <span class="mr-2">#</span>
                <%= channel.name %>
              </.link>
              <%= if channel.name != "general" do %>
                <button phx-click="delete_channel" phx-value-channel_id={channel.id}
                        class="opacity-0 group-hover:opacity-100 text-gray-400 hover:text-red-400 text-sm ml-2"
                        onclick="return confirm('Are you sure you want to delete this channel?')">
                  ×
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
        
        <!-- Voice Channels -->
        <div class="p-4">
          <div class="flex items-center justify-between mb-2">
            <div class="text-gray-400 text-xs uppercase font-semibold">Voice Channels</div>
            <button class="text-gray-400 hover:text-white text-lg">+</button>
          </div>
          <%= for channel <- @voice_channels do %>
            <div class="flex items-center px-2 py-1 rounded text-gray-300 hover:bg-gray-700 hover:text-white transition-colors cursor-pointer">
              <span class="mr-2">🔊</span>
              <%= channel.name %>
            </div>
          <% end %>
          <%= if @voice_channels == [] do %>
            <div class="text-gray-500 text-sm italic px-2">No voice channels</div>
          <% end %>
        </div>
        
        <!-- User Info -->
        <div class="absolute bottom-0 left-0 right-0 bg-gray-800 p-3 flex items-center">
          <div class="w-8 h-8 rounded-full mr-3 flex items-center justify-center text-white text-sm"
               style={"background-color: #{@current_user.avatar_color}"}>
            <%= String.first(@current_user.name || @current_user.email) %>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-white text-sm font-medium truncate">
              <%= @current_user.name || @current_user.email %>
            </div>
            <div class="text-gray-400 text-xs">Online</div>
          </div>
          <button class="text-gray-400 hover:text-white">⚙️</button>
        </div>
      </div>

      <!-- Main Chat Area -->
      <div class="chat-main">
        <!-- Chat Header -->
        <div class="chat-header">
          <div class="flex items-center">
            <span class="text-gray-400 mr-2">#</span>
            <span class="font-semibold"><%= @current_channel.name %></span>
            <div :if={@current_channel.topic} class="ml-4 text-gray-400 text-sm">
              | <%= @current_channel.topic %>
            </div>
          </div>
          
          <div class="flex items-center space-x-2">
            <button class="text-gray-400 hover:text-white p-1">📌</button>
            <button class="text-gray-400 hover:text-white p-1">👥</button>
            <button class="text-gray-400 hover:text-white p-1">🔍</button>
            <button class="text-gray-400 hover:text-white p-1">📞</button>
            <button class="text-gray-400 hover:text-white p-1">🎥</button>
          </div>
        </div>

        <!-- Messages Area -->
        <div class="chat-messages" id="chat-messages" phx-hook="MessageReactions">
          <%= for message <- Enum.reverse(@messages) do %>
            <div class="message group hover:bg-gray-800 transition-colors">
              <div class="message-header">
                <div class="w-10 h-10 rounded-full mr-3 flex items-center justify-center text-white"
                     style={"background-color: #{message.user.avatar_color}"}>
                  <%= String.first(message.user.name || message.user.email) %>
                </div>
                <div>
                  <span class="message-author text-white"><%= message.user.name || message.user.email %></span>
                  <span class="message-timestamp">
                    <%= Calendar.strftime(message.inserted_at, "%m/%d/%Y %H:%M") %>
                  </span>
                  <span :if={message.edited_at} class="text-xs text-gray-500 ml-2">(edited)</span>
                </div>
                
                <!-- Message Actions (show on hover) -->
                <div class="ml-auto opacity-0 group-hover:opacity-100 transition-opacity flex space-x-1">
                  <button class="emoji-reaction text-gray-400 hover:text-white p-1" 
                          data-message-id={message.id} data-emoji="👍">👍</button>
                  <button class="emoji-reaction text-gray-400 hover:text-white p-1" 
                          data-message-id={message.id} data-emoji="❤️">❤️</button>
                  <button class="emoji-reaction text-gray-400 hover:text-white p-1" 
                          data-message-id={message.id} data-emoji="😂">😂</button>
                  
                  <%= if message.user_id == @current_user.id do %>
                    <button phx-click="edit_message" phx-value-message_id={message.id}
                            class="text-gray-400 hover:text-white p-1">✏️</button>
                    <button phx-click="delete_message" phx-value-message_id={message.id}
                            class="text-gray-400 hover:text-white p-1">🗑️</button>
                  <% end %>
                  
                  <button phx-click="pin_message" phx-value-message_id={message.id}
                          class="text-gray-400 hover:text-white p-1">📌</button>
                </div>
              </div>
              
              <div class="message-content ml-13">
                <%= message.content %>
                
                <!-- Message Reactions -->
                <div :if={message.reactions != []} class="flex flex-wrap gap-1 mt-2">
                  <%= for {emoji, count} <- group_reactions(message.reactions) do %>
                    <button class="bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded text-sm transition-colors"
                            phx-click="toggle_reaction" phx-value-message_id={message.id} phx-value-emoji={emoji}>
                      <%= emoji %> <%= count %>
                    </button>
                  <% end %>
                </div>
                
                <!-- Pinned Indicator -->
                <div :if={message.is_pinned} class="text-yellow-400 text-xs mt-1">📌 Pinned</div>
              </div>
            </div>
          <% end %>
          
          <!-- Typing Indicators -->
          <div :if={MapSet.size(@typing_users) > 0} class="text-gray-400 text-sm px-4 py-2">
            Someone is typing...
          </div>
        </div>

        <!-- Message Input -->
        <div class="chat-input">
          <form phx-submit="send_message" class="flex items-center space-x-2">
            <button type="button" class="text-gray-400 hover:text-white p-2">📎</button>
            
            <div class="flex-1 relative">
              <input type="text" name="message" value={@current_message}
                     phx-change="update_message"
                     placeholder={"Message ##{@current_channel.name}"}
                     class="w-full bg-gray-600 text-white px-4 py-3 rounded-lg border-none focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            
            <button type="button" class="text-gray-400 hover:text-white p-2">😀</button>
            <button type="button" class="text-gray-400 hover:text-white p-2">🎁</button>
            <button type="button" class="text-gray-400 hover:text-white p-2">🎵</button>
          </form>
        </div>
      </div>
    </div>
    </.page_with_navbar>
    """
  end

  defp group_reactions(reactions) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} -> {emoji, length(reactions)} end)
  end
end