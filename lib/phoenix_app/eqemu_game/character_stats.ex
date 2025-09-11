defmodule PhoenixApp.EqemuGame.CharacterStats do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "character_stats" do
    field :str, :integer, default: 75
    field :sta, :integer, default: 75
    field :cha, :integer, default: 75
    field :dex, :integer, default: 75
    field :int, :integer, default: 75
    field :agi, :integer, default: 75
    field :wis, :integer, default: 75
    field :atk, :integer, default: 100
    field :ac, :integer, default: 0
    field :hp_regen_rate, :integer, default: 1
    field :mana_regen_rate, :integer, default: 1
    field :endurance_regen_rate, :integer, default: 1
    field :attack_speed, :float, default: 0.0
    field :accuracy, :integer, default: 0
    field :avoidance, :integer, default: 0
    field :combat_effects, :integer, default: 0
    field :shielding, :integer, default: 0
    field :spell_shielding, :integer, default: 0
    field :dot_shielding, :integer, default: 0
    field :damage_shield, :integer, default: 0
    field :damage_shield_mitigation, :integer, default: 0
    field :heroic_str, :integer, default: 0
    field :heroic_int, :integer, default: 0
    field :heroic_wis, :integer, default: 0
    field :heroic_agi, :integer, default: 0
    field :heroic_dex, :integer, default: 0
    field :heroic_sta, :integer, default: 0
    field :heroic_cha, :integer, default: 0
    field :mr, :integer, default: 0
    field :fr, :integer, default: 0
    field :cr, :integer, default: 0
    field :pr, :integer, default: 0
    field :dr, :integer, default: 0
    field :corrup, :integer, default: 0

    belongs_to :character, PhoenixApp.EqemuGame.Character

    timestamps()
  end

  @doc false
  def changeset(character_stats, attrs) do
    character_stats
    |> cast(attrs, [
      :character_id, :str, :sta, :cha, :dex, :int, :agi, :wis, :atk, :ac,
      :hp_regen_rate, :mana_regen_rate, :endurance_regen_rate, :attack_speed,
      :accuracy, :avoidance, :combat_effects, :shielding, :spell_shielding,
      :dot_shielding, :damage_shield, :damage_shield_mitigation, :heroic_str,
      :heroic_int, :heroic_wis, :heroic_agi, :heroic_dex, :heroic_sta,
      :heroic_cha, :mr, :fr, :cr, :pr, :dr, :corrup
    ])
    |> validate_required([:character_id])
    |> validate_number(:str, greater_than_or_equal_to: 0)
    |> validate_number(:sta, greater_than_or_equal_to: 0)
    |> validate_number(:cha, greater_than_or_equal_to: 0)
    |> validate_number(:dex, greater_than_or_equal_to: 0)
    |> validate_number(:int, greater_than_or_equal_to: 0)
    |> validate_number(:agi, greater_than_or_equal_to: 0)
    |> validate_number(:wis, greater_than_or_equal_to: 0)
    |> unique_constraint(:character_id)
  end

  def total_stats(%__MODULE__{} = stats) do
    stats.str + stats.sta + stats.cha + stats.dex + stats.int + stats.agi + stats.wis
  end

  def effective_str(%__MODULE__{str: str, heroic_str: heroic_str}) do
    str + heroic_str
  end

  def effective_sta(%__MODULE__{sta: sta, heroic_sta: heroic_sta}) do
    sta + heroic_sta
  end

  def effective_cha(%__MODULE__{cha: cha, heroic_cha: heroic_cha}) do
    cha + heroic_cha
  end

  def effective_dex(%__MODULE__{dex: dex, heroic_dex: heroic_dex}) do
    dex + heroic_dex
  end

  def effective_int(%__MODULE__{int: int, heroic_int: heroic_int}) do
    int + heroic_int
  end

  def effective_agi(%__MODULE__{agi: agi, heroic_agi: heroic_agi}) do
    agi + heroic_agi
  end

  def effective_wis(%__MODULE__{wis: wis, heroic_wis: heroic_wis}) do
    wis + heroic_wis
  end

  def total_resistances(%__MODULE__{} = stats) do
    stats.mr + stats.fr + stats.cr + stats.pr + stats.dr + stats.corrup
  end
end