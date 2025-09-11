defmodule PhoenixApp.EQEmuGame.ChunkedImporter do
  @moduledoc """
  Chunked import system for processing large PEQ datasets efficiently.
  
  This module handles importing large amounts of data in manageable chunks
  to prevent memory issues and provide progress tracking during import.
  """
  
  alias PhoenixApp.Repo
  require Logger
  
  @default_batch_size 1000
  @default_timeout 60_000  # 60 seconds per batch
  
  defstruct [
    :table_name,
    :source_file,
    :batch_size,
    :timeout,
    :total_records,
    :processed_records,
    :failed_records,
    :start_time,
    :transformer_function,
    :validator_function,
    :progress_callback
  ]
  
  def new(opts \\ []) do
    %__MODULE__{
      table_name: Keyword.fetch!(opts, :table_name),
      source_file: Keyword.get(opts, :source_file),
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      total_records: 0,
      processed_records: 0,
      failed_records: 0,
      start_time: nil,
      transformer_function: Keyword.get(opts, :transformer),
      validator_function: Keyword.get(opts, :validator),
      progress_callback: Keyword.get(opts, :progress_callback)
    }
  end
  
  def import_from_sql_inserts(importer, sql_inserts) when is_list(sql_inserts) do
    Logger.info("🚀 Starting chunked import for #{importer.table_name}")
    Logger.info("📊 Total INSERT statements: #{length(sql_inserts)}")
    
    updated_importer = %{importer | 
      total_records: length(sql_inserts),
      start_time: DateTime.utc_now()
    }
    
    # Process inserts in chunks
    sql_inserts
    |> Enum.chunk_every(importer.batch_size)
    |> Enum.with_index(1)
    |> Enum.reduce(updated_importer, &process_chunk/2)
    |> finalize_import()
  end
  
  def import_from_csv(importer, csv_file_path) do
    Logger.info("🚀 Starting chunked CSV import for #{importer.table_name}")
    Logger.info("📁 Source file: #{csv_file_path}")
    
    unless File.exists?(csv_file_path) do
      Logger.error("❌ CSV file not found: #{csv_file_path}")
      {:error, :file_not_found}
    else
    
    # Count total lines for progress tracking
    total_lines = count_csv_lines(csv_file_path)
    
    updated_importer = %{importer | 
      source_file: csv_file_path,
      total_records: total_lines,
      start_time: DateTime.utc_now()
    }
    
      # Process CSV in chunks
      csv_file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.chunk_every(importer.batch_size)
      |> Stream.with_index(1)
      |> Enum.reduce(updated_importer, &process_csv_chunk/2)
      |> finalize_import()
    end
  end
  
  def import_from_json_lines(importer, jsonl_file_path) do
    Logger.info("🚀 Starting chunked JSONL import for #{importer.table_name}")
    Logger.info("📁 Source file: #{jsonl_file_path}")
    
    unless File.exists?(jsonl_file_path) do
      Logger.error("❌ JSONL file not found: #{jsonl_file_path}")
      {:error, :file_not_found}
    else
    
    # Count total lines
    total_lines = count_file_lines(jsonl_file_path)
    
    updated_importer = %{importer | 
      source_file: jsonl_file_path,
      total_records: total_lines,
      start_time: DateTime.utc_now()
    }
    
      # Process JSONL in chunks
      jsonl_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.chunk_every(importer.batch_size)
      |> Stream.with_index(1)
      |> Enum.reduce(updated_importer, &process_json_chunk/2)
      |> finalize_import()
    end
  end
  
  defp process_chunk({sql_inserts, chunk_index}, importer) do
    Logger.info("📦 Processing chunk #{chunk_index} (#{length(sql_inserts)} records)")
    
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Parse SQL INSERT statements and extract data
      parsed_records = 
        sql_inserts
        |> Enum.map(&parse_sql_insert/1)
        |> Enum.filter(& &1 != nil)
      
      # Transform records if transformer function provided
      transformed_records = 
        if importer.transformer_function do
          Enum.map(parsed_records, importer.transformer_function)
        else
          parsed_records
        end
      
      # Validate records if validator function provided
      valid_records = 
        if importer.validator_function do
          Enum.filter(transformed_records, importer.validator_function)
        else
          transformed_records
        end
      
      # Insert records in a transaction
      {insert_count, failed_count} = insert_records_batch(importer.table_name, valid_records)
      
      processing_time = System.monotonic_time(:millisecond) - start_time
      
      Logger.info("✅ Chunk #{chunk_index} completed: #{insert_count} inserted, #{failed_count} failed (#{processing_time}ms)")
      
      # Update progress
      updated_importer = %{importer | 
        processed_records: importer.processed_records + insert_count,
        failed_records: importer.failed_records + failed_count
      }
      
      # Call progress callback if provided
      if importer.progress_callback do
        progress = calculate_progress(updated_importer)
        importer.progress_callback.(progress)
      end
      
      updated_importer
      
    rescue
      error ->
        Logger.error("❌ Chunk #{chunk_index} failed: #{inspect(error)}")
        %{importer | failed_records: importer.failed_records + length(sql_inserts)}
    end
  end
  
  defp process_csv_chunk({csv_rows, chunk_index}, importer) do
    Logger.info("📦 Processing CSV chunk #{chunk_index} (#{length(csv_rows)} records)")
    
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Transform CSV rows to database records
      transformed_records = 
        csv_rows
        |> Enum.map(&csv_row_to_record/1)
        |> Enum.filter(& &1 != nil)
      
      # Apply transformer if provided
      final_records = 
        if importer.transformer_function do
          Enum.map(transformed_records, importer.transformer_function)
        else
          transformed_records
        end
      
      # Validate records
      valid_records = 
        if importer.validator_function do
          Enum.filter(final_records, importer.validator_function)
        else
          final_records
        end
      
      # Insert records
      {insert_count, failed_count} = insert_records_batch(importer.table_name, valid_records)
      
      processing_time = System.monotonic_time(:millisecond) - start_time
      
      Logger.info("✅ CSV chunk #{chunk_index} completed: #{insert_count} inserted, #{failed_count} failed (#{processing_time}ms)")
      
      updated_importer = %{importer | 
        processed_records: importer.processed_records + insert_count,
        failed_records: importer.failed_records + failed_count
      }
      
      if importer.progress_callback do
        progress = calculate_progress(updated_importer)
        importer.progress_callback.(progress)
      end
      
      updated_importer
      
    rescue
      error ->
        Logger.error("❌ CSV chunk #{chunk_index} failed: #{inspect(error)}")
        %{importer | failed_records: importer.failed_records + length(csv_rows)}
    end
  end
  
  defp process_json_chunk({json_records, chunk_index}, importer) do
    Logger.info("📦 Processing JSON chunk #{chunk_index} (#{length(json_records)} records)")
    
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Transform JSON records
      transformed_records = 
        if importer.transformer_function do
          Enum.map(json_records, importer.transformer_function)
        else
          json_records
        end
      
      # Validate records
      valid_records = 
        if importer.validator_function do
          Enum.filter(transformed_records, importer.validator_function)
        else
          transformed_records
        end
      
      # Insert records
      {insert_count, failed_count} = insert_records_batch(importer.table_name, valid_records)
      
      processing_time = System.monotonic_time(:millisecond) - start_time
      
      Logger.info("✅ JSON chunk #{chunk_index} completed: #{insert_count} inserted, #{failed_count} failed (#{processing_time}ms)")
      
      updated_importer = %{importer | 
        processed_records: importer.processed_records + insert_count,
        failed_records: importer.failed_records + failed_count
      }
      
      if importer.progress_callback do
        progress = calculate_progress(updated_importer)
        importer.progress_callback.(progress)
      end
      
      updated_importer
      
    rescue
      error ->
        Logger.error("❌ JSON chunk #{chunk_index} failed: #{inspect(error)}")
        %{importer | failed_records: importer.failed_records + length(json_records)}
    end
  end
  
  defp insert_records_batch(_table_name, records) when length(records) == 0 do
    {0, 0}
  end
  
  defp insert_records_batch(table_name, records) do
    try do
      # Add timestamps to all records
      timestamped_records = 
        records
        |> Enum.map(&add_timestamps/1)
        |> Enum.map(&add_uuid_id/1)
      
      # Use Repo.insert_all for batch insert
      {insert_count, _} = Repo.insert_all(table_name, timestamped_records, 
        on_conflict: :nothing,
        timeout: @default_timeout
      )
      
      {insert_count, length(records) - insert_count}
      
    rescue
      error ->
        Logger.error("❌ Batch insert failed for #{table_name}: #{inspect(error)}")
        {0, length(records)}
    end
  end
  
  defp parse_sql_insert(sql_line) do
    # Parse INSERT INTO statements to extract data
    # This is a simplified parser - production would need more robust parsing
    case Regex.run(~r/INSERT INTO\s+`?(\w+)`?\s+(?:\([^)]+\))?\s*VALUES\s*\(([^)]+)\)/i, sql_line) do
      [_, _table, values_str] ->
        # Parse values (simplified - would need proper SQL value parsing)
        values = 
          values_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_sql_value/1)
        
        # Convert to map (would need column mapping in production)
        %{raw_values: values, sql_line: sql_line}
      
      nil ->
        nil
    end
  end
  
  defp parse_sql_value(value_str) do
    trimmed = String.trim(value_str)
    
    cond do
      trimmed == "NULL" -> nil
      String.starts_with?(trimmed, "'") and String.ends_with?(trimmed, "'") ->
        String.slice(trimmed, 1..-2//-1)  # Remove quotes
      String.match?(trimmed, ~r/^\d+$/) ->
        String.to_integer(trimmed)
      String.match?(trimmed, ~r/^\d+\.\d+$/) ->
        String.to_float(trimmed)
      true ->
        trimmed
    end
  end
  
  defp csv_row_to_record(csv_row) do
    # Convert CSV row map to database record
    # This would be customized based on the specific table schema
    csv_row
  end
  
  defp add_timestamps(record) do
    now = DateTime.utc_now()
    
    record
    |> Map.put_new(:inserted_at, now)
    |> Map.put_new(:updated_at, now)
  end
  
  defp add_uuid_id(record) do
    Map.put_new(record, :id, Ecto.UUID.generate())
  end
  
  defp calculate_progress(importer) do
    if importer.total_records > 0 do
      processed_percentage = (importer.processed_records / importer.total_records) * 100
      
      elapsed_time = DateTime.diff(DateTime.utc_now(), importer.start_time, :second)
      records_per_second = if elapsed_time > 0, do: importer.processed_records / elapsed_time, else: 0
      
      estimated_remaining = 
        if records_per_second > 0 do
          remaining_records = importer.total_records - importer.processed_records
          remaining_records / records_per_second
        else
          0
        end
      
      %{
        table: importer.table_name,
        processed: importer.processed_records,
        total: importer.total_records,
        failed: importer.failed_records,
        percentage: Float.round(processed_percentage, 2),
        elapsed_seconds: elapsed_time,
        records_per_second: Float.round(records_per_second, 2),
        estimated_remaining_seconds: Float.round(estimated_remaining, 0)
      }
    else
      %{
        table: importer.table_name,
        processed: 0,
        total: 0,
        failed: 0,
        percentage: 0.0,
        elapsed_seconds: 0,
        records_per_second: 0.0,
        estimated_remaining_seconds: 0
      }
    end
  end
  
  defp finalize_import(importer) do
    end_time = DateTime.utc_now()
    total_time = DateTime.diff(end_time, importer.start_time, :second)
    
    Logger.info("🎯 Import completed for #{importer.table_name}")
    Logger.info("📊 Final statistics:")
    Logger.info("   ✅ Successfully processed: #{importer.processed_records}")
    Logger.info("   ❌ Failed records: #{importer.failed_records}")
    Logger.info("   ⏱️  Total time: #{total_time} seconds")
    
    if importer.processed_records > 0 do
      records_per_second = importer.processed_records / total_time
      Logger.info("   🚀 Average speed: #{Float.round(records_per_second, 2)} records/second")
    end
    
    success_rate = if importer.total_records > 0 do
      (importer.processed_records / importer.total_records) * 100
    else
      0.0
    end
    
    Logger.info("   📈 Success rate: #{Float.round(success_rate, 2)}%")
    
    {:ok, %{
      table: importer.table_name,
      processed: importer.processed_records,
      failed: importer.failed_records,
      total_time_seconds: total_time,
      success_rate: success_rate
    }}
  end
  
  # Utility functions
  
  defp count_csv_lines(file_path) do
    File.stream!(file_path)
    |> Enum.count()
    |> Kernel.-(1)  # Subtract header line
  end
  
  defp count_file_lines(file_path) do
    File.stream!(file_path)
    |> Enum.count()
  end
  
  # Predefined transformer functions for common EQEmu tables
  
  def character_transformer(record) do
    %{
      eqemu_id: record["id"],
      account_id: record["account_id"],
      name: record["name"],
      race: record["race"],
      class: record["class"],
      level: record["level"] || 1,
      zone_id: record["zone_id"] || 1,
      x: record["x"] || 0.0,
      y: record["y"] || 0.0,
      z: record["z"] || 0.0,
      heading: record["heading"] || 0.0,
      hp: record["hp"] || 100,
      mana: record["mana"] || 0,
      endurance: record["endurance"] || 100
    }
  end
  
  def item_transformer(record) do
    %{
      eqemu_id: record["id"],
      name: record["name"],
      damage: record["damage"] || 0,
      delay: record["delay"] || 0,
      ac: record["ac"] || 0,
      hp: record["hp"] || 0,
      mana: record["mana"] || 0,
      weight: record["weight"] || 0,
      price: record["price"] || 0,
      itemtype: record["itemtype"] || 0
    }
  end
  
  def account_transformer(record) do
    %{
      eqemu_id: record["id"],
      name: record["name"],
      status: record["status"] || 0,
      expansion: record["expansion"] || 8,
      # Note: user_id would need to be mapped separately
      user_id: nil
    }
  end
  
  # Predefined validator functions
  
  def character_validator(record) do
    record[:name] != nil and 
    String.length(record[:name]) >= 3 and
    String.length(record[:name]) <= 64 and
    record[:race] != nil and
    record[:class] != nil
  end
  
  def item_validator(record) do
    record[:name] != nil and
    String.length(record[:name]) > 0
  end
  
  def account_validator(record) do
    record[:name] != nil and
    String.length(record[:name]) >= 3 and
    String.length(record[:name]) <= 30
  end
end