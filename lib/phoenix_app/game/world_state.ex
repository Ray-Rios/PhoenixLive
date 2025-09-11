defmodule PhoenixApp.Game.WorldState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "world_state" do
    field :world_id, :string
    field :object_id, :string
    field :object_type, :string
    field :position, :map
    field :rotation, :map, default: %{"x" => 0, "y" => 0, "z" => 0}
    field :scale, :map, default: %{"x" => 1, "y" => 1, "z" => 1}
    field :properties, :map, default: %{}
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(world_state, attrs) do
    world_state
    |> cast(attrs, [:world_id, :object_id, :object_type, :position, :rotation,
                    :scale, :properties, :is_active])
    |> validate_required([:world_id, :object_id, :object_type, :position])
    |> unique_constraint([:world_id, :object_id])
  end
end