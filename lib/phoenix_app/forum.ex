defmodule PhoenixApp.Forum do
  @moduledoc """
  The Forum context for Discord-like messaging functionality.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Forum.{Channel, Message, Reaction, Thread, ChannelMember, ChannelInvite}

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
    # Protect the General channel from deletion
    if String.downcase(channel.name) == "general" do
      {:error, :protected_channel}
    else
      # Start transaction to ensure all-or-nothing deletion
      Repo.transaction(fn ->
        # 1. Get all messages in this channel with their attachments
        messages = from(m in Message,
          where: m.channel_id == ^channel.id,
          preload: [:attachments]
        ) |> Repo.all()

        # 2. Collect all attachment URL paths for cleanup (cleaner than reconstructing FS paths)
        attachment_file_paths =
          messages
          |> Enum.flat_map(& &1.attachments)
          |> Enum.map(fn attachment -> attachment.file end)
          |> Enum.filter(& &1)

        # 3. Delete all reactions for messages in this channel
        from(r in Reaction, 
          join: m in Message, on: r.message_id == m.id,
          where: m.channel_id == ^channel.id
        ) |> Repo.delete_all()

        # 4. Delete all threads in this channel (can delete directly by channel_id)
        from(t in Thread, where: t.channel_id == ^channel.id) |> Repo.delete_all()

        # 5. Delete all messages in this channel (this cascades to attachments via DB)
        from(m in Message, where: m.channel_id == ^channel.id) |> Repo.delete_all()

        # 6. Delete the channel itself
        case Repo.delete(channel) do
          {:ok, deleted_channel} ->
            # 7. Broadcast channel deletion
            Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "chat:channels", {:channel_deleted, deleted_channel.id})
            
            # 8. Queue background job to delete files and channel directories from filesystem
            Task.start(fn ->
              # Delete individual attachment files
              Enum.each(attachment_file_paths, fn url_path ->
                PhoenixApp.Uploads.delete_file(url_path)
              end)
              
              # Delete channel directory for each user who uploaded to this channel
              # Extract unique user_ids from attachment paths
              user_dirs = attachment_file_paths
                |> Enum.map(fn path ->
                  # Extract user_id from path: /uploads/{user_id}/forum/{channel_id}/...
                  case String.split(path, "/", parts: 5) do
                    ["", "uploads", user_id, "forum", _] -> user_id
                    _ -> nil
                  end
                end)
                |> Enum.filter(& &1)
                |> Enum.uniq()
              
              # Remove channel directories for each user
              Enum.each(user_dirs, fn user_id ->
                channel_dir = Path.join([PhoenixApp.Uploads.base_dir(), user_id, "forum", deleted_channel.id])
                File.rm_rf(channel_dir)
              end)
            end)

            deleted_channel

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc "Delete a channel with permission checks for a user. Owners/creators, admins, and editors are allowed."
  def delete_channel_by_user(%{id: user_id} = user, %Channel{} = channel) do
    if String.downcase(channel.name) == "general" do
      {:error, :protected_channel}
    else
      can_delete = (Map.has_key?(channel, :owner_id) && channel.owner_id == user_id) ||
                   (Map.has_key?(channel, :created_by_id) && channel.created_by_id == user_id) ||
                   Map.get(user, :is_admin, false) ||
                   user.role in ["admin", "gm", "editor"]

      if can_delete do
        delete_channel(channel)
      else
        {:error, :forbidden}
      end
    end
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
    # Normalize attrs + set position for user channels
    max_position = from(c in Channel, where: c.owner_id == ^user.id, select: max(c.position)) |> Repo.one() || 0

    # Ensure we interpret is_private when provided as strings from forms
    is_private = case Map.get(attrs, "is_private") do
      "true" -> true
      "on" -> true
      true -> true
      _ -> false
    end

    attrs = Map.merge(attrs, %{
      "owner_id" => user.id,
      "created_by_id" => user.id,
      "position" => max_position + 1,
      "is_private" => is_private,
      "is_public" => !is_private,
      "is_user_created" => true
    })

    Repo.transaction(fn ->
      # Create the channel
      channel = case create_channel(attrs) do
        {:ok, channel} -> channel
        {:error, changeset} -> Repo.rollback(changeset)
      end

      # Auto-create owner membership
      owner_attrs = %{
        channel_id: channel.id,
        user_id: user.id,
        role: "owner",
        joined_at: DateTime.utc_now()
      }

      case create_channel_member(owner_attrs) do
        {:ok, _member} -> channel
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Messages
  def list_messages(channel_id, limit \\ 50) do
    from(m in Message,
      join: u in assoc(m, :user),
      where: m.channel_id == ^channel_id,
      where: is_nil(u.role) or u.role != "banned",
      order_by: [asc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :reactions, :thread, attachments: :user]
    )
    |> Repo.all()
    |> Enum.map(fn m ->
      # Filter attachments uploaded by banned users
      filtered_attachments = Enum.filter(m.attachments || [], fn att ->
        case att do
          %{user_id: nil} -> true
          %{user: u} when not is_nil(u) -> is_nil(u.role) or u.role != "banned"
          _ -> true
        end
      end)

      %{m | attachments: filtered_attachments}
    end)
    # messages are returned ordered oldest -> newest already (ascending inserted_at)
    |> Enum.map(& &1)
  end

  def list_messages_by_room(room_id, limit \\ 50) do
    from(m in Message,
      where: m.room_id == ^room_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :reactions, :thread, attachments: :user]
    )
    |> Enum.map(fn m ->
      filtered_attachments = Enum.filter(m.attachments || [], fn att ->
        case att do
          %{user_id: nil} -> true
          %{user: u} when not is_nil(u) -> is_nil(u.role) or u.role != "banned"
          _ -> true
        end
      end)

      %{m | attachments: filtered_attachments}
    end)
    # Ensure chronological order (oldest -> newest)
    |> Enum.map(& &1)
  end

  def get_message!(id) do
    Repo.get!(Message, id) |> Repo.preload([:user, :reactions, :thread, attachments: :user])
  end

  def create_message(user, channel_id, attrs \\ %{}) do
    # Defensive check - disallow banned users from creating messages
    if user && Map.get(user, :role) == "banned" do
      {:error, :banned}
    else
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
    |> Ecto.Changeset.put_change(:edited_at, DateTime.truncate(DateTime.utc_now(), :second))
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
    # Preload attachments so we can clean up files
    message = Repo.preload(message, [:attachments])

    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:message_deleted, message.id})

    # Collect attachment paths for cleanup before deletion
    attachment_paths = message.attachments |> Enum.map(fn att -> att.file end) |> Enum.filter(& &1)

    # Delete DB record (attachments are set to delete_all via migration/associations)
    result = Repo.delete(message)

    # Cleanup files asynchronously via Uploads.delete_file (handles URL->FS mapping)
    if length(attachment_paths) > 0 do
      Task.start(fn ->
        Enum.each(attachment_paths, fn url_path ->
          PhoenixApp.Uploads.delete_file(url_path)
        end)
      end)
    end

    result
  end

  @doc "Delete a message with permission check for a given user (admins/editors or owner)."
  def delete_message_by_user(%{id: user_id} = user, %Message{} = message) do
    can_delete = message.user_id == user_id || Map.get(user, :is_admin, false) || user.role in ["admin", "gm", "editor"]

    if can_delete do
      delete_message(message)
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Create a message attachment that belongs to a message and channel.
  Accepts attrs: filename, content_type, file_size, file (url/path), user_id
  """
  def create_message_attachment(%Message{} = message, attrs) do
    attrs = attrs
            |> Map.put("message_id", message.id)
            |> Map.put("channel_id", message.channel_id)

    %PhoenixApp.Forum.MessageAttachment{}
    |> PhoenixApp.Forum.MessageAttachment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, attachment} ->
        # Broadcast message updated so clients can refresh attachments
        updated = get_message!(message.id)
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:message_updated, updated})
        {:ok, attachment}
      error -> error
    end
  end

  def get_attachment!(id) do
    Repo.get!(PhoenixApp.Forum.MessageAttachment, id) |> Repo.preload([:message, :user, :channel])
  end

  def delete_attachment(%PhoenixApp.Forum.MessageAttachment{} = attachment) do
    # Broadcast update to update message attachments on clients
    message = Repo.preload(attachment, [:message]) |> Map.get(:message)

    # Capture file path/url for deletion
    file_path = attachment.file

    result = Repo.delete(attachment)

    # Cleanup file if exists
    if file_path do
      Task.start(fn -> PhoenixApp.Uploads.delete_file(file_path) end)
    end

    if message do
      Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "channel:#{message.channel_id}", {:message_updated, get_message!(message.id)})
    end

    result
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
      preload: [:user, :reactions, attachments: :user]
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

  # Note: use create_user_channel(user, attrs) which creates the channel and owner membership

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

  def get_channel_member_by_id(id) do
    Repo.get(ChannelMember, id) |> Repo.preload(:user)
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
    # Base members from channel_members table
    members =
      from(m in ChannelMember,
        where: m.channel_id == ^channel_id,
        preload: [:user],
        order_by: [asc: m.joined_at]
      )
      |> Repo.all()

    # Ensure channel owner appears in the list (may not have a ChannelMember row)
    channel = Repo.get(Channel, channel_id)

    owner_member =
      if channel && channel.owner_id do
        owner_present = Enum.any?(members, fn m -> Map.get(m, :user_id) == channel.owner_id end)

        if owner_present do
          []
        else
          case Repo.get(PhoenixApp.Accounts.User, channel.owner_id) do
            nil -> []
            owner_user ->
              [%ChannelMember{channel_id: channel.id, user_id: owner_user.id, role: "owner", user: owner_user, id: nil, joined_at: channel.inserted_at}]
          end
        end
      else
        []
      end

    # Include any pending channel invites (targeted invitee_id present, not accepted, not revoked)
    pending_invites =
      from(i in ChannelInvite,
        where: i.channel_id == ^channel_id and not i.is_revoked and is_nil(i.accepted_at) and not is_nil(i.invitee_id),
        preload: [:invitee, :inviter]
      )
      |> Repo.all()

    invite_members =
      Enum.map(pending_invites, fn invite ->
        %ChannelMember{channel_id: channel_id, user_id: invite.invitee_id, role: "invited", user: invite.invitee, id: nil, joined_at: invite.inserted_at}
        |> Map.put(:_invite_id, invite.id)
      end)

    members ++ owner_member ++ invite_members
  end

  # Permission helpers
  @doc "Return the role string for a user in a channel (or nil if not a member)."
  def user_role_in_channel(channel_id, user_id) do
    case get_channel_member(channel_id, user_id) do
      nil -> nil
      %ChannelMember{role: role} -> role
    end
  end

  @doc "Returns true if the user can fully manage the channel (owner, channel creator, or site admin)."
  def can_manage_channel?(nil, _channel), do: false
  def can_manage_channel?(%{id: user_id} = user, %Channel{} = channel) do
    is_admin = Map.get(user, :is_admin, false) || Map.get(user, :role) in ["admin", "gm", "editor"]
    is_owner = Map.get(channel, :owner_id) == user_id
    is_creator = Map.get(channel, :created_by_id) == user_id

    cond do
      is_admin -> true
      is_owner -> true
      is_creator -> true
      true -> user_role_in_channel(channel.id, user_id) == "owner"
    end
  end

  @doc "Returns true if the user can moderate a channel (owner, moderator, or site admin)."
  def can_moderate_channel?(nil, _channel), do: false
  def can_moderate_channel?(%{id: user_id} = user, %Channel{} = channel) do
    is_admin = Map.get(user, :is_admin, false) || Map.get(user, :role) in ["admin", "gm", "editor"]

    if is_admin do
      true
    else
      member_role = user_role_in_channel(channel.id, user_id)
      member_role in ["owner", "moderator"]
    end
  end

  @doc "Returns true if a user is allowed to post in a channel.
  - Private channels: must be a member and not banned
  - Public channels: disallow site-level 'banned' users"
  def can_post_in_channel?(nil, %Channel{} = channel) do
    # anonymous users cannot post in private channels
    !channel.is_private
  end

  def can_post_in_channel?(%{id: user_id} = user, %Channel{} = channel) do
    # site level ban prevents posting anywhere
    if Map.get(user, :role) == "banned" do
      false
    else
      if channel.is_private do
        case get_channel_member(channel.id, user_id) do
          %ChannelMember{is_banned: true} -> false
          %ChannelMember{} -> true
          nil -> false
        end
      else
        true
      end
    end
  end

  @doc "Returns true if a user can create invites for a channel.
  Owners and moderators can always invite; members can invite if channel is public/user-created (configurable later)."
  def can_invite_to_channel?(nil, _channel), do: false
  def can_invite_to_channel?(%{id: user_id} = user, %Channel{} = channel) do
    # site admins always can
    is_admin = Map.get(user, :is_admin, false) || Map.get(user, :role) in ["admin", "gm", "editor"]

    cond do
      is_admin -> true
      true ->
        member = get_channel_member(channel.id, user_id)
        cond do
          member == nil -> false
          member.is_banned -> false
          member.role in ["owner", "moderator"] -> true
          # allow regular members to invite to public user-created channels
          member.role == "member" and channel.is_public == true -> true
          true -> false
        end
    end
  end

  # ============================================
  # Channel Invites
  # ============================================

  alias PhoenixApp.Forum.ChannelInvite

  def create_channel_invite(attrs \\ %{}) do
    %ChannelInvite{}
    |> ChannelInvite.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, invite} -> {:ok, Repo.preload(invite, [:invitee, :inviter, :channel])}
      error -> error
    end
  end

  @doc "Create a personal invite targeted at a specific user (invitee_id)."
  def create_personal_invite(inviter_id, invitee_identifier, channel_id, opts \\ %{}) do
    # Accept either user id (UUID) or username/email. Resolve to user id when possible.
    resolved_invitee_id =
      cond do
        is_binary(invitee_identifier) ->
          # Try as UUID first
          case Ecto.UUID.cast(invitee_identifier) do
            {:ok, uuid} -> uuid
            :error ->
              # Try resolving by username or email via Accounts
              case PhoenixApp.Accounts.get_user_by_email_or_username(invitee_identifier) do
                nil -> nil
                user -> user.id
              end
          end
        is_nil(invitee_identifier) -> nil
        true -> nil
      end

    if resolved_invitee_id == nil do
      {:error, :invitee_not_found}
    else
      attrs = Map.merge(%{inviter_id: inviter_id, invitee_id: resolved_invitee_id, channel_id: channel_id}, opts)
      create_channel_invite(attrs)
    end
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
        # Ensure invite is still valid for use
        if invite.is_revoked == true || (!!invite.revoked_at) do
          {:error, :invite_revoked}
        else
          if ChannelInvite.is_valid?(invite) do
            # If invite is targeted to a specific invitee, verify the caller
            if invite.invitee_id && invite.invitee_id != user_id do
              {:error, :invite_not_for_user}
            else
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
                  # Mark accepted timestamp when invite is personal
                  if invite.invitee_id do
                    invite
                    |> ChannelInvite.accept()
                    |> Repo.update!()
                  end
                  
                  member
                
                {:error, changeset} ->
                  Repo.rollback(changeset)
              end
            end)
          end
            end
          else
            {:error, :invite_expired}
          end
        end
        end
    end

  @doc "Accept a channel invite by ID (used for personal invites). Returns {:ok, member} or {:error, reason}."
  def accept_channel_invite(invite_id, user_id) do
    case Repo.get(ChannelInvite, invite_id) do
      nil -> {:error, :not_found}
      invite ->
        if invite.is_revoked || (invite.invitee_id && invite.invitee_id != user_id) do
          {:error, :forbidden}
        else
          if ChannelInvite.is_valid?(invite) do
            Repo.transaction(fn ->
              case create_channel_member(%{channel_id: invite.channel_id, user_id: user_id, role: "member"}) do
                {:ok, member} ->
                  invite
                  |> Ecto.Changeset.change(uses: invite.uses + 1)
                  |> ChannelInvite.accept()
                  |> Repo.update!()
                  member

                {:error, changeset} -> Repo.rollback(changeset)
              end
            end)
          else
            {:error, :invite_expired}
          end
        end
    end
  end

  @doc "Revoke a channel invite. Only the inviter, channel owner, or site admins can revoke." 
  def revoke_channel_invite(%{id: user_id} = user, invite_id) do
    case Repo.get(ChannelInvite, invite_id) do
      nil -> {:error, :not_found}
      invite ->
        # Permission check: inviter, channel owner or site admin
        channel = get_channel!(invite.channel_id)
        is_admin = Map.get(user, :is_admin, false) || Map.get(user, :role) in ["admin", "gm", "editor"]

        if invite.inviter_id == user_id || channel.owner_id == user_id || is_admin do
          invite
          |> ChannelInvite.revoke()
          |> Repo.update()
        else
          {:error, :forbidden}
        end
    end
  end

  @doc "Transfer ownership of a channel to a new owner. Only owners, channel creator or site admins can transfer."
  def transfer_channel_ownership(%{id: user_id} = user, %Channel{} = channel, new_owner_id) do
    # Permission: must be current owner, creator, or admin
    is_admin = Map.get(user, :is_admin, false) || Map.get(user, :role) in ["admin", "gm", "editor"]
    allowed = is_admin || channel.owner_id == user_id || channel.created_by_id == user_id

    if not allowed do
      {:error, :forbidden}
    else
      Repo.transaction(fn ->
        # Update channel owner_id
        case update_channel(channel, %{owner_id: new_owner_id}) do
          {:ok, updated_channel} ->
            # Demote previous owner member role (if present and different)
            if channel.owner_id && channel.owner_id != new_owner_id do
              case get_channel_member(channel.id, channel.owner_id) do
                nil -> :ok
                member -> update_channel_member(member, %{role: "member"})
              end
            end

            # Promote new owner to member-owner role
            case get_channel_member(channel.id, new_owner_id) do
              nil -> create_channel_member(%{channel_id: channel.id, user_id: new_owner_id, role: "owner"})
              member -> update_channel_member(member, %{role: "owner"})
            end

            updated_channel

          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
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
