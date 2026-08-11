defmodule PhoenixApp.Repo.Migrations.GameCombatAndSpells do
  use Ecto.Migration

  def up do
    # ── Characters: HP / MP / PvP flag ────────────────────────────────────────
    alter table(:characters) do
      add_if_not_exists :hp,          :integer, null: false, default: 10
      add_if_not_exists :max_hp,      :integer, null: false, default: 10
      add_if_not_exists :mp,          :integer, null: false, default: 10
      add_if_not_exists :max_mp,      :integer, null: false, default: 10
      add_if_not_exists :pvp_flagged, :boolean, null: false, default: false
    end

    # ── Spells ─────────────────────────────────────────────────────────────────
    create_if_not_exists table(:spells, primary_key: false) do
      add :id,               :binary_id, primary_key: true
      add :slug,             :string,    null: false   # unique machine key
      add :name,             :string,    null: false
      add :description,      :text
      add :mp_cost,          :integer,   null: false, default: 0
      add :base_damage,      :integer,   null: false, default: 0
      add :range,            :float,     null: false, default: 20.0
      add :recast_ms,        :integer,   null: false, default: 1000
      add :projectile_type,  :string,    null: false, default: "stone"
      add :targeting_type,   :string,    null: false, default: "single"
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:spells, [:slug])

    execute(
      """
      INSERT INTO spells (id, slug, name, description, mp_cost, base_damage, range, recast_ms, projectile_type, targeting_type, inserted_at, updated_at)
      VALUES (
        gen_random_uuid(),
        'throw_stone',
        'Throw Stone',
        'Hurl a stone at your target. Deals 1 damage if it hits.',
        1, 1, 20.0, 500, 'stone', 'single',
        NOW(), NOW()
      )
      ON CONFLICT (slug) DO NOTHING
      """,
      "DELETE FROM spells WHERE slug = 'throw_stone'"
    )

    # ── Character Spells (learned spells per character) ────────────────────────
    create_if_not_exists table(:character_spells, primary_key: false) do
      add :id,           :binary_id, primary_key: true
      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      add :spell_id,     references(:spells,     type: :binary_id, on_delete: :delete_all), null: false
      add :unlocked_at,  :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:character_spells, [:character_id, :spell_id])
    create_if_not_exists index(:character_spells, [:character_id])

    # ── Items ──────────────────────────────────────────────────────────────────
    create_if_not_exists table(:items, primary_key: false) do
      add :id,          :binary_id, primary_key: true
      add :slug,        :string, null: false
      add :name,        :string, null: false
      add :description, :text
      add :item_type,   :string, null: false, default: "misc"
      # slot_type: head|body|hands|feet|cloak|ring|earring|necklace|belt|main_hand|off_hand|bag
      add :slot_type,   :string, null: false, default: "bag"
      add :rarity,      :string, null: false, default: "common"
      # JSON stats: %{hp: 0, mp: 0, attack: 0, defense: 0, ...}
      add :base_stats,  :map, null: false, default: %{}
      add :max_level,   :integer, null: false, default: 99
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:items, [:slug])

    # ── Character Inventory (bag slots 0-49) ───────────────────────────────────
    create_if_not_exists table(:character_inventory, primary_key: false) do
      add :id,           :binary_id, primary_key: true
      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      add :item_id,      references(:items,      type: :binary_id, on_delete: :restrict),   null: false
      add :bag_slot,     :integer, null: false   # 0-49
      add :quantity,     :integer, null: false, default: 1
      add :item_level,   :integer, null: false, default: 1
      add :item_xp,      :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:character_inventory, [:character_id, :bag_slot])
    create_if_not_exists index(:character_inventory, [:character_id])

    # ── Character Equipment (equipped slots) ───────────────────────────────────
    create_if_not_exists table(:character_equipment, primary_key: false) do
      add :id,           :binary_id, primary_key: true
      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      add :item_id,      references(:items,      type: :binary_id, on_delete: :restrict),   null: false
      # slot_type must be one of the 13 valid equipment slots
      add :slot_type,    :string, null: false
      add :item_level,   :integer, null: false, default: 1
      add :item_xp,      :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:character_equipment, [:character_id, :slot_type])
    create_if_not_exists index(:character_equipment, [:character_id])
  end

  def down do
    drop_if_exists index(:character_equipment, [:character_id])
    drop_if_exists index(:character_equipment, [:character_id, :slot_type])
    drop_if_exists table(:character_equipment)

    drop_if_exists index(:character_inventory, [:character_id])
    drop_if_exists index(:character_inventory, [:character_id, :bag_slot])
    drop_if_exists table(:character_inventory)

    drop_if_exists index(:items, [:slug])
    drop_if_exists table(:items)

    drop_if_exists index(:character_spells, [:character_id])
    drop_if_exists index(:character_spells, [:character_id, :spell_id])
    drop_if_exists table(:character_spells)

    drop_if_exists index(:spells, [:slug])
    drop_if_exists table(:spells)

    alter table(:characters) do
      remove_if_exists :pvp_flagged, :boolean
      remove_if_exists :max_mp,      :integer
      remove_if_exists :mp,          :integer
      remove_if_exists :max_hp,      :integer
      remove_if_exists :hp,          :integer
    end
  end
end
