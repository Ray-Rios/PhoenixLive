defmodule PhoenixApp.Repo.Migrations.EnhanceForumForUserChannels do
  use Ecto.Migration

  def change do
    # Add ownership and visibility to channels
    alter table(:chat_channels) do
      add :owner_id, references(:users, on_delete: :delete_all, type: :binary_id), null: true
      add :is_public, :boolean, default: true, null: false
      add :is_user_created, :boolean, default: false, null: false
      add :max_participants, :integer, default: 50
      add :invite_code, :string
      add :settings, :map, default: %{}
    end

    # Create index for faster queries
    create index(:chat_channels, [:owner_id])
    create index(:chat_channels, [:is_public])
    create index(:chat_channels, [:is_user_created])
    create unique_index(:chat_channels, [:invite_code], where: "invite_code IS NOT NULL")

    # Create channel members table for user-created channels
    create table(:channel_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :channel_id, references(:chat_channels, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :role, :string, default: "member", null: false # owner, admin, moderator, member
      add :nickname, :string
      add :is_muted, :boolean, default: false
      add :is_banned, :boolean, default: false
      add :joined_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channel_members, [:channel_id, :user_id])
    create index(:channel_members, [:user_id])
    create index(:channel_members, [:role])

    # Create streaming sessions table
    create table(:streaming_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :channel_id, references(:chat_channels, on_delete: :delete_all, type: :binary_id), null: false
      add :streamer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :title, :string, null: false
      add :stream_type, :string, null: false # audio, video, screen
      add :is_active, :boolean, default: true, null: false
      add :viewer_count, :integer, default: 0
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:streaming_sessions, [:channel_id])
    create index(:streaming_sessions, [:streamer_id])
    create index(:streaming_sessions, [:is_active])

    # Create channel invites table
    create table(:channel_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :channel_id, references(:chat_channels, on_delete: :delete_all, type: :binary_id), null: false
      add :inviter_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :code, :string, null: false
      add :max_uses, :integer
      add :uses, :integer, default: 0
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channel_invites, [:code])
    create index(:channel_invites, [:channel_id])
  end
end
