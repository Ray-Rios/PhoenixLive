defmodule PhoenixApp.Repo.Migrations.AddFolderPathToUserFiles do
  use Ecto.Migration

  def change do
    # Add folder_path to user_files table
    alter table(:user_files) do
      add :folder_path, :string, default: "/", null: false
    end

    # Add folder_path to user_media table  
    alter table(:user_media) do
      add :folder_path, :string, default: "/", null: false
    end

    # Create indexes for efficient folder browsing
    create index(:user_files, [:user_id, :folder_path])
    create index(:user_media, [:user_id, :folder_path])

    # Create a table for user folders (virtual folders for organization)
    create table(:user_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :path, :string, null: false  # Full path like "/Documents/Work"
      add :parent_path, :string, default: "/"  # Parent folder path
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :color, :string  # Optional folder color
      add :icon, :string   # Optional folder icon

      timestamps(type: :utc_datetime)
    end

    create index(:user_folders, [:user_id, :parent_path])
    create unique_index(:user_folders, [:user_id, :path], name: :user_folders_user_path_unique)
  end
end
