defmodule PhoenixApp.GamesRepo.Migrations.AddCharacterSessionClaim do
  @moduledoc """
  Single-session enforcement: a character may be in at most one live world or
  instance at a time.

  Until now `PreLoginAsync` approved a join on the Holo-sim ACL and nothing
  else, so the same character could be signed in from several clients at once -
  observed five times in one run. That is not primarily a cheating problem, it
  is a DATA problem: `ARSSGameModeBase::Logout` writes a position checkpoint to
  the hub, so two sessions racing the same character means whichever one leaves
  last silently overwrites the other's progress.

  ENFORCED PER CHARACTER, NOT PER ACCOUNT, deliberately. The row is the thing
  that can be corrupted, and two clients on one account running two DIFFERENT
  characters share no row and cannot damage each other. Per-account exclusivity
  is a product decision (and `Games.find_player_server/2` already answers it if
  it is ever wanted); per-character is the data-integrity boundary, which is
  what this is for.
  """

  use Ecto.Migration

  def up do
    alter table(:game_characters) do
      # WHICH SERVER HOLDS THIS CHARACTER, or null when nobody does.
      #
      # A real FK this time - unlike user_id, game_servers lives in this same
      # database, so the constraint is available and worth having. nilify_all
      # means pruning a long-dead server row releases its claims as a side
      # effect rather than leaving characters pointing at a server that no
      # longer exists.
      add :active_server_id,
          references(:game_servers, type: :binary_id, on_delete: :nilify_all)

      # Opaque token handed to the server that won the claim. It presents this
      # to release, which stops a second server releasing a claim it does not
      # hold just because it knows the character id.
      add :active_session_id, :binary_id

      # Informational, not load-bearing. Liveness is "active_server_id is set
      # AND that server's heartbeat is fresh" - one definition, shared with
      # every other liveness question in this schema. These two exist so an
      # admin screen can say how long someone has been in, and so a released
      # session leaves a readable trace behind.
      add :session_started_at, :utc_datetime
      add :session_last_seen_at, :utc_datetime
    end

    # The reconciliation query on every heartbeat is "characters claimed by THIS
    # server", so that column is the one that needs an index. Partial, because
    # the overwhelming majority of rows have no claim at all and there is no
    # reason to carry them in it.
    create_if_not_exists index(:game_characters, [:active_server_id],
                           where: "active_server_id IS NOT NULL",
                           name: :game_characters_active_server_id_index
                         )
  end

  def down do
    drop_if_exists index(:game_characters, [:active_server_id],
                     name: :game_characters_active_server_id_index
                   )

    alter table(:game_characters) do
      remove :active_server_id
      remove :active_session_id
      remove :session_started_at
      remove :session_last_seen_at
    end
  end
end
