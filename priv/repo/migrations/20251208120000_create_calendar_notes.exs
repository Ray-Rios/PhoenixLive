defmodule PhoenixApp.Repo.Migrations.CreateCalendarNotes do
  use Ecto.Migration

  def change do
    create table(:calendar_notes) do
      add :date, :date, null: false
      add :content, :text
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:calendar_notes, [:user_id, :date], unique: true)
  end
end
