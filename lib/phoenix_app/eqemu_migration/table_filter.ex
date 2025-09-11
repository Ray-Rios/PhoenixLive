defmodule PhoenixApp.EqemuMigration.TableFilter do
  @moduledoc """
  Defines which tables to include/exclude during migration.
  Focuses on essential game data while excluding non-critical pathing and grid data.
  """

  @doc """
  Tables to completely exclude from migration.
  These are typically large, non-essential tables that can be regenerated or aren't needed for basic server functionality.
  """
  def excluded_tables do
    [
      # Grid and pathing data (850K+ rows) - NPCs will spawn but won't have complex pathing
      "temp_grid_entries",
      "grid_entries", 
      "grid",
      
      # Detailed pathing data
      "temp_grid",
      "pathing",
      "path_nodes",
      
      # Quest pathing (can be simplified)
      "quest_globals_players",
      "quest_globals",
      
      # Temporary or cache tables
      "temp_merchantlist_temp",
      "temp_cache",
      
      # Large log tables that aren't needed for development
      "eventlog",
      "chatlog", 
      "guildlog",
      "loginlog",
      
      # Performance/analytics tables
      "peqzone_flags",
      "zone_flags",
      
      # Beta/test data
      "beta_",
      "test_"
    ]
  end

  @doc """
  Essential tables that must be included for basic server functionality.
  These contain core game data needed for characters, items, spells, and zones.
  """
  def essential_tables do
    [
      # Core character and account data
      "temp_account", "account",
      "temp_character_data", "character_data", 
      "temp_character_", "character_",
      
      # Items and inventory
      "temp_items", "items",
      "temp_inventory", "inventory",
      "temp_lootdrop", "lootdrop",
      "temp_lootdrop_entries", "lootdrop_entries",
      
      # NPCs and spawning (but not pathing)
      "temp_npc_types", "npc_types",
      "temp_spawn2", "spawn2",
      "temp_spawnentry", "spawnentry", 
      "temp_spawngroup", "spawngroup",
      
      # Spells and abilities
      "temp_spells_new", "spells_new",
      "temp_spell_", "spell_",
      
      # Zones and basic world data
      "temp_zone", "zone",
      "temp_doors", "doors",
      
      # Trading and merchants
      "temp_merchantlist", "merchantlist",
      "temp_tradeskill", "tradeskill",
      
      # Guilds and groups
      "temp_guilds", "guilds",
      "temp_guild_", "guild_",
      
      # Skills and classes
      "temp_skill_caps", "skill_caps",
      "temp_class_", "class_",
      "temp_race_", "race_"
    ]
  end

  @doc """
  Check if a table should be included in the migration.
  """
  def include_table?(table_name) do
    table_name = String.downcase(table_name)
    
    # Exclude if in exclusion list
    if Enum.any?(excluded_tables(), fn pattern -> 
      String.contains?(table_name, String.downcase(pattern))
    end) do
      false
    else
      # Include if essential or not explicitly excluded
      Enum.any?(essential_tables(), fn pattern ->
        String.contains?(table_name, String.downcase(pattern))
      end) || is_likely_essential?(table_name)
    end
  end

  @doc """
  Heuristic to determine if a table is likely essential based on naming patterns.
  """
  defp is_likely_essential?(table_name) do
    essential_patterns = [
      "account", "character", "item", "spell", "npc", "zone", 
      "guild", "skill", "class", "race", "faction", "merchant",
      "door", "object", "spawn", "loot", "trade"
    ]
    
    Enum.any?(essential_patterns, fn pattern ->
      String.contains?(table_name, pattern)
    end)
  end

  @doc """
  Get filtered table counts, excluding non-essential tables.
  """
  def filter_table_counts(table_counts) do
    table_counts
    |> Enum.filter(fn {table_name, _count} -> include_table?(table_name) end)
    |> Enum.into(%{})
  end

  @doc """
  Calculate space savings from excluding tables.
  """
  def calculate_exclusion_savings(table_counts) do
    excluded_counts = 
      table_counts
      |> Enum.filter(fn {table_name, _count} -> not include_table?(table_name) end)
      |> Enum.into(%{})
    
    included_counts = filter_table_counts(table_counts)
    
    excluded_rows = excluded_counts |> Map.values() |> Enum.sum()
    included_rows = included_counts |> Map.values() |> Enum.sum()
    total_rows = table_counts |> Map.values() |> Enum.sum()
    
    savings_percentage = if total_rows > 0 do
      Float.round((excluded_rows / total_rows) * 100, 1)
    else
      0.0
    end
    
    %{
      total_tables: map_size(table_counts),
      excluded_tables: map_size(excluded_counts),
      included_tables: map_size(included_counts),
      total_rows: total_rows,
      excluded_rows: excluded_rows,
      included_rows: included_rows,
      savings_percentage: savings_percentage,
      largest_excluded: get_largest_tables(excluded_counts, 5),
      largest_included: get_largest_tables(included_counts, 10)
    }
  end

  @doc """
  Get the largest tables from a table counts map.
  """
  defp get_largest_tables(table_counts, limit) do
    table_counts
    |> Enum.sort_by(fn {_table, count} -> count end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Format exclusion analysis for display.
  """
  def format_exclusion_analysis(table_counts) do
    analysis = calculate_exclusion_savings(table_counts)
    
    """
    
    === Table Exclusion Analysis ===
    📊 Total Tables: #{analysis.total_tables}
    ✅ Included Tables: #{analysis.included_tables}
    ❌ Excluded Tables: #{analysis.excluded_tables}
    
    📈 Row Counts:
    • Total Rows: #{format_number(analysis.total_rows)}
    • Included Rows: #{format_number(analysis.included_rows)}
    • Excluded Rows: #{format_number(analysis.excluded_rows)}
    • Space Savings: #{analysis.savings_percentage}%
    
    🚫 Top Excluded Tables:
    #{format_table_list(analysis.largest_excluded)}
    
    ✅ Top Included Tables:
    #{format_table_list(analysis.largest_included)}
    """
  end

  defp format_table_list(tables) do
    tables
    |> Enum.with_index(1)
    |> Enum.map(fn {{table, count}, index} ->
      "  #{index}. #{table}: #{format_number(count)} rows"
    end)
    |> Enum.join("\n")
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end