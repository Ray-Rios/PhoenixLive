defmodule PhoenixApp.Repo.Migrations.AddUserIdToMessageAttachments do
  use Ecto.Migration

  def change do
    alter table(:chat_message_attachments) do
      add_if_not_exists :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:chat_message_attachments, [:user_id])
  end
end
