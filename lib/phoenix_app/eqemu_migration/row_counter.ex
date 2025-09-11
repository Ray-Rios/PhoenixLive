defmodule PhoenixApp.EqemuMigration.RowCounter do
  @moduledoc """
  Provides efficient row counting functionality for large SQL dump files.
  Handles streaming analysis to count rows without loading entire file into memory.
  """

  require Logger

  @type table_counts :: %{String.t() => integer()}

  @doc """
  Count rows for all tables in the SQL dump file.
  Returns a map of table_name => row_count.
  """
  @spec count_all_rows(String.t()) :: {:ok, table_counts()} | {:error, term()}
  def count_all_rows(file_path) do
    Logger.info("Starting row count analysis for: #{file_path}")
    
    try do
      result = 
        file_path
        |> File.stream!([], :line)
        |> Enum.reduce(%{}, &process_line_for_counting/2)
      
      total_rows = result |> Map.values() |> Enum.sum()
      Logger.info("Row counting complete. Total rows across all tables: #{total_rows}")
      
      {:ok, result}
    rescue
      e ->
        Logger.error("Row counting failed: #{inspect(e)}")
        {:error, {:counting_error, e}}
    end
  end

  @doc """
  Count rows for a specific table in the SQL dump file.
  """
  @spec count_table_rows(String.t(), String.t()) :: {:ok, integer()} | {:error, term()}
  def count_table_rows(file_path, table_name) do
    Logger.info("Counting rows for table: #{table_name}")
    
    try do
      count = 
        file_path
        |> File.stream!([], :line)
        |> Enum.reduce(0, fn line, acc ->
          case extract_insert_info(line) do
            {:ok, ^table_name, row_count} -> acc + row_count
            _ -> acc
          end
        end)
      
      Logger.info("Table #{table_name} has #{count} rows")
      {:ok, count}
    rescue
      e ->
        Logger.error("Row counting failed for table #{table_name}: #{inspect(e)}")
        {:error, {:counting_error, e}}
    end
  end

  @doc """
  Process a single line for row counting.
  """
  defp process_line_for_counting(line, acc) do
    case extract_insert_info(line) do
      {:ok, table_name, row_count} ->
        current_count = Map.get(acc, table_name, 0)
        Map.put(acc, table_name, current_count + row_count)
      
      :not_insert ->
        acc
    end
  end

  @doc """
  Extract INSERT information from a line.
  Returns {:ok, table_name, row_count} or :not_insert.
  """
  defp extract_insert_info(line) do
    line = String.trim(line)
    
    if String.starts_with?(line, "INSERT INTO") do
      case extract_table_name_from_insert(line) do
        {:ok, table_name} ->
          row_count = count_rows_in_insert(line)
          {:ok, table_name, row_count}
        
        {:error, _} ->
          :not_insert
      end
    else
      :not_insert
    end
  end

  @doc """
  Extract table name from INSERT statement.
  """
  defp extract_table_name_from_insert(line) do
    case Regex.run(~r/INSERT INTO `?(\w+)`?/i, line) do
      [_, table_name] -> {:ok, String.downcase(table_name)}
      _ -> {:error, :no_table_name}
    end
  end

  @doc """
  Count rows in an INSERT statement.
  Handles both single-line and multi-line INSERT statements.
  """
  defp count_rows_in_insert(line) do
    cond do
      # Multi-row INSERT: count "),(" separators + 1
      String.contains?(line, "),(") ->
        separators = length(Regex.scan(~r/\),\s*\(/, line))
        separators + 1
      
      # Single row INSERT or start of multi-row
      String.contains?(line, "VALUES") ->
        1
      
      # Continuation line with row separators
      String.contains?(line, "),(") ->
        length(Regex.scan(~r/\),\s*\(/, line))
      
      # End of multi-row INSERT
      String.ends_with?(line, ");") and String.contains?(line, "(") ->
        1
      
      true ->
        0
    end
  end

  @doc """
  Get tables that exceed a specified row count threshold.
  """
  @spec get_large_tables(table_counts(), integer()) :: [String.t()]
  def get_large_tables(table_counts, threshold \\ 6000) do
    table_counts
    |> Enum.filter(fn {_table, count} -> count > threshold end)
    |> Enum.sort_by(fn {_table, count} -> count end, :desc)
    |> Enum.map(fn {table, _count} -> table end)
  end

  @doc """
  Get summary statistics for table sizes.
  """
  @spec get_size_statistics(table_counts()) :: %{
    total_tables: integer(),
    total_rows: integer(),
    largest_table: {String.t(), integer()} | nil,
    average_rows: float(),
    tables_over_6000: integer()
  }
  def get_size_statistics(table_counts) do
    counts = Map.values(table_counts)
    total_rows = Enum.sum(counts)
    total_tables = map_size(table_counts)
    
    largest_table = 
      case Enum.max_by(table_counts, fn {_table, count} -> count end, fn -> nil end) do
        nil -> nil
        {table, count} -> {table, count}
      end
    
    average_rows = if total_tables > 0, do: total_rows / total_tables, else: 0.0
    
    tables_over_6000 = 
      table_counts
      |> Enum.count(fn {_table, count} -> count > 6000 end)
    
    %{
      total_tables: total_tables,
      total_rows: total_rows,
      largest_table: largest_table,
      average_rows: Float.round(average_rows, 2),
      tables_over_6000: tables_over_6000
    }
  end

  @doc """
  Format row counts for display.
  """
  @spec format_table_counts(table_counts()) :: String.t()
  def format_table_counts(table_counts) do
    stats = get_size_statistics(table_counts)
    
    header = """
    
    === Table Row Count Summary ===
    Total Tables: #{stats.total_tables}
    Total Rows: #{format_number(stats.total_rows)}
    Average Rows per Table: #{stats.average_rows}
    Tables over 6,000 rows: #{stats.tables_over_6000}
    """
    
    largest_info = case stats.largest_table do
      nil -> ""
      {table, count} -> "Largest Table: #{table} (#{format_number(count)} rows)\n"
    end
    
    table_list = 
      table_counts
      |> Enum.sort_by(fn {_table, count} -> count end, :desc)
      |> Enum.take(20)
      |> Enum.map(fn {table, count} -> 
        marker = if count > 6000, do: " ⚠️", else: ""
        "  #{table}: #{format_number(count)} rows#{marker}"
      end)
      |> Enum.join("\n")
    
    header <> largest_info <> "\nTop 20 Tables by Row Count:\n" <> table_list
  end

  @doc """
  Format numbers with commas for readability.
  """
  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end