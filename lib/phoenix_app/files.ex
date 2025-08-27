defmodule PhoenixApp.Files do
  @moduledoc """
  The Files context for file management.
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
    %UserFile{}
    |> UserFile.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_user_file(%UserFile{} = file, attrs) do
    file
    |> UserFile.changeset(attrs)
    |> Repo.update()
  end

  def delete_user_file(%UserFile{} = file) do
    Repo.delete(file)
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
end