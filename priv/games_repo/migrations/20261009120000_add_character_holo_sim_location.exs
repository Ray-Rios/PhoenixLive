defmodule Phxlive.GamesRepo.Migrations.AddCharacterHoloSimLocation do
  @moduledoc """
  Resume-in-instance: if a character logs out inside an instance, the next
  login puts them back there, unless they chose to leave it.

  Written only by an instance server (server API key) on Logout, and cleared
  when the player leaves. Like the session-claim columns, these are NOT in
  GameCharacter's cast list - a player who could write them could point their
  character at an instance they cannot enter and make the client try it on
  every login. The player token may only CLEAR them (see
  GamesController.set_instance_location/2). `instance_location` is opaque to
  the hub; the game writes and reads it.

  Rewritten 2026-10-16 (PHXLIVE.md §9) to the columns' current names and with
  no foreign key, which the game's plugin adds. The module name is kept so the
  migration's identity is unchanged; databases that ran the original are
  renamed by `20261016020000_rename_holo_columns_to_instance`.
  """

  use Ecto.Migration

  def up do
    alter table(:game_characters) do
      add_if_not_exists :instance_id, :binary_id
      add_if_not_exists :instance_location, :map
    end

    create_if_not_exists index(:game_characters, [:instance_id])
  end

  def down do
    drop_if_exists index(:game_characters, [:instance_id])

    alter table(:game_characters) do
      remove_if_exists :instance_location, :map
      remove_if_exists :instance_id, :binary_id
    end
  end
end
