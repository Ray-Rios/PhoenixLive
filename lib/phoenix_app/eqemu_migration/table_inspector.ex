defmodule PhoenixApp.EqemuMigration.TableInspector do
  @moduledoc """
  Provides detailed table structure inspection functionality.
  Extracts column definitions, constraints, and relationships from SQL dump.
  """

  require Logger

  @type column_info :: %{
    name: String.t(),
    type: String.t(),
    nullable: boolean(),
    default: String.t() | nil,
    auto_increment: boolean()
  }

  @type constraint_info :: %{
    type: :primary_key | :foreign_key | :unique | :check,
    columns: [String.t()],
    reference_table: String.t() | nil,
    reference_columns: [String.t()] | nil
  }

  @type table_structure :: %{
    name: String.t(),
    columns: [column_info()],
    constraints: [constraint_info()],
    indexes: [String.t()],
    engine: String.t() | nil,
    charset: String.t() | nil
  }

  @doc """
  Extract detailed table structure from CREATE TABLE statement.
  """
  @spec extract_table_structure(String.t()) :: {:ok, table_structure()} | {:error, term()}
  def extract_table_structure(create_statement) do
    case parse_create_table(create_statement) do
      {:ok, structure} ->
        Logger.debug("Extracted structure for table: #{structure.name}")
        {:ok, structure}
      
      {:error, reason} ->
        Logger.error("Failed to parse table structure: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parse a complete CREATE TABLE statement.
  """
  defp parse_create_table(statement) do
    # Clean up the statement
    cleaned = statement
    |> String.replace(~r/\s+/, " ")
    |> String.trim()

    case extract_table_name_from_create(cleaned) do
      {:ok, table_name} ->
        columns = extract_columns(cleaned)
        constraints = extract_constraints(cleaned)
        indexes = extract_indexes(cleaned)
        engine = extract_engine(cleaned)
        charset = extract_charset(cleaned)

        structure = %{
          name: table_name,
          columns: columns,
          constraints: constraints,
          indexes: indexes,
          engine: engine,
          charset: charset
        }

        {:ok, structure}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extract table name from CREATE TABLE statement.
  """
  defp extract_table_name_from_create(statement) do
    case Regex.run(~r/CREATE (?:TEMPORARY )?TABLE (?:IF NOT EXISTS )?`?(\w+)`?/i, statement) do
      [_, table_name] -> {:ok, String.downcase(table_name)}
      _ -> {:error, :no_table_name}
    end
  end

  @doc """
  Extract column definitions from CREATE TABLE statement.
  """
  defp extract_columns(statement) do
    # Extract the content between parentheses
    case Regex.run(~r/\((.*)\)/s, statement) do
      [_, content] ->
        content
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&is_column_definition/1)
        |> Enum.map(&parse_column_definition/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Check if a line is a column definition (not a constraint).
  """
  defp is_column_definition(line) do
    line = String.trim(line)
    
    # Skip constraint definitions
    not (String.starts_with?(line, "PRIMARY KEY") or
         String.starts_with?(line, "FOREIGN KEY") or
         String.starts_with?(line, "UNIQUE KEY") or
         String.starts_with?(line, "KEY") or
         String.starts_with?(line, "INDEX") or
         String.starts_with?(line, "CONSTRAINT"))
  end

  @doc """
  Parse individual column definition.
  """
  defp parse_column_definition(line) do
    line = String.trim(line)
    
    # Basic regex to extract column info
    case Regex.run(~r/`?(\w+)`?\s+(\w+(?:\(\d+(?:,\d+)?\))?)\s*(.*)/i, line) do
      [_, name, type, modifiers] ->
        %{
          name: String.downcase(name),
          type: String.downcase(type),
          nullable: not String.contains?(modifiers, "NOT NULL"),
          default: extract_default_value(modifiers),
          auto_increment: String.contains?(modifiers, "AUTO_INCREMENT")
        }

      _ ->
        nil
    end
  end

  @doc """
  Extract default value from column modifiers.
  """
  defp extract_default_value(modifiers) do
    case Regex.run(~r/DEFAULT\s+([^,\s]+)/i, modifiers) do
      [_, value] -> String.trim(value, "'\"")
      _ -> nil
    end
  end

  @doc """
  Extract constraint definitions from CREATE TABLE statement.
  """
  defp extract_constraints(statement) do
    case Regex.run(~r/\((.*)\)/s, statement) do
      [_, content] ->
        content
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&is_constraint_definition/1)
        |> Enum.map(&parse_constraint_definition/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Check if a line is a constraint definition.
  """
  defp is_constraint_definition(line) do
    line = String.trim(line)
    
    String.starts_with?(line, "PRIMARY KEY") or
    String.starts_with?(line, "FOREIGN KEY") or
    String.starts_with?(line, "UNIQUE KEY") or
    String.starts_with?(line, "CONSTRAINT")
  end

  @doc """
  Parse constraint definition.
  """
  defp parse_constraint_definition(line) do
    line = String.trim(line)
    
    cond do
      String.starts_with?(line, "PRIMARY KEY") ->
        case Regex.run(~r/PRIMARY KEY \(([^)]+)\)/i, line) do
          [_, columns] ->
            column_list = parse_column_list(columns)
            %{type: :primary_key, columns: column_list, reference_table: nil, reference_columns: nil}
          _ -> nil
        end

      String.starts_with?(line, "FOREIGN KEY") ->
        parse_foreign_key_constraint(line)

      String.starts_with?(line, "UNIQUE KEY") ->
        case Regex.run(~r/UNIQUE KEY `?\w+`? \(([^)]+)\)/i, line) do
          [_, columns] ->
            column_list = parse_column_list(columns)
            %{type: :unique, columns: column_list, reference_table: nil, reference_columns: nil}
          _ -> nil
        end

      true ->
        nil
    end
  end

  @doc """
  Parse foreign key constraint definition.
  """
  defp parse_foreign_key_constraint(line) do
    case Regex.run(~r/FOREIGN KEY \(([^)]+)\) REFERENCES `?(\w+)`? \(([^)]+)\)/i, line) do
      [_, columns, ref_table, ref_columns] ->
        %{
          type: :foreign_key,
          columns: parse_column_list(columns),
          reference_table: String.downcase(ref_table),
          reference_columns: parse_column_list(ref_columns)
        }
      _ -> nil
    end
  end

  @doc """
  Parse comma-separated column list.
  """
  defp parse_column_list(columns_str) do
    columns_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.trim(&1, "`'\""))
    |> Enum.map(&String.downcase/1)
  end

  @doc """
  Extract index definitions (simplified).
  """
  defp extract_indexes(statement) do
    case Regex.run(~r/\((.*)\)/s, statement) do
      [_, content] ->
        content
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn line -> String.starts_with?(line, "KEY") end)
        |> Enum.map(&extract_index_name/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Extract index name from KEY definition.
  """
  defp extract_index_name(line) do
    case Regex.run(~r/KEY `?(\w+)`?/i, line) do
      [_, index_name] -> String.downcase(index_name)
      _ -> nil
    end
  end

  @doc """
  Extract engine information.
  """
  defp extract_engine(statement) do
    case Regex.run(~r/ENGINE=(\w+)/i, statement) do
      [_, engine] -> String.downcase(engine)
      _ -> nil
    end
  end

  @doc """
  Extract charset information.
  """
  defp extract_charset(statement) do
    case Regex.run(~r/CHARSET=(\w+)/i, statement) do
      [_, charset] -> String.downcase(charset)
      _ -> nil
    end
  end
end