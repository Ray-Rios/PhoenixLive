defmodule PhoenixApp.Chat do
  @moduledoc """
  The Chat context for Discord-like messaging functionality.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Chat.{Channel, Message, Reaction, Thread}

  # Channels
  def list_channels do
    from(c in Channel, order_by: [asc: c.position, asc: c.name])
    |> Repo.all()
  end

  def get_channel!(id) do
    Repo.get!(Channel, id)
  end

  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
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
end