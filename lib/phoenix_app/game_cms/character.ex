defmodule PhoenixApp.GameCMS.Character do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_characters" do
    field :name, :string
    field :class, :string
    field :level, :integer, default: 1
    field :experience, :integer, default: 0
    field :health, :integer, default: 100
    field :max_health, :integer, default: 100
    field :mana, :integer, default: 50
    field :max_mana, :integer, default: 50
    field :gold, :integer, default: 0
    field :current_zone, :string, default: "Starting Area"
    field :last_active, :utc_datetime
    
    # Stats
    field :strength, :integer, default: 10
    field :agility, :integer, default: 10
    field :intelligence, :integer, default: 10
    field :vitality, :integer, default: 10
    
    # Calculated stats
    field :attack_power, :integer, default: 10
    field :defense, :integer, default: 5
    field :crit_chance, :float, default: 5.0
    field :attack_speed, :float, default: 1.0

    belongs_to :user, PhoenixApp.Accounts.User
    belongs_to :guild, PhoenixApp.GameCMS.Guild, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :name, :class, :level, :experience, :health, :max_health, 
      :mana, :max_mana, :gold, :current_zone, :last_active,
      :strength, :agility, :intelligence, :vitality,
      :attack_power, :defense, :crit_chance, :attack_speed,
      :user_id, :guild_id
    ])
    |> validate_required([:name, :class, :user_id])
    |> validate_length(:name, min: 2, max: 50)
    |> validate_inclusion(:class, ["Warrior", "Mage", "Rogue", "Priest", "Archer"])
    |> validate_number(:level, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:experience, greater_than_or_equal_to: 0)
    |> validate_number(:health, greater_than_or_equal_to: 0)
    |> validate_number(:mana, greater_than_or_equal_to: 0)
    |> validate_number(:gold, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:guild_id)
  end
end