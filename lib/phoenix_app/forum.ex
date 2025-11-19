defmodule PhoenixApp.Forum do
  @moduledoc """
  The Forum context for Discord-like messaging functionality.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Forum.{Channel, Message, Reaction, Thread}

  # Channels
  def list_channels do
    from(c in Channel, order_by: [asc: c.position, asc: c.name])
    |> Repo.all()
  end

  def list_text_channels do
    from(c in Channel, 
      where: c.channel_type == "text",
      order_by: [asc: c.position, asc: c.name]
    )
    |> Repo.all()
  end

  def list_voice_channels do
    from(c in Channel, 
      where: c.channel_type in ["voice", "video"],
      order_by: [asc: c.position, asc: c.name]
    )
    |> Repo.all()
  end

  def get_channel!(id) do
    Repo.get!(Channel, id)
  end

  def get_channel(id) do
    Repo.get(Channel, id)
  end

  def create_channel(attrs \\ %{}) do
    # Set position to be last
    max_position = from(c in Channel, select: max(c.position)) |> Repo.one() || 0
    
    # Ensure consistent key types - use string keys to match form params
    attrs = 
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()
      |> Map.put("position", max_position + 1)
    
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, channel} ->
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "chat:channels", {:channel_created, channel})
        {:ok, channel}
      error -> error
    end
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_channel} ->
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "chat:channels", {:channel_updated, updated_channel})
        {:ok, updated_channel}
      error -> error
    end
  end

  def delete_channel(%Channel{} = channel) do
    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "chat:channels", {:channel_deleted, channel.id})
    Repo.delete(channel)
  end

  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  def get_or_create_default_channel do
    case Repo.get_by(Channel, name: "general") do
      nil ->
        {:ok, channel} = create_channel(%{
          name: "general",
          description: "General discussion",
          channel_type: "text"
        })
        channel
      channel -> channel
    end
  end

  def list_user_channels(_user_id) do
    # Temporarily return empty list until created_by_id migration is applied
    # TODO: Restore original query after running migration:
    # from(c in Channel,
    #   where: c.created_by_id == ^user_id,
    #   order_by: [asc: c.position, asc: c.name]
    # )
    # |> Repo.all()
    []
  end

  def list_public_channels do
    from(c in Channel,
      where: c.is_private == false,
      order_by: [asc: c.position, asc: c.name]
    )
    |> Repo.all()
  end

  def create_user_channel(user, attrs) do
    # Set position to be last for user channels
    max_position = from(c in Channel, where: c.owner_id == ^user.id, select: max(c.position)) |> Repo.one() || 0

    attrs = Map.merge(attrs, %{
      "owner_id" => user.id,
      "position" => max_position + 1,
      "is_private" => Map.get(attrs, "is_private", false),
      "is_user_created" => true
    })

    create_channel(attrs)
  end

  # Messages
  def list_messages(channel_id, limit \\ 50) do
    from(m in Message, 
      where: m.channel_id == ^channel_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :reactions, :attachments, :thread]
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def list_messages_by_room(room_id, limit \\ 50) do
    from(m in Message, 
      where: m.room_id == ^room_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :reactions, :attachments, :thread]
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def get_message!(id) do
    Repo.get!(Message, id) |> Repo.preload([:user, :reactions, :attachments, :thread])
  end

  def create_message(user, channel_id, attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Ecto.Changeset.put_change(:channel_id, channel_id)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, [:user, :reactions, :attachments])
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{channel_id}", {:new_message, message})
        {:ok, message}
      error -> error
    end
  end

  @doc """
  Creates a message with attributes directly (for Social Hubs with room_id)
  """
  def create_message(attrs) when is_map(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, [:user, :reactions, :attachments])
        {:ok, message}
      error -> error
    end
  end

  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Ecto.Changeset.put_change(:edited_at, DateTime.utc_now())
    |> Repo.update()
    |> case do
      {:ok, updated_message} ->
        updated_message = Repo.preload(updated_message, [:user, :reactions, :attachments])
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{updated_message.channel_id}", {:message_updated, updated_message})
        {:ok, updated_message}
      error -> error
    end
  end

  def delete_message(%Message{} = message) do
    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:message_deleted, message.id})
    Repo.delete(message)
  end

  # Reactions
  def add_reaction(message, user, emoji) do
    case Repo.get_by(Reaction, message_id: message.id, user_id: user.id, emoji: emoji) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{message_id: message.id, user_id: user.id, emoji: emoji})
        |> Repo.insert()
        |> case do
          {:ok, reaction} ->
            Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:reaction_added, reaction})
            {:ok, reaction}
          error -> error
        end
      reaction ->
        {:ok, reaction}
    end
  end

  def remove_reaction(message, user, emoji) do
    case Repo.get_by(Reaction, message_id: message.id, user_id: user.id, emoji: emoji) do
      nil -> {:error, :not_found}
      reaction ->
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:reaction_removed, reaction})
        Repo.delete(reaction)
    end
  end

  # Threads
  def create_thread(message, user, attrs \\ %{}) do
    %Thread{}
    |> Thread.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:message, message)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def list_thread_messages(thread_id, limit \\ 50) do
    from(m in Message, 
      where: m.thread_id == ^thread_id,
      order_by: [asc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :reactions, :attachments]
    )
    |> Repo.all()
  end

  # Search
  def search_messages(channel_id, query) do
    search_term = "%#{query}%"
    
    from(m in Message,
      where: m.channel_id == ^channel_id and ilike(m.content, ^search_term),
      order_by: [desc: m.inserted_at],
      limit: 20,
      preload: [:user]
    )
    |> Repo.all()
  end

  def count_messages_in_channel(channel_id) do
    from(m in Message, where: m.channel_id == ^channel_id, select: count())
    |> Repo.one()
  end

  # ============================================
  # User-Created Channels
  # ============================================

  def list_user_owned_channels(user_id) do
    from(c in Channel,
      where: c.owner_id == ^user_id and c.is_user_created == true,
      order_by: [desc: c.inserted_at],
      preload: [:owner, :members]
    )
    |> Repo.all()
  end

  def list_user_member_channels(user_id) do
    from(m in PhoenixApp.Forum.ChannelMember,
      where: m.user_id == ^user_id,
      join: c in assoc(m, :channel),
      where: c.is_user_created == true,
      preload: [channel: [:owner, :members]],
      order_by: [desc: m.joined_at]
    )
    |> Repo.all()
    |> Enum.map(& &1.channel)
  end

  def list_public_user_channels do
    from(c in Channel,
      where: c.is_public == true and c.is_user_created == true,
      order_by: [desc: c.inserted_at],
      preload: [:owner, :members]
    )
    |> Repo.all()
  end

  def create_user_channel(attrs \\ %{}) do
    # Auto-set is_user_created flag
    attrs = Map.put(attrs, :is_user_created, true)
    
    Repo.transaction(fn ->
      # Create the channel
      channel = case create_channel(attrs) do
        {:ok, channel} -> channel
        {:error, changeset} -> Repo.rollback(changeset)
      end

      # Auto-create owner membership
      owner_attrs = %{
        channel_id: channel.id,
        user_id: attrs.owner_id || attrs["owner_id"],
        role: "owner",
        joined_at: DateTime.utc_now()
      }

      case create_channel_member(owner_attrs) do
        {:ok, _member} -> channel
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # ============================================
  # Channel Members
  # ============================================

  alias PhoenixApp.Forum.ChannelMember

  def is_channel_member?(channel_id, user_id) do
    Repo.exists?(from m in ChannelMember, where: m.channel_id == ^channel_id and m.user_id == ^user_id)
  end

  def get_channel_member(channel_id, user_id) do
    Repo.get_by(ChannelMember, channel_id: channel_id, user_id: user_id)
  end

  def create_channel_member(attrs \\ %{}) do
    %ChannelMember{}
    |> ChannelMember.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel_member(%ChannelMember{} = member, attrs) do
    member
    |> ChannelMember.changeset(attrs)
    |> Repo.update()
  end

  def remove_channel_member(channel_id, user_id) do
    case get_channel_member(channel_id, user_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  def list_channel_members(channel_id) do
    from(m in ChannelMember,
      where: m.channel_id == ^channel_id,
      preload: [:user],
      order_by: [asc: m.joined_at]
    )
    |> Repo.all()
  end

  # ============================================
  # Channel Invites
  # ============================================

  alias PhoenixApp.Forum.ChannelInvite

  def create_channel_invite(attrs \\ %{}) do
    %ChannelInvite{}
    |> ChannelInvite.changeset(attrs)
    |> Repo.insert()
  end

  def get_invite_by_code(code) do
    Repo.get_by(ChannelInvite, code: code)
    |> Repo.preload([:channel, :inviter])
  end

  def use_channel_invite(code, user_id) do
    case get_invite_by_code(code) do
      nil ->
        {:error, :invalid_invite}
      
      invite ->
        if ChannelInvite.is_valid?(invite) do
          # Check if already a member
          if is_channel_member?(invite.channel_id, user_id) do
            {:error, :already_member}
          else
            Repo.transaction(fn ->
              # Add user as member
              case create_channel_member(%{
                channel_id: invite.channel_id,
                user_id: user_id,
                role: "member"
              }) do
                {:ok, member} ->
                  # Increment invite usage
                  invite
                  |> Ecto.Changeset.change(uses: invite.uses + 1)
                  |> Repo.update!()
                  
                  member
                
                {:error, changeset} ->
                  Repo.rollback(changeset)
              end
            end)
          end
        else
          {:error, :invite_expired}
        end
    end
  end

  # ============================================
  # Streaming Sessions
  # ============================================

  alias PhoenixApp.Forum.StreamingSession

  def start_stream(attrs \\ %{}) do
    %StreamingSession{}
    |> StreamingSession.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} ->
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{session.channel_id}", {:stream_started, session})
        {:ok, session}
      error -> error
    end
  end

  def end_stream(session_id) do
    case Repo.get(StreamingSession, session_id) do
      nil -> {:error, :not_found}
      session ->
        session
        |> StreamingSession.changeset(%{is_active: false, ended_at: DateTime.utc_now()})
        |> Repo.update()
        |> case do
          {:ok, updated_session} ->
            Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{session.channel_id}", :stream_ended)
            {:ok, updated_session}
          error -> error
        end
    end
  end

  def get_active_stream(channel_id) do
    from(s in StreamingSession,
      where: s.channel_id == ^channel_id and s.is_active == true,
      preload: [:streamer],
      limit: 1
    )
    |> Repo.one()
  end

  def update_stream_viewer_count(session_id, count) do
    case Repo.get(StreamingSession, session_id) do
      nil -> {:error, :not_found}
      session ->
        session
        |> StreamingSession.changeset(%{viewer_count: count})
        |> Repo.update()
    end
  end

  def list_channel_streams(channel_id, limit \\ 10) do
    from(s in StreamingSession,
      where: s.channel_id == ^channel_id,
      order_by: [desc: s.started_at],
      limit: ^limit,
      preload: [:streamer]
    )
    |> Repo.all()
  end
end