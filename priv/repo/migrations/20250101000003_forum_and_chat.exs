defmodule PhoenixApp.Repo.Migrations.ForumAndChat do
  @moduledoc """
  ============================================================================
  FORUM & CHAT TABLES
  ============================================================================
  Chat channels, messages, threads, reactions, and related features.
  """
  use Ecto.Migration

  def change do
    # ============================================================================
    # CHAT CHANNELS
    # ============================================================================
    
    create_if_not_exists table(:chat_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :topic, :string
      add :channel_type, :string, default: "text"
      add :is_private, :boolean, default: false
      add :is_public, :boolean, default: true
      add :is_user_created, :boolean, default: false
      add :max_participants, :integer, default: 50
      add :invite_code, :string
      add :icon_path, :string
      add :settings, :map, default: %{}
      add :position, :integer, default: 0
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:chat_channels, [:channel_type])
    create_if_not_exists index(:chat_channels, [:is_private])
    create_if_not_exists index(:chat_channels, [:is_public])
    create_if_not_exists index(:chat_channels, [:is_user_created])
    create_if_not_exists index(:chat_channels, [:created_by_id])
    create_if_not_exists index(:chat_channels, [:owner_id])
    create_if_not_exists index(:chat_channels, [:position])
    create_if_not_exists unique_index(:chat_channels, [:invite_code], where: "invite_code IS NOT NULL")

    # ============================================================================
    # CHAT THREADS
    # ============================================================================

    create_if_not_exists table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :is_archived, :boolean, default: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:chat_threads, [:channel_id])
    create_if_not_exists index(:chat_threads, [:is_archived])

    # ============================================================================
    # CHAT MESSAGES
    # ============================================================================

    create_if_not_exists table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :is_pinned, :boolean, default: false
      add :edited_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)
      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end
    
    create_if_not_exists index(:chat_messages, [:thread_id])
    create_if_not_exists index(:chat_messages, [:channel_id])
    create_if_not_exists index(:chat_messages, [:user_id])
    create_if_not_exists index(:chat_messages, [:message_type])
    create_if_not_exists index(:chat_messages, [:is_pinned])
    create_if_not_exists index(:chat_messages, [:reply_to_id])
    create_if_not_exists index(:chat_messages, [:inserted_at])

    # Add parent_message_id to chat_threads (circular reference)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_threads' AND column_name = 'parent_message_id'
      ) THEN
        ALTER TABLE chat_threads 
        ADD COLUMN parent_message_id uuid REFERENCES chat_messages(id) ON DELETE CASCADE;
      END IF;
    END $$;
    """, ""

    create_if_not_exists index(:chat_threads, [:parent_message_id])

    # ============================================================================
    # CHAT MESSAGE ATTACHMENTS
    # ============================================================================

    create_if_not_exists table(:chat_message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string
      add :file_size, :integer
      add :file, :string, null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:chat_message_attachments, [:message_id])
    create_if_not_exists index(:chat_message_attachments, [:channel_id])
    create_if_not_exists index(:chat_message_attachments, [:user_id])

    # ============================================================================
    # CHAT REACTIONS
    # ============================================================================

    create_if_not_exists table(:chat_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:chat_reactions, [:user_id, :message_id, :emoji])
    create_if_not_exists index(:chat_reactions, [:message_id])

    # ============================================================================
    # CHANNEL MEMBERS
    # ============================================================================

    create_if_not_exists table(:channel_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member"
      add :joined_at, :utc_datetime
      add :last_read_message_id, :binary_id
      add :last_seen_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:channel_members, [:user_id, :channel_id])
    create_if_not_exists index(:channel_members, [:channel_id])
    create_if_not_exists index(:channel_members, [:role])
    create_if_not_exists index(:channel_members, [:channel_id, :user_id, :last_read_message_id])

    # ============================================================================
    # CHANNEL INVITES
    # ============================================================================

    create_if_not_exists table(:channel_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :uses, :integer, default: 0
      add :max_uses, :integer
      add :expires_at, :utc_datetime
      add :invitee_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :is_revoked, :boolean, default: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:channel_invites, [:code])
    create_if_not_exists index(:channel_invites, [:channel_id])
    create_if_not_exists index(:channel_invites, [:created_by_id])
    create_if_not_exists index(:channel_invites, [:invitee_id])
    create_if_not_exists index(:channel_invites, [:is_revoked])

    # ============================================================================
    # CUSTOM EMOJIS
    # ============================================================================

    create_if_not_exists table(:custom_emojis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :shortcode, :string, null: false
      add :emoji, :string
      add :image_url, :string
      add :category, :string, default: "Custom"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create_if_not_exists unique_index(:custom_emojis, [:shortcode])
    create_if_not_exists index(:custom_emojis, [:category])
    create_if_not_exists index(:custom_emojis, [:created_by_id])

    # ============================================================================
    # STREAMING SESSIONS
    # ============================================================================

    create_if_not_exists table(:streaming_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :status, :string, default: "pending"
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :viewer_count, :integer, default: 0
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:streaming_sessions, [:channel_id])
    create_if_not_exists index(:streaming_sessions, [:user_id])
    create_if_not_exists index(:streaming_sessions, [:status])
  end
end
