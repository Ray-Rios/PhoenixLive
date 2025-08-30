defmodule PhoenixApp.Repo.Migrations.CreateFilesTables do
  use Ecto.Migration
@disable_ddl_transaction true

  def change do
    # User Files
    create table(:user_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :file_path, :string
      add :file, :string
      add :is_public, :boolean, default: false
      add :description, :text
      add :tags, {:array, :string}, default: []
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_files, [:user_id])
    create index(:user_files, [:content_type])
    create index(:user_files, [:is_public])
    create index(:user_files, [:inserted_at])
  end
end