defmodule PhoenixApp.Content do
  @moduledoc """
  The Content context for blog posts and pages.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Content.{Post, Page}

  # Posts
  def list_posts do
    from(p in Post, order_by: [desc: p.inserted_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def list_published_posts do
    from(p in Post, where: p.is_published == true, order_by: [desc: p.inserted_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_recent_posts(limit \\ 5) do
    from(p in Post, 
      where: p.is_published == true, 
      order_by: [desc: p.inserted_at], 
      limit: ^limit
    )
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_post!(id) do
    Repo.get!(Post, id) |> Repo.preload(:user)
  end

  def get_post_by_slug!(slug) do
    Repo.get_by!(Post, slug: slug) |> Repo.preload(:user)
  end

  def create_post(user, attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  # Pages
  def list_pages do
    Repo.all(Page)
  end

  def get_page!(id), do: Repo.get!(Page, id)

  def create_page(attrs \\ %{}) do
    %Page{}
    |> Page.changeset(attrs)
    |> Repo.insert()
  end

  def update_page(%Page{} = page, attrs) do
    page
    |> Page.changeset(attrs)
    |> Repo.update()
  end

  def delete_page(%Page{} = page) do
    Repo.delete(page)
  end

  # Admin functions
  def count_posts do
    Repo.aggregate(Post, :count)
  end


end