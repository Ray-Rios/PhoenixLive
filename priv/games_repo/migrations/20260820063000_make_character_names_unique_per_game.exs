defmodule PhoenixApp.GamesRepo.Migrations.MakeCharacterNamesUniquePerGame do
  use Ecto.Migration

  # Character names used to be unique per (game, user) - two different
  # accounts could each have a character named "Wesley" in the same game,
  # which showed up in a real client-server PIE test as two different
  # players both calling themselves the same name. That is wrong for a
  # game where the name is what other players actually see: it needs to be
  # unique across the whole game, not just within one account.
  def up do
    # Existing data can already violate the new constraint - that is
    # exactly what triggered this migration - so disambiguate before
    # creating it, or CREATE UNIQUE INDEX fails outright on the first
    # collision. The earliest character by inserted_at keeps its name;
    # later ones get " 2", " 3", etc appended. Not pretty, but deterministic,
    # it only touches rows that were already colliding, and a player who
    # gets renamed will notice immediately and can pick something else.
    execute(
      """
      WITH ranked AS (
        SELECT id, game_id, name,
               ROW_NUMBER() OVER (PARTITION BY game_id, name ORDER BY inserted_at, id) AS rn
        FROM game_characters
      )
      UPDATE game_characters gc
      SET name = gc.name || ' ' || ranked.rn
      FROM ranked
      WHERE gc.id = ranked.id AND ranked.rn > 1
      """,
      "-- no-op: cannot un-rename characters on rollback"
    )

    drop_if_exists index(:game_characters, [:game_id, :user_id, :name])
    create_if_not_exists unique_index(:game_characters, [:game_id, :name])
  end

  def down do
    drop_if_exists index(:game_characters, [:game_id, :name])
    create_if_not_exists unique_index(:game_characters, [:game_id, :user_id, :name])
  end
end
