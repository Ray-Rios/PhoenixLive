defmodule PhoenixApp.GamesRepo.Migrations.HoloSimStatesUserIdNullable do
  use Ecto.Migration

  # holo_sim_states.user_id was the per-player key before instances became
  # shared (20260811110000). That migration dropped the key but left the column
  # NOT NULL, so every first save of a sim failed the insert with a 500.
  def up do
    alter table(:holo_sim_states) do
      modify :user_id, :binary_id, null: true
    end
  end

  def down do
    execute "UPDATE holo_sim_states SET user_id = last_saved_by_user_id WHERE user_id IS NULL"

    alter table(:holo_sim_states) do
      modify :user_id, :binary_id, null: false
    end
  end
end
