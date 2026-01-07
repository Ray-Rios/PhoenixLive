defmodule PhoenixApp.Repo.Migrations.CreateUserNotifications do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :title, :string
      add :content, :text
      add :read, :boolean, default: false, null: false
      add :read_at, :utc_datetime
      
      # Link to the resource
      add :resource_type, :string
      add :resource_id, :binary_id
      
      # Additional context for navigation
      add :metadata, :map, default: %{}
      
      # Relationships
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create_if_not_exists index(:user_notifications, [:user_id])
    create_if_not_exists index(:user_notifications, [:user_id, :read])
    create_if_not_exists index(:user_notifications, [:user_id, :inserted_at])
    create_if_not_exists index(:user_notifications, [:resource_type, :resource_id])
  end
end
