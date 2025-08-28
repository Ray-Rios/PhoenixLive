defmodule PhoenixApp.Commerce.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categories" do
    field :name, :string
    field :description, :string
    field :slug, :string

    has_many :products, PhoenixApp.Commerce.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :slug])
    |> validate_required([:name])
    |> unique_constraint(:slug)
    |> maybe_generate_slug()
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name)
        if name do
          slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9\s]/, "") |> String.replace(~r/\s+/, "-")
          put_change(changeset, :slug, slug)
        else
          changeset
        end
      _ -> changeset
    end
  end
end