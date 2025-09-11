defmodule PhoenixApp.EqemuMigration.DatabaseAnalyzer do
  @moduledoc """
  Analyzes the postgres_peq.sql dump file to extract table structures,
  row counts, and other metadata needed for migration planning.
  """

  require Logger

  @type table_info :: %{
    name: String.t(),
    columns: [String.t()],
    primary_key: String.t() | nil,
    foreign_keys: [{String.t(), String.t(), String.t()}],
    indexes: [String.t()],
    row_count: integer(),
    create_statement: String.t()
  }

  @type analysis_result :: %{
    tables: %{String.t() => table_info()},
    total_size_bytes: integer(),
    largest_tables: [String.t()],
    analysis_timestamp: DateTime.t()
  }

  @doc """
  Analyze the postgres_peq.sql dump file.
  Processes the file in streaming fashion to handle large files efficiently.
  """
  @spec analyze_dump(String.t()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze_dump(file_path) do
    Logger.info("Starting analysis of dump file: #{file_path}")
    
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        Logger.info("File size: #{format_bytes(size)}")
        
        result = %{
          tables: %{},
          total_size_bytes: size,
          largest_tables: [],
          analysis_timestamp: DateTime.utc_now()
        }
        
        case stream_analyze_file(file_path, result) do
          {:ok, final_result} ->
            final_result = finalize_analysis(final_result)
            Logger.info("Analysis complete. Found #{map_size(final_result.tables)} tables")
            {:ok, final_result}
          
          {:error, reason} ->
            Logger.error("Analysis failed: #{inspect(reason)}")
            {:error, reason}
        end
      
      {:error, reason} ->
        Logger.error("Cannot access file #{file_path}: #{inspect(reason)}")
        {:error, {:file_access, reason}}
    end
  end

  @doc """
  Stream through the SQL file and analyze its contents.
  """
  defp stream_analyze_file(file_path, initial_result) do
    try do
      file_path
      |> File.stream!([], :line)
      |> Enum.reduce_while({:ok, initial_result, %{current_table: nil, in_insert: false, row_count: 0}}, 
           &process_line/2)
      |> case do
        {:ok, result, _state} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, {:stream_error, e}}
    end
  end

  @doc """
  Process each line of the SQL dump file.
  """
  defp process_line(line, {:ok, result, state}) do
    line = String.trim(line)
    
    cond do
      # Skip comments and empty lines
      String.starts_with?(line, "--") or String.length(line) == 0 ->
        {:cont, {:ok, result, state}}
      
      # Detect CREATE TABLE statements
      String.starts_with?(line, "CREATE TABLE") or String.starts_with?(line, "CREATE TEMPORARY TABLE") ->
        case extract_table_name(line) do
          {:ok, table_name} ->
            Logger.debug("Found table: #{table_name}")
            new_state = %{state | current_table: table_name, in_insert: false, row_count: 0}
            {:cont, {:ok, result, new_state}}
          
          {:error, _} ->
            {:cont, {:ok, result, state}}
        end
      
      # Detect INSERT statements
      String.starts_with?(line, "INSERT INTO") ->
        case extract_insert_table_name(line) do
          {:ok, table_name} ->
            row_count = count_insert_rows(line)
            new_state = %{state | current_table: table_name, in_insert: true, row_count: row_count}
            {:cont, {:ok, result, new_state}}
          
          {:error, _} ->
            {:cont, {:ok, result, state}}
        end
      
      # Continue counting rows in multi-line INSERT
      state.in_insert and (String.contains?(line, "),(") or String.ends_with?(line, ");")) ->
        additional_rows = count_insert_rows(line)
        new_row_count = state.row_count + additional_rows
        
        # If this line ends the INSERT, update the table info
        if String.ends_with?(line, ");") do
          updated_result = update_table_row_count(result, state.current_table, new_row_count)
          new_state = %{state | in_insert: false, row_count: 0}
          {:cont, {:ok, updated_result, new_state}}
        else
          new_state = %{state | row_count: new_row_count}
          {:cont, {:ok, result, new_state}}
        end
      
      # Detect table structure information
      String.contains?(line, "PRIMARY KEY") ->
        case state.current_table do
          nil -> {:cont, {:ok, result, state}}
          table_name ->
            primary_key = extract_primary_key(line)
            updated_result = update_table_primary_key(result, table_name, primary_key)
            {:cont, {:ok, updated_result, state}}
        end
      
      true ->
        {:cont, {:ok, result, state}}
    end
  end

  defp process_line(_line, {:error, reason}), do: {:halt, {:error, reason}}

  @doc """
  Extract table name from CREATE TABLE statement.
  """
  defp extract_table_name(line) do
    case Regex.run(~r/CREATE (?:TEMPORARY )?TABLE (?:IF NOT EXISTS )?`?(\w+)`?/i, line) do
      [_, table_name] -> {:ok, String.downcase(table_name)}
      _ -> {:error, :no_table_name}
    end
  end

  @doc """
  Extract table name from INSERT INTO statement.
  """
  defp extract_insert_table_name(line) do
    case Regex.run(~r/INSERT INTO `?(\w+)`?/i, line) do
      [_, table_name] -> {:ok, String.downcase(table_name)}
      _ -> {:error, :no_table_name}
    end
  end

  @doc """
  Count the number of rows in an INSERT statement by counting value groups.
  """
  defp count_insert_rows(line) do
    # Count occurrences of "),(" which indicates row separators
    separators = length(Regex.scan(~r/\),\s*\(/, line))
    
    # If there are separators, there's one more row than separators
    # If no separators but contains VALUES, there's at least 1 row
    cond do
      separators > 0 -> separators + 1
      String.contains?(line, "VALUES") -> 1
      true -> 0
    end
  end

  @doc """
  Extract primary key information from table definition line.
  """
  defp extract_primary_key(line) do
    case Regex.run(~r/PRIMARY KEY \(`?(\w+)`?\)/i, line) do
      [_, key_name] -> key_name
      _ -> nil
    end
  end

  @doc """
  Update table row count in the analysis result.
  """
  defp update_table_row_count(result, table_name, row_count) do
    table_info = Map.get(result.tables, table_name, %{
      name: table_name,
      columns: [],
      primary_key: nil,
      foreign_keys: [],
      indexes: [],
      row_count: 0,
      create_statement: ""
    })
    
    updated_table = %{table_info | row_count: row_count}
    %{result | tables: Map.put(result.tables, table_name, updated_table)}
  end

  @doc """
  Update table primary key in the analysis result.
  """
  defp update_table_primary_key(result, table_name, primary_key) do
    case Map.get(result.tables, table_name) do
      nil -> result
      table_info ->
        updated_table = %{table_info | primary_key: primary_key}
        %{result | tables: Map.put(result.tables, table_name, updated_table)}
    end
  end

  @doc """
  Finalize the analysis by sorting tables by size and calculating statistics.
  """
  defp finalize_analysis(result) do
    # Sort tables by row count to identify largest tables
    largest_tables = 
      result.tables
      |> Enum.sort_by(fn {_name, info} -> info.row_count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {name, _info} -> name end)
    
    %{result | largest_tables: largest_tables}
  end

  @doc """
  Format bytes into human-readable format.
  """
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  @doc """
  Get information about a specific table.
  """
  @spec get_table_info(String.t()) :: table_info() | nil
  def get_table_info(table_name) do
    # This would typically load from a cached analysis result
    # For now, return nil - this will be implemented when we have persistent storage
    nil
  end

  @doc """
  Count rows in a specific table from the dump.
  """
  @spec count_table_rows(String.t()) :: integer()
  def count_table_rows(table_name) do
    # This would typically load from a cached analysis result
    # For now, return 0 - this will be implemented when we have persistent storage
    0
  end
end