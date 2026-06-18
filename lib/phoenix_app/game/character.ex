defmodule PhoenixApp.Game.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "characters" do
    field :name, :string
    field :character_type, :string
    field :model_path, :string
    field :approved_at, :utc_datetime
    field :last_x, :float, default: 0.0
    field :last_y, :float, default: 0.0
    field :last_z, :float, default: 0.0
    field :last_heading, :float, default: 0.0

    belongs_to :user, PhoenixApp.Accounts.User
    belongs_to :last_zone, PhoenixApp.Game.Zone

    timestamps(type: :utc_datetime)
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :name,
      :character_type,
      :model_path,
      :approved_at,
      :last_x,
      :last_y,
      :last_z,
      :last_heading,
      :last_zone_id,
      :user_id
    ])
    |> validate_required([:name, :character_type, :model_path, :approved_at, :last_zone_id, :user_id])
    |> validate_length(:name, min: 2)
    |> validate_length(:character_type, min: 2)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:last_zone_id)
  end
end