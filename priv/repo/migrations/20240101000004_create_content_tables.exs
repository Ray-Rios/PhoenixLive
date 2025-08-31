defmodule PhoenixApp.Repo.Migrations.CreateContentTables do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    # Posts
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :excerpt, :text
      add :is_published, :boolean, default: false
      add :published_at, :utc_datetime
      add :featured_image, :string
      add :meta_description, :string
      add :tags, {:array, :string}, default: []
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:user_id])
    create index(:posts, [:is_published])
    create index(:posts, [:published_at])
    create index(:posts, [:tags])

    # Pages
    create table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :is_published, :boolean, default: false
      add :meta_description, :string
      add :template, :string, default: "default"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pages, [:slug])
    create index(:pages, [:is_published])

    # Comments (for posts)
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :is_approved, :boolean, default: false
      add :author_name, :string
      add :author_email, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:post_id])
    create index(:comments, [:user_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:is_approved])
    create index(:comments, [:inserted_at])
  end
end