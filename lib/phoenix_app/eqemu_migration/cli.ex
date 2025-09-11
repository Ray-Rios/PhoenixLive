defmodule PhoenixApp.EqemuMigration.CLI do
  @moduledoc """
  Command-line interface for EQEMU database migration tools.
  Provides easy access to analysis and migration functionality.
  """

  alias PhoenixApp.EqemuMigration.DatabaseAnalyzer
  alias PhoenixApp.EqemuMigration.RowCounter
  alias PhoenixApp.EqemuMigration.TableInspector
  alias PhoenixApp.EqemuMigration.SqlTransformer

  @default_dump_path "eqemu/mySQL_to_Postgres_Tool/postgres_peq.sql"

  @doc """
  Run a quick analysis of the dump file.
  """
  def quick_analysis(file_path \\ @default_dump_path) do
    IO.puts("🔍 Starting quick analysis of #{file_path}...")
    
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        IO.puts("📁 File size: #{format_bytes(size)}")
        
        case RowCounter.count_all_rows(file_path) do
          {:ok, counts} ->
            display_row_counts(counts)
            
          {:error, reason} ->
            IO.puts("❌ Error counting rows: #{inspect(reason)}")
        end
        
      {:error, reason} ->
        IO.puts("❌ Cannot access file: #{inspect(reason)}")
    end
  end

  @doc """
  Run a full analysis of the dump file.
  """
  def full_analysis(file_path \\ @default_dump_path) do
    IO.puts("🔍 Starting full analysis of #{file_path}...")
    
    case DatabaseAnalyzer.analyze_dump(file_path) do
      {:ok, result} ->
        display_full_analysis(result)
        
      {:error, reason} ->
        IO.puts("❌ Analysis failed: #{inspect(reason)}")
    end
  end

  @doc """
  Analyze a specific table in detail.
  """
  def analyze_table(table_name, file_path \\ @default_dump_path) do
    IO.puts("🔍 Analyzing table: #{table_name}")
    
    case RowCounter.count_table_rows(file_path, table_name) do
      {:ok, count} ->
        IO.puts("📊 Row count: #{format_number(count)}")
        
        if count > 6000 do
          IO.puts("⚠️  This table exceeds the 6,000 row limit and will need trimming")
        else
          IO.puts("✅ This table is within the 6,000 row limit")
        end
        
      {:error, reason} ->
        IO.puts("❌ Error analyzing table: #{inspect(reason)}")
    end
  end

  @doc """
  Transform the SQL file to match Phoenix schema.
  """
  def transform_sql(opts \\ []) do
    IO.puts("🔄 Starting SQL transformation for Phoenix compatibility...")
    
    case SqlTransformer.run_transformation(opts) do
      {:ok, result} ->
        IO.puts("✅ SQL transformation completed successfully!")
        IO.puts("📁 Input file: #{result.input}")
        IO.puts("📁 Output file: #{result.output}")
        IO.puts("🎯 Ready to import the transformed SQL file into Phoenix database")
        
      {:error, reason} ->
        IO.puts("❌ SQL transformation failed: #{inspect(reason)}")
    end
  end

  @doc """
  List all tables that exceed the row limit.
  """
  def list_large_tables(limit \\ 6000, file_path \\ @default_dump_path) do
    IO.puts("🔍 Finding tables with more than #{format_number(limit)} rows...")
    
    case RowCounter.count_all_rows(file_path) do
      {:ok, counts} ->
        large_tables = RowCounter.get_large_tables(counts, limit)
        
        if Enum.empty?(large_tables) do
          IO.puts("✅ No tables exceed the #{format_number(limit)} row limit")
        else
          IO.puts("⚠️  Found #{length(large_tables)} tables that exceed the limit:")
          
          large_tables
          |> Enum.each(fn table ->
            count = counts[table]
            excess = count - limit
            IO.puts("  • #{table}: #{format_number(count)} rows (+#{format_number(excess)} over limit)")
          end)
        end
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  @doc """
  Display row count summary.
  """
  defp display_row_counts(counts) do
    IO.puts(RowCounter.format_table_counts(counts))
  end

  @doc """
  Display full analysis results.
  """
  defp display_full_analysis(result) do
    IO.puts("\n=== EQEMU Database Analysis Results ===")
    IO.puts("📅 Analysis completed: #{DateTime.to_string(result.analysis_timestamp)}")
    IO.puts("📁 File size: #{format_bytes(result.total_size_bytes)}")
    IO.puts("📊 Total tables found: #{map_size(result.tables)}")
    
    # Calculate total rows
    total_rows = 
      result.tables
      |> Map.values()
      |> Enum.map(& &1.row_count)
      |> Enum.sum()
    
    IO.puts("📈 Total rows across all tables: #{format_number(total_rows)}")
    
    # Show largest tables
    if not Enum.empty?(result.largest_tables) do
      IO.puts("\n🏆 Largest tables by row count:")
      
      result.largest_tables
      |> Enum.take(10)
      |> Enum.with_index(1)
      |> Enum.each(fn {table_name, index} ->
        table_info = result.tables[table_name]
        marker = if table_info.row_count > 6000, do: " ⚠️", else: ""
        IO.puts("  #{index}. #{table_name}: #{format_number(table_info.row_count)} rows#{marker}")
      end)
    end
    
    # Show tables that need trimming
    large_tables = 
      result.tables
      |> Enum.filter(fn {_name, info} -> info.row_count > 6000 end)
      |> length()
    
    if large_tables > 0 do
      IO.puts("\n⚠️  #{large_tables} tables exceed the 6,000 row limit and will need trimming")
    else
      IO.puts("\n✅ All tables are within the 6,000 row limit")
    end
  end

  @doc """
  Format bytes into human-readable format.
  """
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

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