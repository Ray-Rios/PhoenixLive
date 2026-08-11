defmodule PhoenixApp.Game.CharacterSpell do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "character_spells" do
    belongs_to :character, PhoenixApp.Game.Character
    belongs_to :spell,     PhoenixApp.Game.Spell
    field :unlocked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(cs, attrs) do
    cs
    |> cast(attrs, [:character_id, :spell_id, :unlocked_at])
    |> validate_required([:character_id, :spell_id, :unlocked_at])
    |> unique_constraint([:character_id, :spell_id])
    |> foreign_key_constraint(:character_id)
    |> foreign_key_constraint(:spell_id)
  end
end
