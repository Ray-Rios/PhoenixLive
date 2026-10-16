defmodule Phxlive.GamesRepo.Migrations.AddInstanceColumnsToGameServers do
  @moduledoc """
  Instance servers: a server row with `instance_id` set is running one
  game-defined instance (NULL = a world server). `launched_by_user_id` is who
  started it, for attribution only.

  Rewritten 2026-10-16 (PHXLIVE.md §9) to the columns' current names and with
  no foreign key: what an instance is belongs to the game's plugin, which adds
  its own constraint. Databases that
  ran the original version are brought to the same shape by
  `20261016020000_rename_holo_columns_to_instance`.
  """
  use Ecto.Migration

  def up do
    alter table(:game_servers) do
      add_if_not_exists :instance_id, :binary_id
      add_if_not_exists :launched_by_user_id, :binary_id
    end

    create_if_not_exists index(:game_servers, [:game_id, :launched_by_user_id])
    create_if_not_exists index(:game_servers, [:instance_id])
  end

  def down do
    drop_if_exists index(:game_servers, [:instance_id])
    drop_if_exists index(:game_servers, [:game_id, :launched_by_user_id])

    alter table(:game_servers) do
      remove_if_exists :launched_by_user_id, :binary_id
      remove_if_exists :instance_id, :binary_id
    end
  end
end
