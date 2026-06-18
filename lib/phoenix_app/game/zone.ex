defmodule PhoenixApp.Game.Zone do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "zones" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :spawn_x, :float, default: 0.0
    field :spawn_y, :float, default: 0.0
    field :spawn_z, :float, default: 0.0
    field :spawn_heading, :float, default: 0.0

    has_many :characters, PhoenixApp.Game.Character, foreign_key: :last_zone_id

    timestamps(type: :utc_datetime)
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :slug, :description, :spawn_x, :spawn_y, :spawn_z, :spawn_heading])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end