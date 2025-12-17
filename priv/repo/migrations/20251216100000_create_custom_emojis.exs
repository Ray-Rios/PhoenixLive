defmodule PhoenixApp.Repo.Migrations.CreateCustomEmojis do
  use Ecto.Migration

  def change do
    create table(:custom_emojis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :shortcode, :string, null: false
      add :emoji, :string  # For unicode emojis that are custom-aliased
      add :image_url, :string  # For custom image emojis
      add :category, :string, default: "Custom"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      
      timestamps()
    end

    create unique_index(:custom_emojis, [:shortcode])
    create index(:custom_emojis, [:category])
    create index(:custom_emojis, [:created_by_id])
  end
end
