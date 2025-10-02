defmodule PhoenixApp.FileManagement do
  @moduledoc """
  The FileManagement context for file management operations.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Files.UserFile

  def list_user_files(user) do
    from(f in UserFile, where: f.user_id == ^user.id, order_by: [desc: f.inserted_at])
    |> Repo.all()
  end

  def get_user_file!(user, id) do
    from(f in UserFile, where: f.user_id == ^user.id and f.id == ^id)
    |> Repo.one!()
  end

  def create_user_file(user, attrs \\ %{}) do
    IO.puts("Creating user file with attrs:")
    IO.inspect(attrs, label: "Original attrs")
    
    # Handle Base64 data from JavaScript
    attrs = prepare_file_attrs(attrs)
    
    IO.inspect(attrs, label: "Processed attrs")
    
    # Ensure uploads directory exists
    ensure_uploads_directory(user)
    
    changeset = %UserFile{}
    |> UserFile.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    
    IO.inspect(changeset, label: "Changeset before insert")
    
    result = Repo.insert(changeset)
    IO.inspect(result, label: "Insert result")
    
    result
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

  def create_folder(_user, _folder_name) do
    # Folder creation not implemented yet - requires database migration
    # to add proper folder support or separate folders table
    {:error, "Folder creation not implemented yet"}
  end

  defp prepare_file_attrs(%{"data" => "data:" <> data_url} = attrs) do
    IO.puts("Preparing file attrs with Base64 data")
    
    # Parse Base64 data URL
    [metadata, base64_data] = String.split(data_url, ";base64,", parts: 2)
    content_type = String.replace(metadata, "data:", "")
    
    # Decode Base64 data
    {:ok, file_data} = Base.decode64(base64_data)
    
    # Create a temporary file for Arc to process
    filename = attrs["name"] || "upload"
    temp_path = System.tmp_dir!() |> Path.join("upload_#{System.unique_integer()}_#{filename}")
    File.write!(temp_path, file_data)
    
    IO.puts("Created temp file at: #{temp_path}")
    IO.puts("File size: #{byte_size(file_data)} bytes")
    
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
    IO.puts("Fallback prepare_file_attrs called")
    IO.inspect(attrs, label: "Fallback attrs")
    attrs
  end
  
  defp ensure_uploads_directory(user) do
    base_dir = "uploads"
    user_dir = Path.join([base_dir, "user_files", to_string(user.id)])
    
    File.mkdir_p!(base_dir)
    File.mkdir_p!(user_dir)
  end
end