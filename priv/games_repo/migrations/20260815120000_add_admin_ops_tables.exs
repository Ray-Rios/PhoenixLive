defmodule PhoenixApp.GamesRepo.Migrations.AddAdminOpsTables do
  @moduledoc """
  The data behind the RaysSpaceSim admin section: who is on which instance,
  the command channel that lets an admin act on a running server, and a record
  of who did what.

  ## Why the roster is a jsonb column and not a table

  A `server_players` table would join cleanly to characters and keep history,
  but every heartbeat would have to reconcile it - delete the leavers, insert
  the joiners - several times a minute per instance, forever, to represent
  something that is only ever read as a whole. The roster is a snapshot, not a
  ledger. One jsonb write per heartbeat is atomic, cheap, and cannot drift out
  of sync with the count beside it.

  History, if it is wanted later, belongs in its own append-only table rather
  than being a side effect of presence.

  ## Why commands are a table and not a column

  A single `pending_command` column cannot express "kick these three players",
  and it silently loses the second instruction if an admin issues two before
  the next heartbeat. A queue is barely more code and does not have that shape
  of bug.
  """
  use Ecto.Migration

  def up do
    alter table(:game_servers) do
      # WHO IS ACTUALLY ON THIS SERVER.
      #
      # current_players already carries the count. The count cannot answer
      # "which instance is this player in", which is the question an admin
      # actually has, so this carries the identities alongside it.
      #
      # Shaped as %{"players" => [%{"user_id" => ..., "character_id" => ...,
      # "name" => ..., "joined_at" => ...}]} - an object at the top level, not a
      # bare array, so the column is a plain Ecto :map with no array-of-jsonb
      # ambiguity, and so more per-instance facts can be added beside it later
      # without another migration.
      add_if_not_exists :roster, :map, null: false, default: %{}
    end

    # "Where is user X right now" - a containment query over the roster. GIN is
    # what makes that an index lookup instead of a scan across every instance.
    # execute/1, NOT execute/2. The two-argument reversible form is only legal
    # inside change/0 - Ecto rejects it in up/0 - and this module defines up/0
    # and down/0 because the rest of it needs them. The down side of this index
    # lives in down/0 below, where it belongs.
    execute(
      "CREATE INDEX IF NOT EXISTS game_servers_roster_idx ON game_servers USING GIN (roster jsonb_path_ops)"
    )

    # -----------------------------------------------------------------------
    # The control channel.
    #
    # Instances heartbeat; nothing can call INTO them. Rather than add a second
    # transport just for admin actions, the heartbeat RESPONSE carries whatever
    # is queued here. That is why this table exists at all: no sockets, no
    # inbound firewall rules, and an instance that has gone away simply stops
    # collecting - which is the correct behaviour for a command aimed at it.
    # -----------------------------------------------------------------------
    create_if_not_exists table(:server_commands, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :server_id,
          references(:game_servers, type: :binary_id, on_delete: :delete_all),
          null: false

      # shutdown | drain | kick
      #
      # A plain string for the same reason game_servers.status is one: adding a
      # verb later should be a code change, not a migration holding a lock.
      add :command, :string, null: false

      # kick carries the user to remove; shutdown and drain carry a reason that
      # the server can show players before it goes.
      add :payload, :map, null: false, default: %{}

      add :issued_by_user_id, :binary_id
      add :issued_at, :utc_datetime, null: false

      # NULL means still queued. Set when a heartbeat carries it away, so the
      # admin UI can distinguish "sent" from "sitting here because that instance
      # is not heartbeating any more" - which is a different problem with a
      # different fix.
      add :delivered_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # The hot query, run on every heartbeat: undelivered commands for one server.
    create_if_not_exists index(:server_commands, [:server_id, :delivered_at])

    # -----------------------------------------------------------------------
    # Audit.
    #
    # Worth having from the first day there are two admins, and impossible to
    # backfill from the day it is first wanted - which is always the day
    # something was destroyed and nobody remembers doing it.
    # -----------------------------------------------------------------------
    create_if_not_exists table(:admin_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Deliberately NOT a foreign key. Users live in the main repo, not this
      # one, and an audit record must survive the account it refers to being
      # deleted - an audit log with cascading deletes is not an audit log.
      add :actor_user_id, :binary_id, null: false
      add :actor_email, :string

      add :action, :string, null: false

      # server | holo_sim | character | game
      add :subject_type, :string
      add :subject_id, :binary_id

      # Whatever makes the entry legible a year later: the sim's name, the
      # player kicked, the reason given.
      add :details, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create_if_not_exists index(:admin_actions, [:inserted_at])
    create_if_not_exists index(:admin_actions, [:subject_type, :subject_id])
    create_if_not_exists index(:admin_actions, [:actor_user_id])
  end

  def down do
    drop_if_exists index(:admin_actions, [:actor_user_id])
    drop_if_exists index(:admin_actions, [:subject_type, :subject_id])
    drop_if_exists index(:admin_actions, [:inserted_at])
    drop_if_exists table(:admin_actions)

    drop_if_exists index(:server_commands, [:server_id, :delivered_at])
    drop_if_exists table(:server_commands)

    execute("DROP INDEX IF EXISTS game_servers_roster_idx")

    alter table(:game_servers) do
      remove_if_exists :roster, :map
    end
  end
end
