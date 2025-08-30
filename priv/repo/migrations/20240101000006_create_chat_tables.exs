defmodule PhoenixApp.Repo.Migrations.CreateChatTables do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    # Chat Channels
    create table(:chat_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :topic, :string
      add :channel_type, :string, default: "text"
      add :is_private, :boolean, default: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_channels, [:channel_type])
    create index(:chat_channels, [:is_private])
    create index(:chat_channels, [:created_by_id])

    # Chat Messages
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :is_pinned, :boolean, default: false
      add :edited_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:channel_id])
    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:message_type])
    create index(:chat_messages, [:is_pinned])
    create index(:chat_messages, [:reply_to_id])
    create index(:chat_messages, [:inserted_at])

    # Chat Message Attachments
    create table(:chat_message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string
      add :file_size, :integer
      add :file, :string, null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_message_attachments, [:message_id])

    # Chat Reactions
    create table(:chat_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_reactions, [:user_id, :message_id, :emoji])
    create index(:chat_reactions, [:message_id])

    # Chat Threads
    create table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :is_archived, :boolean, default: false
      add :parent_message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_threads, [:parent_message_id])
    create index(:chat_threads, [:channel_id])
    create index(:chat_threads, [:is_archived])
  end
end