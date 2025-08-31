defmodule PhoenixApp.Repo.Migrations.AddThreadIdToChatMessages do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:chat_messages, [:thread_id])
  end
end