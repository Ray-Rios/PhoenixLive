defmodule PhoenixApp.GameCMS do
  @moduledoc """
  The GameCMS context - handles all game content management operations.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.GameCMS.{Character, Item, Quest, Guild, GameEvent, ChatMessage}

  ## Characters

  def list_characters do
    Repo.all(Character)
  end

  def get_character!(id), do: Repo.get!(Character, id)

  def get_character_by_user_id(user_id) do
    Repo.get_by(Character, user_id: user_id)
  end

  def create_character(attrs \\ %{}) do
    %Character{}
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  def delete_character(%Character{} = character) do
    Repo.delete(character)
  end

  ## Items

  def list_items do
    Repo.all(Item)
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  ## Quests

  def list_quests do
    Repo.all(Quest)
  end

  def get_quest!(id), do: Repo.get!(Quest, id)

  def create_quest(attrs \\ %{}) do
    %Quest{}
    |> Quest.changeset(attrs)
    |> Repo.insert()
  end

  def update_quest(%Quest{} = quest, attrs) do
    quest
    |> Quest.changeset(attrs)
    |> Repo.update()
  end

  def delete_quest(%Quest{} = quest) do
    Repo.delete(quest)
  end

  ## Guilds

  def list_guilds do
    Repo.all(Guild)
  end

  def get_guild!(id), do: Repo.get!(Guild, id)

  def create_guild(attrs \\ %{}) do
    %Guild{}
    |> Guild.changeset(attrs)
    |> Repo.insert()
  end

  def update_guild(%Guild{} = guild, attrs) do
    guild
    |> Guild.changeset(attrs)
    |> Repo.update()
  end

  def delete_guild(%Guild{} = guild) do
    Repo.delete(guild)
  end

  ## Game Events

  def list_game_events do
    GameEvent
    |> order_by(desc: :inserted_at)
    |> limit(100)
    |> Repo.all()
  end

  def create_game_event(attrs \\ %{}) do
    %GameEvent{}
    |> GameEvent.changeset(attrs)
    |> Repo.insert()
  end

  ## Chat Messages

  def list_chat_messages(limit \\ 50) do
    ChatMessage
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def create_chat_message(attrs \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  ## Statistics

  def get_game_stats do
    %{
      total_characters: Repo.aggregate(Character, :count),
      total_items: Repo.aggregate(Item, :count),
      total_quests: Repo.aggregate(Quest, :count),
      total_guilds: Repo.aggregate(Guild, :count),
      active_players: get_active_players_count(),
      recent_events: list_game_events() |> Enum.take(10)
    }
  end

  defp get_active_players_count do
    # Count characters that have been active in the last hour
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)
    
    Character
    |> where([c], c.last_active > ^one_hour_ago)
    |> Repo.aggregate(:count)
  end
end