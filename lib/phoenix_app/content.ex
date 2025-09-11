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
    from(p in Post, where: p.status == :published, order_by: [desc: p.inserted_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_recent_posts(limit \\ 5) do
    from(p in Post, 
      where: p.status == :published, 
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

  # CMS-style functions
  def list_posts_by_status(status) do
    from(p in Post, where: p.status == ^status, order_by: [desc: p.inserted_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def list_posts_by_type(post_type) do
    from(p in Post, where: p.post_type == ^post_type, order_by: [desc: p.inserted_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def list_posts_with_filters(opts \\ []) do
    query = from(p in Post, order_by: [desc: p.inserted_at])
    
    query
    |> maybe_filter_by_status(opts[:status])
    |> maybe_filter_by_type(opts[:post_type])
    |> maybe_filter_by_user(opts[:user_id])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status) do
    from(p in query, where: p.status == ^status)
  end

  defp maybe_filter_by_type(query, nil), do: query
  defp maybe_filter_by_type(query, post_type) do
    from(p in query, where: p.post_type == ^post_type)
  end

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id) do
    from(p in query, where: p.user_id == ^user_id)
  end

  # Comments
  alias PhoenixApp.Content.Comment

  def list_comments(post_id \\ nil) do
    query = from(c in Comment, order_by: [desc: c.inserted_at])
    
    query = if post_id, do: from(c in query, where: c.post_id == ^post_id), else: query
    
    query
    |> Repo.all()
    |> Repo.preload([:user, :post])
  end

  def list_approved_comments(post_id) do
    from(c in Comment, 
      where: c.post_id == ^post_id and c.status == :approved,
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_comment!(id) do
    Repo.get!(Comment, id) |> Repo.preload([:user, :post])
  end

  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
  end

  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  def approve_comment(%Comment{} = comment) do
    update_comment(comment, %{status: :approved})
  end

  def spam_comment(%Comment{} = comment) do
    update_comment(comment, %{status: :spam})
  end

  # Admin functions
  def count_posts do
    Repo.aggregate(Post, :count)
  end

  def count_posts_by_status(status) do
    from(p in Post, where: p.status == ^status)
    |> Repo.aggregate(:count)
  end

  def count_comments do
    Repo.aggregate(Comment, :count)
  end

  def count_comments_by_status(status) do
    from(c in Comment, where: c.status == ^status)
    |> Repo.aggregate(:count)
  end
end