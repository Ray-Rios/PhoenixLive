defmodule PhoenixAppWeb.Resolvers.EqemuResolver do
  alias PhoenixApp.EqemuGame
  # Note: Accounts removed - not used in EQEmu resolver

  # Character Resolvers
  def get_character(_parent, %{id: id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(id)
    
    if character.user_id == user.id or user.is_admin do
      {:ok, character}
    else
      {:error, "Not authorized"}
    end
  end

  def list_user_characters(_parent, _args, %{context: %{current_user: user}}) do
    characters = EqemuGame.list_user_characters(user)
    {:ok, characters}
  end

  def create_character(_parent, %{input: input}, %{context: %{current_user: user}}) do
    # Generate unique character_id
    character_id = :rand.uniform(2_000_000_000)
    
    # Set default starting zone (Qeynos for good races, Freeport for evil, Cabilis for Iksar)
    starting_zone = case input.race do
      128 -> 106  # Iksar -> Cabilis
      9 -> 8      # Troll -> Grobb
      10 -> 67    # Ogre -> Oggok
      6 -> 42     # Dark Elf -> Neriak
      _ -> 1      # Others -> Qeynos
    end
    
    attrs = Map.merge(input, %{
      character_id: character_id,
      zone_id: starting_zone,
      level: 1,
      hp: calculate_starting_hp(input.race, input.class),
      mana: calculate_starting_mana(input.race, input.class),
      endurance: 100,
      experience: 0
    })
    
    case EqemuGame.create_character(user, attrs) do
      {:ok, character} ->
        # Create character stats
        EqemuGame.create_character_stats(character.id, %{})
        
        # Broadcast character creation
        Absinthe.Subscription.publish(
          PhoenixAppWeb.Endpoint,
          character,
          character_updated: "character:#{character.id}"
        )
        
        {:ok, character}
      
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_character(_parent, %{id: id, input: input}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.update_character(character, input) do
        {:ok, updated_character} ->
          # Broadcast character update
          Absinthe.Subscription.publish(
            PhoenixAppWeb.Endpoint,
            updated_character,
            character_updated: "character:#{updated_character.id}"
          )
          
          {:ok, updated_character}
        
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Not authorized"}
    end
  end

  def delete_character(_parent, %{id: id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.delete_character(character) do
        {:ok, deleted_character} ->
          {:ok, deleted_character}
        
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Not authorized"}
    end
  end

  # Inventory Resolvers
  def get_character_inventory(_parent, %{character_id: character_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      inventory = EqemuGame.get_character_inventory(character_id)
      {:ok, inventory}
    else
      {:error, "Not authorized"}
    end
  end

  def update_inventory(_parent, %{character_id: character_id, input: input}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.create_inventory_item(character_id, input) do
        {:ok, inventory_item} ->
          {:ok, inventory_item}
        
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Not authorized"}
    end
  end

  # Item Resolvers
  def list_items(_parent, args, _resolution) do
    items = EqemuGame.list_items(args)
    {:ok, items}
  end

  def get_item(_parent, %{id: id}, _resolution) when not is_nil(id) do
    item = EqemuGame.get_item!(id)
    {:ok, item}
  end

  def get_item(_parent, %{item_id: item_id}, _resolution) when not is_nil(item_id) do
    case EqemuGame.get_item_by_item_id(item_id) do
      nil -> {:error, "Item not found"}
      item -> {:ok, item}
    end
  end

  def get_item(_parent, _args, _resolution) do
    {:error, "Must provide either id or item_id"}
  end

  # Zone Resolvers
  def list_zones(_parent, _args, _resolution) do
    zones = EqemuGame.list_zones()
    {:ok, zones}
  end

  def get_zone(_parent, %{id: id}, _resolution) when not is_nil(id) do
    zone = EqemuGame.get_zone!(id)
    {:ok, zone}
  end

  def get_zone(_parent, %{zone_id: zone_id}, _resolution) when not is_nil(zone_id) do
    case EqemuGame.get_zone_by_zone_id(zone_id) do
      nil -> {:error, "Zone not found"}
      zone -> {:ok, zone}
    end
  end

  def get_zone(_parent, %{short_name: short_name}, _resolution) when not is_nil(short_name) do
    case EqemuGame.get_zone_by_short_name(short_name) do
      nil -> {:error, "Zone not found"}
      zone -> {:ok, zone}
    end
  end

  def get_zone(_parent, _args, _resolution) do
    {:error, "Must provide either id, zone_id, or short_name"}
  end

  def zone_character(_parent, %{character_id: character_id, zone_id: zone_id} = args, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      x = Map.get(args, :x)
      y = Map.get(args, :y)
      z = Map.get(args, :z)
      heading = Map.get(args, :heading)
      
      case EqemuGame.zone_character(character_id, zone_id, x, y, z, heading) do
        {:ok, updated_character} ->
          # Broadcast zone change
          Absinthe.Subscription.publish(
            PhoenixAppWeb.Endpoint,
            updated_character,
            character_updated: %{character: "#{updated_character.id}"}
          )
          
          {:ok, updated_character}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Not authorized"}
    end
  end

  # Guild Resolvers
  def get_guild(_parent, %{id: id}, _resolution) do
    guild = EqemuGame.get_guild!(id)
    {:ok, guild}
  end

  def get_character_guild(_parent, %{character_id: character_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.get_character_guild(character_id) do
        nil -> {:ok, nil}
        guild -> {:ok, guild}
      end
    else
      {:error, "Not authorized"}
    end
  end

  def join_guild(_parent, %{character_id: character_id, guild_id: guild_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.join_guild(character_id, guild_id) do
        {:ok, guild_member} ->
          {:ok, guild_member}
        
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Not authorized"}
    end
  end

  def leave_guild(_parent, %{character_id: character_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.leave_guild(character_id) do
        {count, _} when count > 0 ->
          {:ok, %{success: true}}
        
        _ ->
          {:error, "Not in a guild"}
      end
    else
      {:error, "Not authorized"}
    end
  end

  # Quest Resolvers
  def get_available_quests(_parent, %{character_id: character_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      quests = EqemuGame.get_available_quests(character_id)
      {:ok, quests}
    else
      {:error, "Not authorized"}
    end
  end

  def get_character_quests(_parent, %{character_id: character_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      quests = EqemuGame.get_character_quests(character_id)
      {:ok, quests}
    else
      {:error, "Not authorized"}
    end
  end

  def accept_quest(_parent, %{character_id: character_id, task_id: task_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.accept_quest(character_id, task_id) do
        {:ok, character_task} ->
          {:ok, character_task}
        
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Not authorized"}
    end
  end

  def complete_quest(_parent, %{character_id: character_id, task_id: task_id}, %{context: %{current_user: user}}) do
    character = EqemuGame.get_character!(character_id)
    
    if character.user_id == user.id or user.is_admin do
      case EqemuGame.complete_quest(character_id, task_id) do
        {:ok, character_task} ->
          {:ok, character_task}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Not authorized"}
    end
  end

  # NPC Resolvers
  def get_zone_npcs(_parent, %{zone_id: _zone_id}, _resolution) do
    # This would need to be implemented in EqemuGame context
    {:ok, []}
  end

  # Spell Resolvers
  def get_class_spells(_parent, %{class_id: _class_id} = args, _resolution) do
    _level = Map.get(args, :level, 65)
    # This would need to be implemented in EqemuGame context
    {:ok, []}
  end

  # Helper functions
  defp calculate_starting_hp(race, class) do
    base_hp = case class do
      1 -> 54   # Warrior
      2 -> 48   # Cleric
      3 -> 52   # Paladin
      4 -> 50   # Ranger
      5 -> 52   # Shadow Knight
      6 -> 48   # Druid
      7 -> 50   # Monk
      8 -> 48   # Bard
      9 -> 50   # Rogue
      10 -> 48  # Shaman
      11 -> 48  # Necromancer
      12 -> 48  # Wizard
      13 -> 48  # Magician
      14 -> 48  # Enchanter
      15 -> 50  # Beastlord
      16 -> 54  # Berserker
      _ -> 50
    end
    
    race_bonus = case race do
      2 -> 5    # Barbarian
      8 -> 5    # Dwarf
      9 -> 10   # Troll
      10 -> 15  # Ogre
      128 -> 5  # Iksar
      _ -> 0
    end
    
    base_hp + race_bonus
  end

  defp calculate_starting_mana(_race, class) do
    case class do
      1 -> 0    # Warrior
      2 -> 80   # Cleric
      3 -> 0    # Paladin (gets mana later)
      4 -> 0    # Ranger (gets mana later)
      5 -> 0    # Shadow Knight (gets mana later)
      6 -> 80   # Druid
      7 -> 0    # Monk
      8 -> 0    # Bard (gets mana later)
      9 -> 0    # Rogue
      10 -> 80  # Shaman
      11 -> 80  # Necromancer
      12 -> 80  # Wizard
      13 -> 80  # Magician
      14 -> 80  # Enchanter
      15 -> 0   # Beastlord (gets mana later)
      16 -> 0   # Berserker
      _ -> 0
    end
  end
end