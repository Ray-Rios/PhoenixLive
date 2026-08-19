defmodule PhoenixApp.GamesRepo.Migrations.AddInstanceColumnsToGameServers do
  use Ecto.Migration

  def up do
    alter table(:game_servers) do
      # NULL  = a world server (the shared solar system).
      # SET   = a Holo-sim instance running exactly one player's sim.
      add_if_not_exists :holo_sim_id, references(:holo_sims, type: :binary_id, on_delete: :nilify_all)

      # Which player this instance was started for.
      #
      # Instances are never shared - one launch, one player, one process. This
      # column is what makes "you already have an active sim" answerable, and
      # what lets a reconnecting player be routed back to their own pod rather
      # than a stranger's.
      add_if_not_exists :instance_user_id, :binary_id
    end

    # The hot lookup: "does this player already have an instance running?"
    create_if_not_exists index(:game_servers, [:game_id, :instance_user_id])
    create_if_not_exists index(:game_servers, [:holo_sim_id])
  end

  def down do
    drop_if_exists index(:game_servers, [:holo_sim_id])
    drop_if_exists index(:game_servers, [:game_id, :instance_user_id])

    alter table(:game_servers) do
      remove_if_exists :instance_user_id, :binary_id
      remove_if_exists :holo_sim_id, references(:holo_sims, type: :binary_id)
    end
  end
end
