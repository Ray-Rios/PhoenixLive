defmodule PhoenixApp.Content.Post do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :is_published, :boolean, default: false
    field :published_at, :utc_datetime
    field :featured_image, PhoenixApp.PostImage.Type
    field :meta_description, :string
    field :tags, {:array, :string}, default: []

    belongs_to :user, PhoenixApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :slug, :content, :excerpt, :is_published, :published_at, :meta_description, :tags])
    |> cast_attachments(attrs, [:featured_image])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:excerpt, max: 500)
    |> validate_length(:meta_description, max: 160)
    |> maybe_generate_slug()
    |> maybe_set_published_at()
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        title = get_change(changeset, :title)
        if title do
          slug = title 
                 |> String.downcase() 
                 |> String.replace(~r/[^a-z0-9\s]/, "") 
                 |> String.replace(~r/\s+/, "-")
                 |> String.slice(0, 100)
          put_change(changeset, :slug, slug)
        else
          changeset
        end
      _ -> changeset
    end
  end

  defp maybe_set_published_at(changeset) do
    is_published = get_change(changeset, :is_published)
    current_published_at = get_field(changeset, :published_at)
    
    cond do
      is_published == true and is_nil(current_published_at) ->
        put_change(changeset, :published_at, DateTime.utc_now())
      is_published == false ->
        put_change(changeset, :published_at, nil)
      true ->
        changeset
    end
  end
end