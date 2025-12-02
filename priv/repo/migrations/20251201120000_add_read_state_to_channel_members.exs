defmodule PhoenixApp.Repo.Migrations.AddReadStateToChannelMembers do
  use Ecto.Migration

  def change do
    alter table(:channel_members) do
      add :last_read_message_id, :binary_id
      add :last_seen_at, :utc_datetime
    end

    create index(:channel_members, [:channel_id, :user_id, :last_read_message_id])
  end
end
