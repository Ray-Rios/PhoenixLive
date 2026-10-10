defmodule PhoenixApp.GamesRepo.Migrations.AddCharacterHoloSimLocation do
  @moduledoc """
  Resume-in-sim (Ray, 2026-10-09): "if a character is logged out while in a
  holo-sim, they should log back in to the same spot, but not if they've chosen
  to /exit the sim."

  Written only by the Holo-sim instance (server API key) on Logout, and cleared
  by it when the player left with /exit. Like the session-claim columns, these
  are NOT in GameCharacter's cast list - a player who could write them could
  point their character at a sim they cannot enter and make the client try it
  on every login. The player token may only CLEAR them (see
  GamesController.set_holo_location/2).

  `holo_sim_id` is a real FK: holo_sims lives in this database, and
  nilify_all means deleting a sim quietly sends everyone resuming into it back
  to the world server instead of into a 404.

  `holo_sim_location` is opaque to the hub - the instance writes and reads it.
  It is either {"mode": "abs", ...} or {"mode": "body", "body": key, ...}; see
  UHoloSimWorldSubsystem in the game.
  """

  use Ecto.Migration

  def change do
    alter table(:game_characters) do
      add :holo_sim_id, references(:holo_sims, type: :binary_id, on_delete: :nilify_all)
      add :holo_sim_location, :map
    end

    create index(:game_characters, [:holo_sim_id])
  end
end
