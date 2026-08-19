defmodule PhoenixApp.GamesRepo.Migrations.HoloSimsSharedInstances do
  use Ecto.Migration

  @moduledoc """
  Moves Holo-sims from per-player instances to SHARED instances.

  The original design gave every player their own copy of a sim. That was a
  misreading: public sims mean people join the SAME instance, so an instance
  belongs to a sim, not to a player.

  Three consequences, all here:

    * `game_servers.instance_user_id` becomes `launched_by_user_id` — who
      started it, for attribution only. Lookups now key on `holo_sim_id` alone.
    * `holo_sim_states` loses its per-user key. One shared world in memory can
      only have one saved state; per-player state was incoherent the moment
      instances became shared.
    * `holo_sims.visitors_can_build` decides whether anyone but the owner may
      leave a permanent mark.
  """

  def up do
    # --- game_servers: attribution, not ownership --------------------
    rename table(:game_servers), :instance_user_id, to: :launched_by_user_id

    drop_if_exists index(:game_servers, [:game_id, :instance_user_id])
    create_if_not_exists index(:game_servers, [:game_id, :launched_by_user_id])

    # --- holo_sims: who may leave a permanent mark -------------------
    alter table(:holo_sims) do
      # False by default. A visitor to a public sim can interact with the world
      # but nothing they do survives them leaving, which is the safe default -
      # a public sim is otherwise unrecoverable griefing with no undo.
      add_if_not_exists :visitors_can_build, :boolean, null: false, default: false
    end

    # --- holo_sim_states: one world, one state -----------------------
    #
    # Existing rows are per (sim, user). Collapsing them means picking one row
    # per sim, and the only defensible pick is the OWNER's - it is their world.
    # Everything else is discarded.
    execute """
    DELETE FROM holo_sim_states hss
    USING holo_sims hs
    WHERE hss.holo_sim_id = hs.id
      AND hss.user_id IS DISTINCT FROM hs.owner_user_id
    """

    drop_if_exists index(:holo_sim_states, [:holo_sim_id, :user_id])

    alter table(:holo_sim_states) do
      # Kept as "who last saved", useful for moderation once visitors can build.
      # No longer part of the key.
      add_if_not_exists :last_saved_by_user_id, :binary_id
    end

    execute "UPDATE holo_sim_states SET last_saved_by_user_id = user_id"

    create_if_not_exists unique_index(:holo_sim_states, [:holo_sim_id])
  end

  def down do
    drop_if_exists unique_index(:holo_sim_states, [:holo_sim_id])

    alter table(:holo_sim_states) do
      remove_if_exists :last_saved_by_user_id, :binary_id
    end

    create_if_not_exists unique_index(:holo_sim_states, [:holo_sim_id, :user_id])

    alter table(:holo_sims) do
      remove_if_exists :visitors_can_build, :boolean
    end

    drop_if_exists index(:game_servers, [:game_id, :launched_by_user_id])
    create_if_not_exists index(:game_servers, [:game_id, :instance_user_id])

    rename table(:game_servers), :launched_by_user_id, to: :instance_user_id
  end
end
