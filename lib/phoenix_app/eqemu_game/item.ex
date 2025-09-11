defmodule PhoenixApp.EqemuGame.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "eqemu_items" do
    # Core fields that match the migration
    field :eqemu_id, :integer
    field :name, :string
    field :lore, :string
    field :idfile, :string
    field :nodrop, :integer, default: 0
    field :norent, :integer, default: 0
    field :itemtype, :integer, default: 0  # Note: migration uses 'itemtype' not 'item_type'
    field :icon, :integer, default: 0
    field :price, :integer, default: 0
    field :bagtype, :integer, default: 0
    field :bagslots, :integer, default: 0
    field :bagsize, :integer, default: 0
    field :bagwr, :integer, default: 0
    field :book, :integer, default: 0
    field :filename, :string
    field :banedmgrace, :integer, default: 0
    field :banedmgbody, :integer, default: 0
    field :banedmgamt, :integer, default: 0
    field :magic, :integer, default: 0
    field :casttime_, :integer, default: 0
    field :bardtype, :integer, default: 0
    field :bardvalue, :integer, default: 0
    field :light, :integer, default: 0
    field :delay, :integer, default: 0
    field :elemdmgtype, :integer, default: 0
    field :elemdmgamt, :integer, default: 0
    field :damage, :integer, default: 0
    field :color, :integer, default: 0
    field :classes, :integer, default: 0
    field :races, :integer, default: 0
    field :deity, :integer, default: 0
    field :ac, :integer, default: 0
    field :accuracy, :integer, default: 0
    field :agi, :integer, default: 0  # Note: migration uses 'agi' not 'aagi'
    field :cha, :integer, default: 0
    field :dex, :integer, default: 0
    field :int, :integer, default: 0
    field :sta, :integer, default: 0
    field :str, :integer, default: 0
    field :wis, :integer, default: 0
    field :hp, :integer, default: 0
    field :mana, :integer, default: 0
    field :endur, :integer, default: 0
    field :cr, :integer, default: 0
    field :dr, :integer, default: 0
    field :fr, :integer, default: 0
    field :mr, :integer, default: 0
    field :pr, :integer, default: 0
    field :haste, :integer, default: 0
    field :damageshield, :integer, default: 0
    # Add weight and reqlevel for admin interface
    field :weight, :integer, default: 0
    field :reqlevel, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :eqemu_id, :name, :lore, :idfile, :nodrop, :norent, :itemtype, :icon, 
      :price, :bagtype, :bagslots, :bagsize, :bagwr, :book, :filename, 
      :banedmgrace, :banedmgbody, :banedmgamt, :magic, :casttime_, :bardtype, 
      :bardvalue, :light, :delay, :elemdmgtype, :elemdmgamt, :damage, :color, 
      :classes, :races, :deity, :ac, :accuracy, :agi, :cha, :dex, :int, :sta, 
      :str, :wis, :hp, :mana, :endur, :cr, :dr, :fr, :mr, :pr, :haste, :damageshield,
      :weight, :reqlevel
    ])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 64)
    |> unique_constraint(:eqemu_id)
  end

  def item_type_name(%__MODULE__{itemtype: itemtype}) do
    case itemtype do
      0 -> "1H Slashing"
      1 -> "2H Slashing"
      2 -> "1H Piercing"
      3 -> "1H Blunt"
      4 -> "2H Blunt"
      5 -> "Archery"
      8 -> "Shield"
      10 -> "Armor"
      11 -> "Misc"
      14 -> "Food"
      15 -> "Drink"
      16 -> "Light"
      17 -> "Combinable"
      18 -> "Bandage"
      19 -> "Throwing"
      20 -> "Spell"
      21 -> "Potion"
      22 -> "Wind Instrument"
      23 -> "Stringed Instrument"
      24 -> "Brass Instrument"
      25 -> "Percussion Instrument"
      26 -> "Arrow"
      27 -> "Jewelry"
      29 -> "Book"
      30 -> "Note"
      31 -> "Key"
      32 -> "Coin"
      33 -> "2H Piercing"
      34 -> "Fishing Pole"
      35 -> "Fishing Bait"
      36 -> "Alcohol"
      37 -> "Key (bis)"
      38 -> "Compass"
      39 -> "Poison"
      40 -> "Lockpick"
      42 -> "Hand to Hand"
      45 -> "Martial"
      _ -> "Unknown"
    end
  end

  def slot_name(slot_id) do
    case slot_id do
      0 -> "Charm"
      1 -> "Left Ear"
      2 -> "Head"
      3 -> "Face"
      4 -> "Right Ear"
      5 -> "Neck"
      6 -> "Shoulders"
      7 -> "Arms"
      8 -> "Back"
      9 -> "Left Wrist"
      10 -> "Right Wrist"
      11 -> "Range"
      12 -> "Hands"
      13 -> "Primary"
      14 -> "Secondary"
      15 -> "Left Ring"
      16 -> "Right Ring"
      17 -> "Chest"
      18 -> "Legs"
      19 -> "Feet"
      20 -> "Waist"
      21 -> "Powersource"
      22 -> "Ammo"
      _ when slot_id >= 23 and slot_id <= 30 -> "General #{slot_id - 22}"
      _ when slot_id >= 2000 and slot_id <= 2007 -> "Bank #{slot_id - 1999}"
      _ when slot_id >= 2500 and slot_id <= 2503 -> "Shared Bank #{slot_id - 2499}"
      _ -> "Unknown Slot"
    end
  end

  def is_weapon?(%__MODULE__{itemtype: itemtype}) do
    itemtype in [0, 1, 2, 3, 4, 5, 19, 33, 42, 45]
  end

  def is_armor?(%__MODULE__{itemtype: itemtype}) do
    itemtype in [8, 10]
  end

  def is_jewelry?(%__MODULE__{itemtype: itemtype}) do
    itemtype == 27
  end

  def is_container?(%__MODULE__{bagslots: bagslots}) do
    bagslots > 0
  end

  def is_magic?(%__MODULE__{magic: magic}) do
    magic == 1
  end

  def is_lore?(%__MODULE__{lore: lore}) do
    not is_nil(lore) and String.length(lore) > 0
  end

  def is_nodrop?(%__MODULE__{nodrop: nodrop}) do
    nodrop == 1
  end

  def is_norent?(%__MODULE__{norent: norent}) do
    norent == 1
  end

  def can_use_class?(%__MODULE__{classes: classes}, class_id) do
    import Bitwise
    (classes &&& (1 <<< (class_id - 1))) != 0
  end

  def can_use_race?(%__MODULE__{races: races}, race_id) do
    import Bitwise
    race_bit = case race_id do
      1 -> 0   # Human
      2 -> 1   # Barbarian
      3 -> 2   # cat
      4 -> 3   # Wood Elf
      5 -> 4   # High Elf
      6 -> 5   # Dark Elf
      7 -> 6   # Half Elf
      8 -> 7   # Dwarf
      9 -> 8   # Troll
      10 -> 9  # Ogre
      11 -> 10 # Halfling
      12 -> 11 # Gnome
      128 -> 12 # Iksar
      130 -> 13 # Vah Shir
      330 -> 14 # Froglok
      522 -> 15 # Drakkin
      _ -> -1
    end
    
    if race_bit >= 0 do
      (races &&& (1 <<< race_bit)) != 0
    else
      false
    end
  end

  def total_stats(%__MODULE__{} = item) do
    item.str + item.sta + item.cha + item.dex + item.int + item.agi + item.wis
  end

  def total_resistances(%__MODULE__{} = item) do
    item.mr + item.fr + item.cr + item.dr + item.pr
  end
end