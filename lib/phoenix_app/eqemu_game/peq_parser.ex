defmodule PhoenixApp.EQEmuGame.PeqParser do
  @moduledoc """
  SQL parser to analyze PEQ database structure and generate Phoenix migrations.
  
  This module handles parsing the large PEQ SQL dump file (7763+ lines) and
  extracts table structures, data types, and relationships for conversion
  to Phoenix-compatible PostgreSQL schema.
  """
  
  require Logger
  
  @peq_sql_file "eqemu/migrations/peq.sql"
  @output_dir "tmp/eqemu_migration"
  @batch_size 1000
  
  defstruct [
    :file_path,
    :total_lines,
    :parsed_tables,
    :data_inserts,
    :foreign_keys,
    :indexes,
    :current_line,
    :errors
  ]
  
  def parse_peq_file(file_path \\ @peq_sql_file) do
    Logger.info("🔍 Starting PEQ SQL file analysis: #{file_path}")
    
    unless File.exists?(file_path) do
      Logger.error("❌ PEQ SQL file not found: #{file_path}")
      {:error, :file_not_found}
    else
    
    # Initialize parser state
    parser_state = %__MODULE__{
      file_path: file_path,
      total_lines: count_lines(file_path),
      parsed_tables: %{},
      data_inserts: %{},
      foreign_keys: [],
      indexes: [],
      current_line: 0,
      errors: []
    }
    
    Logger.info("📊 Total lines to parse: #{parser_state.total_lines}")
    
      # Create output directory
      File.mkdir_p!(@output_dir)
      
      # Parse the file
      with {:ok, parsed_state} <- parse_sql_file(parser_state),
           :ok <- generate_migration_files(parsed_state),
           :ok <- generate_import_scripts(parsed_state) do
        
        Logger.info("✅ PEQ parsing completed successfully!")
        print_parsing_summary(parsed_state)
        {:ok, parsed_state}
      else
        {:error, reason} ->
          Logger.error("❌ PEQ parsing failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
  
  defp count_lines(file_path) do
    File.stream!(file_path)
    |> Enum.count()
  end
  
  defp parse_sql_file(parser_state) do
    Logger.info("📖 Parsing SQL file...")
    
    file_stream = File.stream!(parser_state.file_path)
    
    final_state = 
      file_stream
      |> Stream.with_index(1)
      |> Enum.reduce(parser_state, &parse_sql_line/2)
    
    if length(final_state.errors) > 0 do
      Logger.warning("⚠️  Parsing completed with #{length(final_state.errors)} warnings")
      Enum.each(final_state.errors, &Logger.warning("   #{&1}"))
    end
    
    {:ok, final_state}
  end
  
  defp parse_sql_line({line, line_number}, state) do
    # Update progress every 1000 lines
    if rem(line_number, 1000) == 0 do
      progress = Float.round(line_number / state.total_lines * 100, 1)
      Logger.info("📈 Parsing progress: #{progress}% (#{line_number}/#{state.total_lines})")
    end
    
    trimmed_line = String.trim(line)
    updated_state = %{state | current_line: line_number}
    
    cond do
      # Skip comments and empty lines
      String.starts_with?(trimmed_line, "--") or 
      String.starts_with?(trimmed_line, "/*") or
      String.starts_with?(trimmed_line, "#") or
      trimmed_line == "" ->
        updated_state
      
      # Parse CREATE TABLE statements
      String.starts_with?(trimmed_line, "CREATE TABLE") ->
        parse_create_table(trimmed_line, updated_state)
      
      # Parse INSERT statements
      String.starts_with?(trimmed_line, "INSERT INTO") ->
        parse_insert_statement(trimmed_line, updated_state)
      
      # Parse ALTER TABLE statements (foreign keys, indexes)
      String.starts_with?(trimmed_line, "ALTER TABLE") ->
        parse_alter_table(trimmed_line, updated_state)
      
      # Parse CREATE INDEX statements
      String.starts_with?(trimmed_line, "CREATE INDEX") or
      String.starts_with?(trimmed_line, "CREATE UNIQUE INDEX") ->
        parse_create_index(trimmed_line, updated_state)
      
      # Continue parsing multi-line statements
      String.contains?(trimmed_line, "(") or String.contains?(trimmed_line, ",") ->
        parse_table_column(trimmed_line, updated_state)
      
      true ->
        updated_state
    end
  end
  
  defp parse_create_table(line, state) do
    # Extract table name from CREATE TABLE statement
    case Regex.run(~r/CREATE TABLE\s+`?(\w+)`?\s*\(/i, line) do
      [_, table_name] ->
        Logger.debug("🔍 Found table: #{table_name}")
        
        table_info = %{
          name: table_name,
          columns: [],
          primary_key: nil,
          mysql_engine: nil,
          charset: nil,
          auto_increment: nil
        }
        
        %{state | parsed_tables: Map.put(state.parsed_tables, table_name, table_info)}
      
      nil ->
        add_error(state, "Failed to parse CREATE TABLE: #{line}")
    end
  end
  
  defp parse_table_column(line, state) do
    # This is a simplified column parser - would need more robust parsing for production
    trimmed = String.trim(line)
    
    # Skip lines that don't look like column definitions
    if String.starts_with?(trimmed, ")") or 
       String.starts_with?(trimmed, "PRIMARY KEY") or
       String.starts_with?(trimmed, "KEY") or
       String.starts_with?(trimmed, "UNIQUE KEY") do
      state
    else
      # Extract column information (simplified)
      case Regex.run(~r/`?(\w+)`?\s+(\w+(?:\(\d+(?:,\d+)?\))?)/i, trimmed) do
        [_, column_name, data_type] ->
          # Find the current table being parsed
          current_table = find_current_table(state)
          if current_table do
            column_info = %{
              name: column_name,
              mysql_type: data_type,
              postgresql_type: convert_mysql_to_postgresql_type(data_type),
              nullable: !String.contains?(trimmed, "NOT NULL"),
              default: extract_default_value(trimmed),
              auto_increment: String.contains?(trimmed, "AUTO_INCREMENT")
            }
            
            updated_table = Map.update!(current_table, :columns, &[column_info | &1])
            %{state | parsed_tables: Map.put(state.parsed_tables, updated_table.name, updated_table)}
          else
            state
          end
        
        nil ->
          state
      end
    end
  end
  
  defp parse_insert_statement(line, state) do
    # Extract table name and track insert statements for data migration
    case Regex.run(~r/INSERT INTO\s+`?(\w+)`?/i, line) do
      [_, table_name] ->
        current_inserts = Map.get(state.data_inserts, table_name, [])
        updated_inserts = [line | current_inserts]
        
        %{state | data_inserts: Map.put(state.data_inserts, table_name, updated_inserts)}
      
      nil ->
        add_error(state, "Failed to parse INSERT statement: #{line}")
    end
  end
  
  defp parse_alter_table(line, state) do
    # Parse foreign key constraints and other ALTER TABLE statements
    cond do
      String.contains?(line, "FOREIGN KEY") ->
        parse_foreign_key(line, state)
      
      String.contains?(line, "ADD INDEX") ->
        parse_add_index(line, state)
      
      true ->
        state
    end
  end
  
  defp parse_create_index(line, state) do
    # Parse CREATE INDEX statements
    case Regex.run(~r/CREATE\s+(?:UNIQUE\s+)?INDEX\s+`?(\w+)`?\s+ON\s+`?(\w+)`?\s*\(([^)]+)\)/i, line) do
      [_, index_name, table_name, columns] ->
        index_info = %{
          name: index_name,
          table: table_name,
          columns: String.split(columns, ",") |> Enum.map(&String.trim/1),
          unique: String.contains?(line, "UNIQUE")
        }
        
        %{state | indexes: [index_info | state.indexes]}
      
      nil ->
        add_error(state, "Failed to parse CREATE INDEX: #{line}")
    end
  end
  
  defp parse_foreign_key(line, state) do
    # Simplified foreign key parsing
    case Regex.run(~r/FOREIGN KEY\s*\(`?(\w+)`?\)\s*REFERENCES\s+`?(\w+)`?\s*\(`?(\w+)`?\)/i, line) do
      [_, local_column, foreign_table, foreign_column] ->
        fk_info = %{
          local_column: local_column,
          foreign_table: foreign_table,
          foreign_column: foreign_column,
          line: state.current_line
        }
        
        %{state | foreign_keys: [fk_info | state.foreign_keys]}
      
      nil ->
        state
    end
  end
  
  defp parse_add_index(_line, state) do
    # Parse ADD INDEX from ALTER TABLE
    state
  end
  
  defp find_current_table(state) do
    # Find the most recently parsed table (simplified approach)
    case Map.keys(state.parsed_tables) do
      [] -> nil
      keys -> Map.get(state.parsed_tables, List.last(keys))
    end
  end
  
  defp convert_mysql_to_postgresql_type(mysql_type) do
    # Convert MySQL data types to PostgreSQL equivalents
    case String.downcase(mysql_type) do
      "int" <> _ -> "INTEGER"
      "tinyint" <> _ -> "SMALLINT"
      "smallint" <> _ -> "SMALLINT"
      "mediumint" <> _ -> "INTEGER"
      "bigint" <> _ -> "BIGINT"
      "varchar" <> rest -> "VARCHAR" <> rest
      "char" <> rest -> "CHAR" <> rest
      "text" -> "TEXT"
      "mediumtext" -> "TEXT"
      "longtext" -> "TEXT"
      "float" -> "REAL"
      "double" -> "DOUBLE PRECISION"
      "decimal" <> rest -> "DECIMAL" <> rest
      "datetime" -> "TIMESTAMP"
      "timestamp" -> "TIMESTAMP"
      "date" -> "DATE"
      "time" -> "TIME"
      "blob" -> "BYTEA"
      "mediumblob" -> "BYTEA"
      "longblob" -> "BYTEA"
      _ -> mysql_type  # Keep original if no conversion found
    end
  end
  
  defp extract_default_value(line) do
    case Regex.run(~r/DEFAULT\s+([^,\s]+)/i, line) do
      [_, default_val] -> String.trim(default_val, "'\"")
      nil -> nil
    end
  end
  
  defp add_error(state, error_message) do
    error = "Line #{state.current_line}: #{error_message}"
    %{state | errors: [error | state.errors]}
  end
  
  defp generate_migration_files(state) do
    Logger.info("📝 Generating Phoenix migration files...")
    
    # Generate main migration file
    migration_content = generate_migration_content(state)
    migration_file = Path.join(@output_dir, "001_create_eqemu_tables.exs")
    
    File.write!(migration_file, migration_content)
    Logger.info("✅ Migration file created: #{migration_file}")
    
    # Generate data type mapping file
    mapping_content = generate_type_mapping(state)
    mapping_file = Path.join(@output_dir, "mysql_to_postgresql_mapping.json")
    
    File.write!(mapping_file, mapping_content)
    Logger.info("✅ Type mapping file created: #{mapping_file}")
    
    :ok
  end
  
  defp generate_import_scripts(state) do
    Logger.info("📝 Generating data import scripts...")
    
    # Generate Elixir import script
    import_content = generate_elixir_import_script(state)
    import_file = Path.join(@output_dir, "peq_data_importer.exs")
    
    File.write!(import_file, import_content)
    Logger.info("✅ Import script created: #{import_file}")
    
    # Generate SQL conversion script
    sql_content = generate_sql_conversion_script(state)
    sql_file = Path.join(@output_dir, "convert_peq_to_postgresql.sql")
    
    File.write!(sql_file, sql_content)
    Logger.info("✅ SQL conversion script created: #{sql_file}")
    
    :ok
  end
  
  defp generate_migration_content(state) do
    tables = Map.values(state.parsed_tables)
    
    """
    defmodule PhoenixApp.Repo.Migrations.CreateEqemuTables do
      use Ecto.Migration
      
      def up do
    #{Enum.map_join(tables, "\n", &generate_table_migration/1)}
    
        # Create indexes
    #{Enum.map_join(state.indexes, "\n", &generate_index_migration/1)}
    
        # Add foreign keys
    #{Enum.map_join(state.foreign_keys, "\n", &generate_foreign_key_migration/1)}
      end
      
      def down do
    #{Enum.map_join(Enum.reverse(tables), "\n", fn table -> "    drop table(:#{table.name})" end)}
      end
    end
    """
  end
  
  defp generate_table_migration(table) do
    columns = Enum.reverse(table.columns)  # Reverse to get original order
    
    """
        create table(:#{table.name}) do
    #{Enum.map_join(columns, "\n", &generate_column_migration/1)}
          
          timestamps()
        end
    """
  end
  
  defp generate_column_migration(column) do
    type = String.downcase(column.postgresql_type)
    nullable = if column.nullable, do: "", else: ", null: false"
    default = if column.default, do: ", default: #{inspect(column.default)}", else: ""
    
    "      add :#{column.name}, :#{type}#{nullable}#{default}"
  end
  
  defp generate_index_migration(index) do
    unique = if index.unique, do: ", unique: true", else: ""
    columns = Enum.map_join(index.columns, ", ", &":#{String.trim(&1, "`")}")
    
    "    create index(:#{index.table}, [#{columns}]#{unique})"
  end
  
  defp generate_foreign_key_migration(fk) do
    "    alter table(:#{fk.foreign_table}) do\n      add :#{fk.local_column}_id, references(:#{fk.foreign_table}, on_delete: :nothing)\n    end"
  end
  
  defp generate_type_mapping(state) do
    mapping = 
      state.parsed_tables
      |> Map.values()
      |> Enum.flat_map(& &1.columns)
      |> Enum.map(fn col -> {col.mysql_type, col.postgresql_type} end)
      |> Enum.uniq()
      |> Map.new()
    
    Jason.encode!(mapping, pretty: true)
  end
  
  defp generate_elixir_import_script(state) do
    """
    # Generated PEQ Data Import Script
    # This script imports data from the parsed PEQ database
    
    defmodule PhoenixApp.PeqDataImporter do
      alias PhoenixApp.Repo
      require Logger
      
      @batch_size #{@batch_size}
      
      def import_all_data do
        Logger.info("🎮 Starting PEQ data import...")
        
    #{Enum.map_join(Map.keys(state.data_inserts), "\n", &generate_table_import_function/1)}
        
        Logger.info("✅ PEQ data import completed!")
      end
      
    #{Enum.map_join(Map.keys(state.data_inserts), "\n\n", fn table -> generate_import_function(table, state) end)}
    end
    
    # Run the import
    PhoenixApp.PeqDataImporter.import_all_data()
    """
  end
  
  defp generate_table_import_function(table_name) do
    "    import_#{table_name}()"
  end
  
  defp generate_import_function(table_name, state) do
    inserts = Map.get(state.data_inserts, table_name, [])
    insert_count = length(inserts)
    
    """
      defp import_#{table_name} do
        Logger.info("📊 Importing #{table_name} (#{insert_count} records)...")
        
        # TODO: Parse and convert INSERT statements for #{table_name}
        # Original inserts: #{insert_count} statements
        
        Logger.info("✅ #{table_name} import completed")
      end
    """
  end
  
  defp generate_sql_conversion_script(state) do
    """
    -- Generated SQL Conversion Script
    -- Converts MySQL PEQ data to PostgreSQL format
    
    -- Disable foreign key checks during import
    SET session_replication_role = replica;
    
    #{Enum.map_join(Map.keys(state.parsed_tables), "\n\n", &generate_table_conversion/1)}
    
    -- Re-enable foreign key checks
    SET session_replication_role = DEFAULT;
    
    -- Update sequences for auto-increment columns
    #{Enum.map_join(Map.keys(state.parsed_tables), "\n", &generate_sequence_update/1)}
    """
  end
  
  defp generate_table_conversion(table_name) do
    """
    -- Convert #{table_name} data
    -- TODO: Add specific conversion logic for #{table_name}
    """
  end
  
  defp generate_sequence_update(table_name) do
    "-- SELECT setval('#{table_name}_id_seq', (SELECT MAX(id) FROM #{table_name}));"
  end
  
  defp print_parsing_summary(state) do
    Logger.info("📊 PEQ Parsing Summary:")
    Logger.info("   📋 Tables parsed: #{map_size(state.parsed_tables)}")
    Logger.info("   📊 Data inserts found: #{map_size(state.data_inserts)}")
    Logger.info("   🔗 Foreign keys: #{length(state.foreign_keys)}")
    Logger.info("   📇 Indexes: #{length(state.indexes)}")
    Logger.info("   ⚠️  Warnings: #{length(state.errors)}")
    
    # Show top tables by insert count
    top_tables = 
      state.data_inserts
      |> Enum.map(fn {table, inserts} -> {table, length(inserts)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
    
    Logger.info("   🔝 Top tables by data volume:")
    Enum.each(top_tables, fn {table, count} ->
      Logger.info("      #{table}: #{count} inserts")
    end)
  end
end