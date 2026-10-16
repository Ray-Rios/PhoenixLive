defmodule Phxlive.GamesRepo.Migrations.RenameHoloColumnsToInstance do
  @moduledoc """
  RaysSpaceSim moved into its own plugin (PHXLIVE.md §9), and the hub's
  tables stopped using its words: `holo_sim_id` becomes `instance_id` on
  `game_servers` and `game_characters`, and `holo_sim_location` becomes
  `instance_location`. Indexes and foreign keys are renamed to match (the
  foreign keys themselves are the plugin's and stay as they are).

  A no-op on databases built after the rewrite of the earlier migrations,
  which create the new names directly. Data is untouched.
  """
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = current_schema() AND table_name = 'game_servers' AND column_name = 'holo_sim_id') THEN
        ALTER TABLE game_servers RENAME COLUMN holo_sim_id TO instance_id;
      END IF;

      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = current_schema() AND table_name = 'game_characters' AND column_name = 'holo_sim_id') THEN
        ALTER TABLE game_characters RENAME COLUMN holo_sim_id TO instance_id;
      END IF;

      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = current_schema() AND table_name = 'game_characters' AND column_name = 'holo_sim_location') THEN
        ALTER TABLE game_characters RENAME COLUMN holo_sim_location TO instance_location;
      END IF;
    END $$;
    """

    execute "ALTER INDEX IF EXISTS game_servers_holo_sim_id_index RENAME TO game_servers_instance_id_index"
    execute "ALTER INDEX IF EXISTS game_characters_holo_sim_id_index RENAME TO game_characters_instance_id_index"

    # Ecto's foreign_key_constraint(:instance_id) looks for these names.
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'game_servers_holo_sim_id_fkey') THEN
        ALTER TABLE game_servers RENAME CONSTRAINT game_servers_holo_sim_id_fkey TO game_servers_instance_id_fkey;
      END IF;

      IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'game_characters_holo_sim_id_fkey') THEN
        ALTER TABLE game_characters RENAME CONSTRAINT game_characters_holo_sim_id_fkey TO game_characters_instance_id_fkey;
      END IF;
    END $$;
    """
  end

  def down, do: :ok
end
