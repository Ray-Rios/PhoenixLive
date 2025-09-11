defmodule PhoenixApp.GameCMS.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_items" do
    field :name, :string
    field :description, :string
    field :item_type, :string
    field :rarity, :string, default: "common"
    field :level_requirement, :integer, default: 1
    field :price, :integer, default: 0
    field :icon, :string
    field :usable, :boolean, default: false
    field :stackable, :boolean, default: true
    field :max_stack, :integer, default: 99
    
    # Item stats (for equipment)
    field :attack_power, :integer, default: 0
    field :defense, :integer, default: 0
    field :health_bonus, :integer, default: 0
    field :mana_bonus, :integer, default: 0
    field :strength_bonus, :integer, default: 0
    field :agility_bonus, :integer, default: 0
    field :intelligence_bonus, :integer, default: 0
    field :vitality_bonus, :integer, default: 0
    
    # For consumables
    field :health_restore, :integer, default: 0
    field :mana_restore, :integer, default: 0
    field :buff_duration, :integer, default: 0
    field :buff_effect, :string

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :name, :description, :item_type, :rarity, :level_requirement, :price,
      :icon, :usable, :stackable, :max_stack,
      :attack_power, :defense, :health_bonus, :mana_bonus,
      :strength_bonus, :agility_bonus, :intelligence_bonus, :vitality_bonus,
      :health_restore, :mana_restore, :buff_duration, :buff_effect
    ])
    |> validate_required([:name, :item_type])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:item_type, [
      "weapon", "armor", "accessory", "consumable", "material", "quest", "misc"
    ])
    |> validate_inclusion(:rarity, [
      "common", "uncommon", "rare", "epic", "legendary", "artifact"
    ])
    |> validate_number(:level_requirement, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:max_stack, greater_than: 0, less_than_or_equal_to: 999)
  end
end