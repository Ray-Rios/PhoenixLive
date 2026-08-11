defmodule PhoenixApp.Game.Spell do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "spells" do
    field :slug,            :string
    field :name,            :string
    field :description,     :string
    field :mp_cost,         :integer, default: 0
    field :base_damage,     :integer, default: 0
    field :range,           :float,   default: 20.0
    field :recast_ms,       :integer, default: 1000
    field :projectile_type, :string,  default: "stone"
    field :targeting_type,  :string,  default: "single"

    timestamps(type: :utc_datetime)
  end

  def changeset(spell, attrs) do
    spell
    |> cast(attrs, [:slug, :name, :description, :mp_cost, :base_damage, :range, :recast_ms, :projectile_type, :targeting_type])
    |> validate_required([:slug, :name, :mp_cost, :base_damage])
    |> unique_constraint(:slug)
  end
end
