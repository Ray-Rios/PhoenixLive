defmodule PhoenixApp.Repo.Migrations.AddChannelIdToChatMessageAttachments do
  use Ecto.Migration

  def change do
    alter table(:chat_message_attachments) do
      add_if_not_exists :channel_id, references(:chat_channels, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:chat_message_attachments, [:channel_id])
  end
end
