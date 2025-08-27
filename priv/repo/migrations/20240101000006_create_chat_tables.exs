defmodule PhoenixApp.Repo.Migrations.CreateChatTables do
  use Ecto.Migration

  def change do
    # Chat Channels
    create table(:chat_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :topic, :string
      add :is_private, :boolean, default: false
      add :position, :integer, default: 0
      add :channel_type, :string, default: "text"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_channels, [:name])
    create index(:chat_channels, [:channel_type])
    create index(:chat_channels, [:position])

    # Chat Messages (without thread_id initially to avoid circular dependency)
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :edited_at, :utc_datetime
      add :is_pinned, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:channel_id])
    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:inserted_at])
    create index(:chat_messages, [:is_pinned])

    # Chat Threads
    create table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :is_archived, :boolean, default: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_threads, [:message_id])
    create index(:chat_threads, [:user_id])

    # Add thread_id to chat_messages after chat_threads table is created
    alter table(:chat_messages) do
      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :delete_all)
    end

    create index(:chat_messages, [:thread_id])

    # Chat Reactions
    create table(:chat_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_reactions, [:message_id, :user_id, :emoji])

    # Chat Message Attachments
    create table(:chat_message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :file, :string
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_message_attachments, [:message_id])
  end
end