#!/usr/bin/env elixir

# Migration script to move uploaded files from old structure to new structure
# Old: /app/uploads/{user_id}/{year}/{month}/{context}/{filename}
# New: /app/uploads/{user_id}/{context}/{filename}

defmodule UploadMigration do
  require Logger

  @base_dir "/app/uploads"

  def run do
    Logger.info("Starting upload path migration...")
    
    case File.ls(@base_dir) do
      {:ok, entries} ->
        # Filter out non-user directories (like "public")
        user_dirs = Enum.filter(entries, fn entry ->
          path = Path.join(@base_dir, entry)
          File.dir?(path) && entry != "public" && String.match?(entry, ~r/^[a-f0-9-]+$/)
        end)
        
        Logger.info("Found #{length(user_dirs)} user directories to process")
        
        Enum.each(user_dirs, &process_user_dir/1)
        
        Logger.info("Migration complete!")
        
      {:error, reason} ->
        Logger.error("Failed to list base directory: #{inspect(reason)}")
    end
  end

  defp process_user_dir(user_id) do
    user_path = Path.join(@base_dir, user_id)
    Logger.info("Processing user directory: #{user_id}")
    
    case File.ls(user_path) do
      {:ok, entries} ->
        # Look for year directories (4-digit numbers)
        year_dirs = Enum.filter(entries, fn entry ->
          File.dir?(Path.join(user_path, entry)) && String.match?(entry, ~r/^\d{4}$/)
        end)
        
        if length(year_dirs) > 0 do
          Logger.info("  Found #{length(year_dirs)} year directories")
          Enum.each(year_dirs, fn year ->
            process_year_dir(user_id, year)
          end)
        end
        
      {:error, reason} ->
        Logger.error("  Failed to list user directory: #{inspect(reason)}")
    end
  end

  defp process_year_dir(user_id, year) do
    year_path = Path.join([@base_dir, user_id, year])
    
    case File.ls(year_path) do
      {:ok, entries} ->
        # Look for month directories (2-digit numbers)
        month_dirs = Enum.filter(entries, fn entry ->
          File.dir?(Path.join(year_path, entry)) && String.match?(entry, ~r/^\d{2}$/)
        end)
        
        Enum.each(month_dirs, fn month ->
          process_month_dir(user_id, year, month)
        end)
        
      {:error, reason} ->
        Logger.error("  Failed to list year directory #{year}: #{inspect(reason)}")
    end
  end

  defp process_month_dir(user_id, year, month) do
    month_path = Path.join([@base_dir, user_id, year, month])
    
    case File.ls(month_path) do
      {:ok, entries} ->
        # These should be context directories (or files if no context was used)
        Enum.each(entries, fn entry ->
          old_path = Path.join(month_path, entry)
          
          if File.dir?(old_path) do
            # It's a context directory
            process_context_dir(user_id, year, month, entry)
          else
            # It's a file without context
            move_file(user_id, old_path, entry, nil)
          end
        end)
        
        # After processing, remove empty year/month directories
        cleanup_empty_dirs(user_id, year, month)
        
      {:error, reason} ->
        Logger.error("  Failed to list month directory #{year}/#{month}: #{inspect(reason)}")
    end
  end

  defp process_context_dir(user_id, year, month, context) do
    context_path = Path.join([@base_dir, user_id, year, month, context])
    
    case File.ls(context_path) do
      {:ok, files} ->
        Logger.info("    Moving #{length(files)} files from #{year}/#{month}/#{context}")
        
        Enum.each(files, fn filename ->
          old_file_path = Path.join(context_path, filename)
          move_file(user_id, old_file_path, filename, context)
        end)
        
      {:error, reason} ->
        Logger.error("  Failed to list context directory #{context}: #{inspect(reason)}")
    end
  end

  defp move_file(user_id, old_path, filename, context) do
    # Build new path
    new_dir = if context do
      Path.join([@base_dir, user_id, context])
    else
      Path.join([@base_dir, user_id])
    end
    
    new_path = Path.join(new_dir, filename)
    
    # Create new directory if needed
    case File.mkdir_p(new_dir) do
      :ok ->
        # Check if destination already exists (avoid duplicates)
        if File.exists?(new_path) do
          Logger.warn("      Skipping #{filename} - already exists at destination")
        else
          # Move the file
          case File.rename(old_path, new_path) do
            :ok ->
              Logger.info("      Moved: #{filename}")
              
            {:error, :exdev} ->
              # Cross-device link error - copy and delete instead
              case File.cp(old_path, new_path) do
                :ok ->
                  File.rm(old_path)
                  Logger.info("      Copied and removed: #{filename}")
                  
                {:error, reason} ->
                  Logger.error("      Failed to copy #{filename}: #{inspect(reason)}")
              end
              
            {:error, reason} ->
              Logger.error("      Failed to move #{filename}: #{inspect(reason)}")
          end
        end
        
      {:error, reason} ->
        Logger.error("      Failed to create directory #{new_dir}: #{inspect(reason)}")
    end
  end

  defp cleanup_empty_dirs(user_id, year, month) do
    month_path = Path.join([@base_dir, user_id, year, month])
    year_path = Path.join([@base_dir, user_id, year])
    
    # Remove month directory if empty
    case File.ls(month_path) do
      {:ok, []} ->
        File.rmdir(month_path)
        Logger.info("    Removed empty directory: #{year}/#{month}")
        
      _ -> :ok
    end
    
    # Remove year directory if empty
    case File.ls(year_path) do
      {:ok, []} ->
        File.rmdir(year_path)
        Logger.info("    Removed empty directory: #{year}")
        
      _ -> :ok
    end
  end
end

# Run the migration
UploadMigration.run()
