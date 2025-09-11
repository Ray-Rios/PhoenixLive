defmodule PhoenixApp.EQEmuGame.MigrationGenerator do
  @moduledoc """
  Generates Phoenix migrations from parsed PEQ schema.
  
  This module takes the output from PeqParser and creates proper Phoenix/Ecto
  migrations that are compatible with CockroachDB and follow Phoenix conventions.
  """
  
  require Logger
  
  @migration_template """
  defmodule PhoenixApp.Repo.Migrations.<%= @migration_name %> do
    use Ecto.Migration
    
    def up do
  <%= @up_content %>
    end
    
    def down do
  <%= @down_content %>
    end
  end
  """
  
  def generate_from_parsed_data(parsed_state, opts \\ []) do
    Logger.info("🏗️ Generating Phoenix migrations from parsed PEQ data...")
    
    output_dir = Keyword.get(opts, :output_dir, "priv/repo/migrations")
    File.mkdir_p!(output_dir)
    
    # Generate main schema migration
    with :ok <- generate_schema_migration(parsed_state, output_dir),
         :ok <- generate_data_migration(parsed_state, output_dir),
         :ok <- generate_index_migration(parsed_state, output_dir),
         :ok <- generate_foreign_key_migration(parsed_state, output_dir) do
      
      Logger.info("✅ All migrations generated successfully!")
      :ok
    else
      {:error, reason} ->
        Logger.error("❌ Migration generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp generate_schema_migration(parsed_state, output_dir) do
    Logger.info("📝 Generating schema migration...")
    
    timestamp = generate_timestamp(1)
    filename = "#{timestamp}_create_eqemu_schema.exs"
    filepath = Path.join(output_dir, filename)
    
    # Group tables by priority (accounts first, then characters, etc.)
    prioritized_tables = prioritize_tables(parsed_state.parsed_tables)
    
    up_content = generate_schema_up_content(prioritized_tables)
    down_content = generate_schema_down_content(prioritized_tables)
    
    migration_content = EEx.eval_string(@migration_template, [
      migration_name: "CreateEqemuSchema",
      up_content: up_content,
      down_content: down_content
    ])
    
    File.write!(filepath, migration_content)
    Logger.info("✅ Schema migration created: #{filename}")
    :ok
  end
  
  defp generate_data_migration(parsed_state, output_dir) do
    Logger.info("📝 Generating data migration...")
    
    timestamp = generate_timestamp(2)
    filename = "#{timestamp}_create_eqemu_data_functions.exs"
    filepath = Path.join(output_dir, filename)
    
    up_content = generate_data_functions_content(parsed_state)
    down_content = generate_data_functions_down_content()
    
    migration_content = EEx.eval_string(@migration_template, [
      migration_name: "CreateEqemuDataFunctions",
      up_content: up_content,
      down_content: down_content
    ])
    
    File.write!(filepath, migration_content)
    Logger.info("✅ Data migration created: #{filename}")
    :ok
  end
  
  defp generate_index_migration(parsed_state, output_dir) do
    Logger.info("📝 Generating index migration...")
    
    timestamp = generate_timestamp(3)
    filename = "#{timestamp}_create_eqemu_indexes.exs"
    filepath = Path.join(output_dir, filename)
    
    up_content = generate_indexes_up_content(parsed_state.indexes, parsed_state.parsed_tables)
    down_content = generate_indexes_down_content(parsed_state.indexes)
    
    migration_content = EEx.eval_string(@migration_template, [
      migration_name: "CreateEqemuIndexes",
      up_content: up_content,
      down_content: down_content
    ])
    
    File.write!(filepath, migration_content)
    Logger.info("✅ Index migration created: #{filename}")
    :ok
  end
  
  defp generate_foreign_key_migration(parsed_state, output_dir) do
    Logger.info("📝 Generating foreign key migration...")
    
    timestamp = generate_timestamp(4)
    filename = "#{timestamp}_create_eqemu_foreign_keys.exs"
    filepath = Path.join(output_dir, filename)
    
    up_content = generate_foreign_keys_up_content(parsed_state.foreign_keys)
    down_content = generate_foreign_keys_down_content(parsed_state.foreign_keys)
    
    migration_content = EEx.eval_string(@migration_template, [
      migration_name: "CreateEqemuForeignKeys",
      up_content: up_content,
      down_content: down_content
    ])
    
    File.write!(filepath, migration_content)
    Logger.info("✅ Foreign key migration created: #{filename}")
    :ok
  end
  
  defp prioritize_tables(parsed_tables) do
    # Define table creation order based on dependencies
    priority_order = [
      # Core system tables first
      "account", "users",
      
      # Zone and world data
      "zone", "zone_points", "start_zones",
      
      # Character system
      "character_data", "character_stats", "character_skills",
      "character_inventory", "character_spells", "character_memmed_spells",
      
      # Items and equipment
      "items", "item_tick",
      
      # Guild system
      "guilds", "guild_members", "guild_ranks",
      
      # Quest and task system
      "tasks", "character_tasks",
      
      # NPC and spawn system
      "npc_types", "spawn2", "spawnentry", "spawngroupentry",
      
      # Loot system
      "loot_table", "loot_table_entries", "loottable",
      
      # Spell system
      "spells_new", "spell_buckets"
    ]
    
    # Sort tables by priority, with unknown tables at the end
    sorted_tables = 
      priority_order
      |> Enum.filter(&Map.has_key?(parsed_tables, &1))
      |> Enum.map(&{&1, Map.get(parsed_tables, &1)})
    
    # Add any remaining tables not in priority list
    remaining_tables = 
      parsed_tables
      |> Enum.reject(fn {name, _} -> name in priority_order end)
    
    sorted_tables ++ remaining_tables
  end
  
  defp generate_schema_up_content(prioritized_tables) do
    table_definitions = 
      prioritized_tables
      |> Enum.map(&generate_table_definition/1)
      |> Enum.join("\n\n")
    
    """
      # Create EQEmu tables in dependency order
  #{table_definitions}
    """
  end
  
  defp generate_schema_down_content(prioritized_tables) do
    # Drop tables in reverse order
    drop_statements = 
      prioritized_tables
      |> Enum.reverse()
      |> Enum.map(fn {table_name, _} -> "    drop_if_exists table(:#{table_name})" end)
      |> Enum.join("\n")
    
    """
      # Drop EQEmu tables in reverse dependency order
  #{drop_statements}
    """
  end
  
  defp generate_table_definition({table_name, table_info}) do
    # Convert table name to Phoenix convention
    phoenix_table_name = convert_table_name(table_name)
    
    # Generate column definitions
    columns = 
      table_info.columns
      |> Enum.reverse()  # Restore original order
      |> Enum.map(&generate_column_definition/1)
      |> Enum.join("\n")
    
    # Add primary key if not auto-generated
    primary_key_line = 
      if has_auto_increment_id?(table_info.columns) do
        ""
      else
        "      add :id, :binary_id, primary_key: true\n"
      end
    
    """
      create table(:#{phoenix_table_name}) do
  #{primary_key_line}#{columns}
        
        timestamps()
      end
    """
  end
  
  defp generate_column_definition(column) do
    # Convert column name to Phoenix convention
    phoenix_column_name = convert_column_name(column.name)
    
    # Convert data type
    phoenix_type = convert_to_phoenix_type(column.postgresql_type)
    
    # Build column options
    options = []
    
    options = if column.nullable, do: options, else: ["null: false" | options]
    options = if column.default, do: ["default: #{format_default_value(column.default, phoenix_type)}" | options]
    options = if column.auto_increment and phoenix_column_name == "id", do: ["primary_key: true" | options]
    
    options_str = if length(options) > 0, do: ", " <> Enum.join(options, ", "), else: ""
    
    "      add :#{phoenix_column_name}, :#{phoenix_type}#{options_str}"
  end
  
  defp generate_data_functions_content(_parsed_state) do
    """
      # Create helper functions for data import and validation
      
      execute \"\"\"
      CREATE OR REPLACE FUNCTION convert_mysql_timestamp(mysql_ts INTEGER)
      RETURNS TIMESTAMP AS $$
      BEGIN
        IF mysql_ts = 0 OR mysql_ts IS NULL THEN
          RETURN NULL;
        ELSE
          RETURN to_timestamp(mysql_ts);
        END IF;
      END;
      $$ LANGUAGE plpgsql;
      \"\"\"
      
      execute \"\"\"
      CREATE OR REPLACE FUNCTION validate_eqemu_character(
        char_name VARCHAR(64),
        char_race INTEGER,
        char_class INTEGER
      ) RETURNS BOOLEAN AS $$
      BEGIN
        -- Validate character name (3-64 characters, alphanumeric)
        IF char_name IS NULL OR length(char_name) < 3 OR length(char_name) > 64 THEN
          RETURN FALSE;
        END IF;
        
        -- Validate race (1-522 in EverQuest)
        IF char_race < 1 OR char_race > 522 THEN
          RETURN FALSE;
        END IF;
        
        -- Validate class (1-16 in EverQuest)
        IF char_class < 1 OR char_class > 16 THEN
          RETURN FALSE;
        END IF;
        
        RETURN TRUE;
      END;
      $$ LANGUAGE plpgsql;
      \"\"\"
      
      execute \"\"\"
      CREATE OR REPLACE FUNCTION cleanup_orphaned_records()
      RETURNS INTEGER AS $$
      DECLARE
        deleted_count INTEGER := 0;
      BEGIN
        -- Clean up characters without valid accounts
        DELETE FROM character_data WHERE account_id NOT IN (SELECT id FROM account);
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        
        RETURN deleted_count;
      END;
      $$ LANGUAGE plpgsql;
      \"\"\"
    """
  end
  
  defp generate_data_functions_down_content do
    """
      # Drop helper functions
      execute "DROP FUNCTION IF EXISTS convert_mysql_timestamp(INTEGER)"
      execute "DROP FUNCTION IF EXISTS validate_eqemu_character(VARCHAR, INTEGER, INTEGER)"
      execute "DROP FUNCTION IF EXISTS cleanup_orphaned_records()"
    """
  end
  
  defp generate_indexes_up_content(indexes, parsed_tables) do
    # Generate essential indexes for performance
    essential_indexes = generate_essential_indexes(parsed_tables)
    parsed_indexes = Enum.map(indexes, &generate_index_statement/1)
    
    all_indexes = (essential_indexes ++ parsed_indexes) |> Enum.join("\n")
    
    """
      # Create essential performance indexes
  #{all_indexes}
    """
  end
  
  defp generate_indexes_down_content(indexes) do
    drop_statements = 
      indexes
      |> Enum.map(fn index -> "    drop_if_exists index(:#{index.table}, [:#{Enum.join(index.columns, ", :")}])" end)
      |> Enum.join("\n")
    
    """
      # Drop custom indexes (essential indexes dropped with tables)
  #{drop_statements}
    """
  end
  
  defp generate_essential_indexes(parsed_tables) do
    # Generate indexes for common query patterns
    essential_patterns = [
      {"character_data", ["account_id"], false},
      {"character_data", ["name"], true},
      {"character_inventory", ["charid"], false},
      {"items", ["name"], false},
      {"guilds", ["name"], true},
      {"guild_members", ["char_id"], false},
      {"zone", ["short_name"], true}
    ]
    
    essential_patterns
    |> Enum.filter(fn {table, _, _} -> Map.has_key?(parsed_tables, table) end)
    |> Enum.map(fn {table, columns, unique} ->
      unique_str = if unique, do: ", unique: true", else: ""
      column_list = Enum.map_join(columns, ", ", &":#{&1}")
      "    create index(:#{table}, [#{column_list}]#{unique_str})"
    end)
  end
  
  defp generate_index_statement(index) do
    unique_str = if index.unique, do: ", unique: true", else: ""
    columns = Enum.map_join(index.columns, ", ", &":#{String.trim(&1, "`")}")
    
    "    create index(:#{index.table}, [#{columns}]#{unique_str})"
  end
  
  defp generate_foreign_keys_up_content(foreign_keys) do
    fk_statements = 
      foreign_keys
      |> Enum.map(&generate_foreign_key_statement/1)
      |> Enum.join("\n")
    
    """
      # Add foreign key constraints for data integrity
  #{fk_statements}
    """
  end
  
  defp generate_foreign_keys_down_content(foreign_keys) do
    drop_statements = 
      foreign_keys
      |> Enum.map(fn fk -> 
        "    drop constraint(:#{fk.foreign_table}, :#{fk.local_column}_#{fk.foreign_table}_fkey)"
      end)
      |> Enum.join("\n")
    
    """
      # Drop foreign key constraints
  #{drop_statements}
    """
  end
  
  defp generate_foreign_key_statement(fk) do
    """
      alter table(:#{fk.foreign_table}) do
        modify :#{fk.local_column}, references(:#{fk.foreign_table}, on_delete: :restrict)
      end
    """
  end
  
  # Helper functions
  
  defp generate_timestamp(offset_minutes) do
    base_time = DateTime.utc_now()
    offset_time = DateTime.add(base_time, offset_minutes * 60, :second)
    
    Calendar.strftime(offset_time, "%Y%m%d%H%M%S")
  end
  
  defp convert_table_name(mysql_name) do
    # Convert MySQL table names to Phoenix conventions
    case mysql_name do
      "character_data" -> "eqemu_characters"
      "account" -> "eqemu_accounts"
      "items" -> "eqemu_items"
      "guilds" -> "eqemu_guilds"
      "guild_members" -> "eqemu_guild_members"
      "zone" -> "eqemu_zones"
      name -> "eqemu_#{name}"
    end
  end
  
  defp convert_column_name(mysql_name) do
    # Convert MySQL column names to Phoenix conventions
    case mysql_name do
      "id" -> "eqemu_id"  # Preserve original EQEmu IDs
      name -> name
    end
  end
  
  defp convert_to_phoenix_type(postgresql_type) do
    # Convert PostgreSQL types to Phoenix/Ecto types
    case String.downcase(postgresql_type) do
      "integer" -> "integer"
      "bigint" -> "bigint"
      "smallint" -> "smallint"
      "varchar" <> _ -> "string"
      "char" <> _ -> "string"
      "text" -> "text"
      "real" -> "float"
      "double precision" -> "float"
      "decimal" <> _ -> "decimal"
      "timestamp" -> "utc_datetime"
      "date" -> "date"
      "time" -> "time"
      "bytea" -> "binary"
      type -> type
    end
  end
  
  defp has_auto_increment_id?(columns) do
    Enum.any?(columns, fn col -> 
      col.name == "id" and col.auto_increment 
    end)
  end
  
  defp format_default_value(value, type) do
    case type do
      "string" -> "\"#{value}\""
      "integer" -> value
      "float" -> value
      "boolean" -> value
      _ -> "\"#{value}\""
    end
  end
end