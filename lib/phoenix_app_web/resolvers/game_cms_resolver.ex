defmodule PhoenixAppWeb.Resolvers.GameCmsResolver do
  alias PhoenixApp.GameCMS

  # Character Resolvers
  def list_characters(_parent, _args, _resolution) do
    {:ok, GameCMS.list_characters()}
  end

  def get_character(_parent, %{id: id}, _resolution) do
    case GameCMS.get_character!(id) do
      nil -> {:error, "Character not found"}
      character -> {:ok, character}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Character not found"}
  end

  def get_my_character(_parent, _args, %{context: %{current_user: user}}) do
    case GameCMS.get_character_by_user_id(user.id) do
      nil -> {:error, "No character found for current user"}
      character -> {:ok, character}
    end
  end

  def get_my_character(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def create_character(_parent, %{input: input}, %{context: %{current_user: user}}) do
    input_with_user = Map.put(input, :user_id, user.id)
    
    case GameCMS.create_character(input_with_user) do
      {:ok, character} ->
        # Create a game event
        GameCMS.create_game_event(%{
          event_type: "player_join",
          message: "#{character.name} joined the game!",
          user_id: user.id,
          character_id: character.id
        })
        
        {:ok, character}
      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  def create_character(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def update_character(_parent, %{id: id, input: input}, %{context: %{current_user: user}}) do
    character = GameCMS.get_character!(id)
    
    # Check if user owns this character or is admin
    if character.user_id == user.id or user.role == :admin do
      case GameCMS.update_character(character, input) do
        {:ok, character} -> {:ok, character}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Not authorized to update this character"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Character not found"}
  end

  def update_character(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def delete_character(_parent, %{id: id}, %{context: %{current_user: user}}) do
    character = GameCMS.get_character!(id)
    
    # Check if user owns this character or is admin
    if character.user_id == user.id or user.role == :admin do
      case GameCMS.delete_character(character) do
        {:ok, character} -> {:ok, character}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Not authorized to delete this character"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Character not found"}
  end

  def delete_character(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  # Item Resolvers
  def list_items(_parent, _args, _resolution) do
    {:ok, GameCMS.list_items()}
  end

  def get_item(_parent, %{id: id}, _resolution) do
    case GameCMS.get_item!(id) do
      nil -> {:error, "Item not found"}
      item -> {:ok, item}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Item not found"}
  end

  def create_item(_parent, %{input: input}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      case GameCMS.create_item(input) do
        {:ok, item} -> {:ok, item}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  end

  def create_item(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def update_item(_parent, %{id: id, input: input}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      item = GameCMS.get_item!(id)
      case GameCMS.update_item(item, input) do
        {:ok, item} -> {:ok, item}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Item not found"}
  end

  def update_item(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def delete_item(_parent, %{id: id}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      item = GameCMS.get_item!(id)
      case GameCMS.delete_item(item) do
        {:ok, item} -> {:ok, item}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Item not found"}
  end

  def delete_item(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  # Quest Resolvers
  def list_quests(_parent, _args, _resolution) do
    {:ok, GameCMS.list_quests()}
  end

  def get_quest(_parent, %{id: id}, _resolution) do
    case GameCMS.get_quest!(id) do
      nil -> {:error, "Quest not found"}
      quest -> {:ok, quest}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Quest not found"}
  end

  def create_quest(_parent, %{input: input}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      case GameCMS.create_quest(input) do
        {:ok, quest} -> {:ok, quest}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  end

  def create_quest(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def update_quest(_parent, %{id: id, input: input}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      quest = GameCMS.get_quest!(id)
      case GameCMS.update_quest(quest, input) do
        {:ok, quest} -> {:ok, quest}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Quest not found"}
  end

  def update_quest(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def delete_quest(_parent, %{id: id}, %{context: %{current_user: user}}) do
    if user.role == :admin do
      quest = GameCMS.get_quest!(id)
      case GameCMS.delete_quest(quest) do
        {:ok, quest} -> {:ok, quest}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Admin access required"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Quest not found"}
  end

  def delete_quest(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  # Guild Resolvers
  def list_guilds(_parent, _args, _resolution) do
    {:ok, GameCMS.list_guilds()}
  end

  def get_guild(_parent, %{id: id}, _resolution) do
    case GameCMS.get_guild!(id) do
      nil -> {:error, "Guild not found"}
      guild -> {:ok, guild}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Guild not found"}
  end

  def create_guild(_parent, %{input: input}, %{context: %{current_user: user}}) do
    input_with_leader = Map.put(input, :leader_id, user.id)
    
    case GameCMS.create_guild(input_with_leader) do
      {:ok, guild} -> {:ok, guild}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def create_guild(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def update_guild(_parent, %{id: id, input: input}, %{context: %{current_user: user}}) do
    guild = GameCMS.get_guild!(id)
    
    # Check if user is guild leader or admin
    if guild.leader_id == user.id or user.role == :admin do
      case GameCMS.update_guild(guild, input) do
        {:ok, guild} -> {:ok, guild}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Not authorized to update this guild"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Guild not found"}
  end

  def update_guild(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def delete_guild(_parent, %{id: id}, %{context: %{current_user: user}}) do
    guild = GameCMS.get_guild!(id)
    
    # Check if user is guild leader or admin
    if guild.leader_id == user.id or user.role == :admin do
      case GameCMS.delete_guild(guild) do
        {:ok, guild} -> {:ok, guild}
        {:error, changeset} -> {:error, format_errors(changeset)}
      end
    else
      {:error, "Not authorized to delete this guild"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Guild not found"}
  end

  def delete_guild(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  # Event and Chat Resolvers
  def list_game_events(_parent, _args, _resolution) do
    {:ok, GameCMS.list_game_events()}
  end

  def list_chat_messages(_parent, %{limit: limit}, _resolution) do
    {:ok, GameCMS.list_chat_messages(limit)}
  end

  def list_chat_messages(_parent, _args, _resolution) do
    {:ok, GameCMS.list_chat_messages()}
  end

  def send_chat_message(_parent, %{input: input}, %{context: %{current_user: user}}) do
    input_with_user = Map.put(input, :user_id, user.id)
    
    case GameCMS.create_chat_message(input_with_user) do
      {:ok, message} ->
        # Broadcast the message to all connected users
        Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "game:chat", {:new_message, message})
        {:ok, message}
      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  def send_chat_message(_parent, _args, _resolution) do
    {:error, "Authentication required"}
  end

  def get_game_stats(_parent, _args, _resolution) do
    {:ok, GameCMS.get_game_stats()}
  end

  # Helper function to format changeset errors
  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end