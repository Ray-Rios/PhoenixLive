defmodule PhoenixApp.Files do
  @moduledoc """
  The Files context for comprehensive file management operations.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Files.UserFile

  # User file operations
  def list_user_files(user) do
    from(f in UserFile, where: f.user_id == ^user.id, order_by: [desc: f.inserted_at])
    |> Repo.all()
  end

  def get_user_file!(user, id) do
    from(f in UserFile, where: f.user_id == ^user.id and f.id == ^id)
    |> Repo.one!()
  end

  def create_user_file(user, attrs \\ %{}) do
    # Handle Base64 data from JavaScript
    attrs = prepare_file_attrs(attrs)
    
    # Ensure uploads directory exists
    ensure_uploads_directory(user)
    
    changeset = %UserFile{}
    |> UserFile.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    
    Repo.insert(changeset)
  end

  def update_user_file(%UserFile{} = user_file, attrs) do
    user_file
    |> UserFile.changeset(attrs)
    |> Repo.update()
  end

  def delete_user_file(%UserFile{} = user_file) do
    Repo.delete(user_file)
  end

  def change_user_file(%UserFile{} = user_file, attrs \\ %{}) do
    UserFile.changeset(user_file, attrs)
  end

  def get_file_stats(user) do
    query = from f in UserFile, where: f.user_id == ^user.id
    
    %{
      total_files: Repo.aggregate(query, :count),
      total_size: Repo.aggregate(query, :sum, :file_size) || 0,
      images: Repo.aggregate(from(f in query, where: like(f.content_type, "image/%")), :count),
      videos: Repo.aggregate(from(f in query, where: like(f.content_type, "video/%")), :count),
      audio: Repo.aggregate(from(f in query, where: like(f.content_type, "audio/%")), :count),
      documents: Repo.aggregate(from(f in query, where: f.content_type in ["application/pdf", "application/msword", "text/plain"]), :count)
    }
  end

  def search_files(user, query) do
    search_term = "%#{query}%"
    
    from(f in UserFile, 
      where: f.user_id == ^user.id and ilike(f.filename, ^search_term),
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  def count_files do
    Repo.aggregate(UserFile, :count)
  end

  # Admin functions - list all files across all users
  def list_all_user_files do
    from(f in UserFile, order_by: [desc: f.inserted_at], preload: [:user])
    |> Repo.all()
  end

  def get_user_file_by_id!(id) do
    Repo.get!(UserFile, id)
  end

  def delete_user_file_by_id(id) when is_binary(id) do
    case Repo.get(UserFile, id) do
      nil -> {:error, :not_found}
      file -> Repo.delete(file)
    end
  end

  def create_folder(_user, _folder_name) do
    # Folder creation not implemented yet - requires database migration
    # to add proper folder support or separate folders table
    {:error, "Folder creation not implemented yet"}
  end

  def get_user_data_usage(user_id) do
    # Get total size from UserFile uploads
    user_files_size = from(f in UserFile, where: f.user_id == ^user_id, select: sum(f.file_size)) |> Repo.one() || 0

    # Get total size from UserMedia uploads
    user_media_size = from(m in PhoenixApp.Content.UserMedia, where: m.user_id == ^user_id, select: sum(m.file_size)) |> Repo.one() || 0

    # Get count of files
    user_files_count = from(f in UserFile, where: f.user_id == ^user_id, select: count()) |> Repo.one() || 0
    user_media_count = from(m in PhoenixApp.Content.UserMedia, where: m.user_id == ^user_id, select: count()) |> Repo.one() || 0

    %{
      total_size_bytes: user_files_size + user_media_size,
      total_files: user_files_count + user_media_count,
      user_files_size: user_files_size,
      user_media_size: user_media_size,
      user_files_count: user_files_count,
      user_media_count: user_media_count
    }
  end

  def get_all_users_data_usage do
    # Get data usage for all users
    user_files_query = from(f in UserFile,
      select: %{user_id: f.user_id, size: sum(f.file_size), count: count()},
      group_by: f.user_id
    )

    user_media_query = from(m in PhoenixApp.Content.UserMedia,
      select: %{user_id: m.user_id, size: sum(m.file_size), count: count()},
      group_by: m.user_id
    )

    user_files_data = Repo.all(user_files_query) |> Enum.into(%{}, fn r -> {r.user_id, r} end)
    user_media_data = Repo.all(user_media_query) |> Enum.into(%{}, fn r -> {r.user_id, r} end)

    # Combine data for all users
    all_user_ids = Map.keys(user_files_data) ++ Map.keys(user_media_data) |> Enum.uniq()

    Enum.map(all_user_ids, fn user_id ->
      files_data = Map.get(user_files_data, user_id, %{size: 0, count: 0})
      media_data = Map.get(user_media_data, user_id, %{size: 0, count: 0})

      %{
        user_id: user_id,
        total_size_bytes: files_data.size + media_data.size,
        total_files: files_data.count + media_data.count,
        user_files_size: files_data.size,
        user_media_size: media_data.size,
        user_files_count: files_data.count,
        user_media_count: media_data.count
      }
    end)
    |> Enum.sort_by(& &1.total_size_bytes, :desc)
  end

  # Public/admin file operations
  def list_public_files(role \\ :user) when role in [:admin, :gm, :editor, :user] do
    query = case role do
      :user -> from(f in UserFile, where: f.is_public == true)
      _ -> from(f in UserFile) # Admin/GM/Editor can see all files
    end
    
    query |> order_by([desc: :inserted_at]) |> Repo.all()
  end

  def get_public_file!(id, role \\ :user) do
    query = case role do
      :user -> from(f in UserFile, where: f.id == ^id and f.is_public == true)
      _ -> from(f in UserFile, where: f.id == ^id) # Admin/GM/Editor can access all files
    end
    
    Repo.one!(query)
  end

  # File type helpers
  def is_image?(%UserFile{content_type: content_type}), do: String.starts_with?(content_type, "image/")
  def is_video?(%UserFile{content_type: content_type}), do: String.starts_with?(content_type, "video/")
  def is_audio?(%UserFile{content_type: content_type}), do: String.starts_with?(content_type, "audio/")
  def is_document?(%UserFile{content_type: content_type}) do
    content_type in ["application/pdf", "application/msword", "text/plain", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
  end

  def format_file_size(size_bytes) when is_integer(size_bytes) do
    cond do
      size_bytes >= 1_073_741_824 -> "#{Float.round(size_bytes / 1_073_741_824, 2)} GB"
      size_bytes >= 1_048_576 -> "#{Float.round(size_bytes / 1_048_576, 2)} MB"
      size_bytes >= 1024 -> "#{Float.round(size_bytes / 1024, 2)} KB"
      true -> "#{size_bytes} B"
    end
  end
  def format_file_size(_), do: "0 B"

  # Private helper functions
  defp prepare_file_attrs(%{"data" => "data:" <> data_url} = attrs) do
    # Parse Base64 data URL
    [metadata, base64_data] = String.split(data_url, ";base64,", parts: 2)
    content_type = String.replace(metadata, "data:", "")
    
    # Decode Base64 data
    {:ok, file_data} = Base.decode64(base64_data)
    
    # Create a temporary file for Arc to process
    filename = attrs["name"] || "upload"
    temp_path = System.tmp_dir!() |> Path.join("upload_#{System.unique_integer()}_#{filename}")
    File.write!(temp_path, file_data)
    
    # Create Plug.Upload-like struct that Arc can handle
    file_upload = %Plug.Upload{
      filename: filename,
      path: temp_path,
      content_type: content_type
    }
    
    # Schedule temp file cleanup
    Task.start(fn ->
      :timer.sleep(10000) # Wait 10 seconds for Arc to process
      if File.exists?(temp_path), do: File.rm!(temp_path)
    end)
    
    %{
      "file" => file_upload,
      "original_filename" => filename,
      "filename" => Path.basename(filename, Path.extname(filename)),
      "content_type" => content_type,
      "file_size" => byte_size(file_data)
    }
  end
  
  defp prepare_file_attrs(attrs) when is_map(attrs) do
    attrs
  end
  
  defp ensure_uploads_directory(user) do
    base_dir = "uploads"
    user_dir = Path.join([base_dir, "user_files", to_string(user.id)])
    
    File.mkdir_p!(base_dir)
    File.mkdir_p!(user_dir)
  end
end