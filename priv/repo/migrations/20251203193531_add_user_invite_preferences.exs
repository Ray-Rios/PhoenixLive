defmodule PhoenixApp.Repo.Migrations.AddUserInvitePreferences do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Invite preferences
      add :allow_channel_invites, :boolean, default: true
      add :blocked_user_ids, {:array, :binary_id}, default: []
      
      # Audio/notification preferences
      add :notification_sound_enabled, :boolean, default: true
      add :master_volume, :float, default: 0.7
    end
  end
end
