defmodule PhoenixApp.Content.Page do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pages" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :template_type, :string, default: "default"
    field :is_published, :boolean, default: false
    field :meta_description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :slug, :content, :template_type, :is_published, :meta_description])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:meta_description, max: 160)
    |> maybe_generate_slug()
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
          put_change(changeset, :slug, slug)
        else
          changeset
        end
      _ -> changeset
    end
  end
end