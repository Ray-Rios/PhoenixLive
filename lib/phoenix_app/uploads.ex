defmodule PhoenixApp.Uploads do
  @moduledoc """
  Centralized upload handling for all file uploads in the application.
  
  Provides consistent path generation, URL generation, and file operations
  for user uploads across different contexts (blog, forum, avatars, etc.).
  
  ## File Structure
  
  All uploads are stored under `priv/static/uploads/` with the following structure:
  - User-specific: `uploads/{user_id}/{yyyy}/{mm}/{context}/{filename}`
  - Public: `uploads/public/{context}/{filename}`
  
  ## Examples
  
      # Upload a blog featured image
      {:ok, url} = Uploads.upload_file(user, temp_path, entry, context: "blog")
      
      # Upload a forum attachment
      {:ok, url} = Uploads.upload_file(user, temp_path, entry, context: "forum")
      
      # Upload an avatar
      {:ok, url} = Uploads.upload_file(user, temp_path, entry, context: "avatar")
      
      # Upload to public directory
      {:ok, url} = Uploads.upload_file(nil, temp_path, entry, context: "public/images", public: true)
  """
  
  require Logger

  @doc """
  Get the base upload directory path (filesystem path).
  Returns absolute path like "/app/uploads" in production (mounted PVC)
  or relative path in development.
  """
  def base_dir do
    # Always use /app/uploads which is where the PVC is mounted in production
    # In development, this path won't exist and will fall back to creating it locally
    "/app/uploads"
  end

  @doc """
  Get the public uploads directory path (filesystem path).
  Returns: "priv/static/uploads/public"
  """
  def public_dir do
    Path.join([base_dir(), "public"])
  end

  @doc """
  Build upload directory path for a user with yyyy/mm structure.
  
  ## Options
  - `:context` - Upload context (e.g., "avatar", "blog", "forum")
  - `:public` - If true, uses public directory instead of user directory
  
  ## Examples
      iex> PhoenixApp.Uploads.user_dir(123, context: "blog")
      "priv/static/uploads/123/2025/11/blog"
      
      iex> PhoenixApp.Uploads.user_dir(nil, public: true, context: "images")
      "priv/static/uploads/public/images"
  """
  def user_dir(user_id, opts \\ []) do
    context = Keyword.get(opts, :context)
    public = Keyword.get(opts, :public, false)
    
    if public do
      case context do
        nil -> public_dir()
        ctx -> Path.join([public_dir(), ctx])
      end
    else
      now = DateTime.utc_now()
      year = now.year |> to_string()
      month = now.month |> to_string() |> String.pad_leading(2, "0")
      
      parts = [base_dir(), to_string(user_id), year, month]
      parts = if context, do: parts ++ [context], else: parts
      
      Path.join(parts)
    end
  end

  @doc """
  Build URL path for serving uploaded files.
  
  ## Examples
      iex> PhoenixApp.Uploads.url_path(123, "2025", "11", "blog", "image.png")
      "/uploads/123/2025/11/blog/image.png"
      
      iex> PhoenixApp.Uploads.url_path(nil, nil, nil, "images", "logo.png", public: true)
      "/uploads/public/images/logo.png"
  """
  def url_path(user_id, year, month, context, filename, opts \\ []) do
    public = Keyword.get(opts, :public, false)
    
    if public do
      case context do
        nil -> "/uploads/public/#{filename}"
        ctx -> "/uploads/public/#{ctx}/#{filename}"
      end
    else
      parts = ["/uploads", to_string(user_id), year, month]
      parts = if context, do: parts ++ [context], else: parts
      parts = parts ++ [filename]
      
      Path.join(parts)
    end
  end

  @doc """
  Get current year and month for path building.
  Returns: {year_string, month_string}
  
  ## Example
      iex> PhoenixApp.Uploads.current_date_parts()
      {"2025", "11"}
  """
  def current_date_parts do
    now = DateTime.utc_now()
    year = now.year |> to_string()
    month = now.month |> to_string() |> String.pad_leading(2, "0")
    {year, month}
  end

  @doc """
  Ensure upload directory exists, creating it if necessary.
  Returns :ok or {:error, reason}
  """
  def ensure_dir(path) do
    File.mkdir_p(path)
  end

  @doc """
  Generate a unique filename with the given extension.
  
  ## Example
      iex> PhoenixApp.Uploads.unique_filename(".jpg")
      "a1b2c3d4e5f6g7h8.jpg"
  """
  def unique_filename(extension) do
    random = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    "#{random}#{extension}"
  end

  @doc """
  Uploads a file from a LiveView upload entry.
  
  This is the main high-level function that combines path generation,
  directory creation, and file copying into a single operation.
  
  ## Parameters
  - `user` - The user uploading the file (or nil for public uploads)
  - `temp_path` - Temporary file path from LiveView upload (e.g., entry.path)
  - `entry` - The upload entry struct with client metadata
  - `opts` - Options:
    - `:context` - Upload context (e.g., "blog", "forum", "avatar")
    - `:public` - If true, upload to public directory
    - `:filename` - Optional custom filename (defaults to random hash + extension)
  
  ## Returns
  - `{:ok, url}` - Success with the public URL path
  - `{:error, reason}` - Failure with error reason
  
  ## Examples
      # User upload
      {:ok, url} = upload_file(user, temp_path, entry, context: "blog")
      
      # Public upload
      {:ok, url} = upload_file(nil, temp_path, entry, context: "images", public: true)
  """
  def upload_file(user, temp_path, entry, opts \\ []) do
    context = Keyword.get(opts, :context, "general")
    public = Keyword.get(opts, :public, false)
    custom_filename = Keyword.get(opts, :filename)
    
    # Generate filename
    filename = custom_filename || unique_filename(Path.extname(entry.client_name))
    
    # Generate paths
    {dest_dir, url} = if public do
      dir = user_dir(nil, public: true, context: context)
      url_path = url_path(nil, nil, nil, context, filename, public: true)
      {dir, url_path}
    else
      {year, month} = current_date_parts()
      dir = user_dir(user.id, context: context)
      url_path = url_path(user.id, year, month, context, filename)
      {dir, url_path}
    end
    
    # Log for debugging
    Logger.info("Uploading file: #{entry.client_name} (#{entry.client_size} bytes) to #{dest_dir}")
    
    # Create directory
    case ensure_dir(dest_dir) do
      :ok ->
        # Copy file
        dest_file = Path.join(dest_dir, filename)
        case File.cp(temp_path, dest_file) do
          :ok ->
            Logger.info("File uploaded successfully: #{url}")
            {:ok, url}
          
          {:error, reason} ->
            Logger.error("File copy failed: #{inspect(reason)}")
            {:error, "file_copy_failed: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        Logger.error("Directory creation failed: #{inspect(reason)}")
        {:error, "mkdir_failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets the MIME type category from a MIME type string.
  
  Returns one of: "image", "video", "audio", "document", "archive", or "other"
  """
  def get_file_type(mime_type) when is_binary(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      String.contains?(mime_type, "pdf") -> "document"
      String.contains?(mime_type, "document") -> "document"
      String.contains?(mime_type, "text") -> "document"
      String.contains?(mime_type, "zip") -> "archive"
      String.contains?(mime_type, "compressed") -> "archive"
      true -> "other"
    end
  end

  def get_file_type(_), do: "other"

  @doc """
  Formats file size in bytes to human-readable format.
  """
  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    cond do
      bytes >= 1_099_511_627_776 -> "#{Float.round(bytes / 1_099_511_627_776, 2)} TB"
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  def format_bytes(_), do: "0 B"

  @doc """
  Deletes an uploaded file given its URL path.
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def delete_file(url_path) when is_binary(url_path) do
    # Convert URL path to filesystem path
    file_path = url_path
                |> String.replace_prefix("/uploads/", "")
                |> then(&Path.join([base_dir(), &1]))
    
    case File.rm(file_path) do
      :ok ->
        Logger.info("Deleted file: #{url_path}")
        :ok
      
      {:error, reason} ->
        Logger.error("Failed to delete file #{url_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete_file(_), do: {:error, :invalid_path}

  @doc """
  Checks if a file exists at the given URL path.
  """
  def file_exists?(url_path) when is_binary(url_path) do
    file_path = url_path
                |> String.replace_prefix("/uploads/", "")
                |> then(&Path.join([base_dir(), &1]))
    
    File.exists?(file_path)
  end

  def file_exists?(_), do: false

  @doc """
  Gets the absolute filesystem path from a URL path.
  """
  def url_to_path(url_path) when is_binary(url_path) do
    url_path
    |> String.replace_prefix("/uploads/", "")
    |> then(&Path.join([base_dir(), &1]))
  end

  def url_to_path(_), do: nil
end
