defmodule PhoenixApp.Repo.Migrations.ContentManagement do
  @moduledoc """
  ============================================================================
  CONTENT MANAGEMENT TABLES
  ============================================================================
  Posts, pages, comments, and media management.
  """
  use Ecto.Migration

  def change do
    # ============================================================================
    # POSTS (Blog System)
    # ============================================================================
    
    create_if_not_exists table(:posts, primary_key: false) do
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
      add :show_share_buttons, :boolean, default: true
      add :share_platforms, {:array, :string}, default: ["twitter", "facebook", "linkedin", "reddit", "email"]
      add :share_buttons_colored, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:posts, [:slug])
    create_if_not_exists index(:posts, [:user_id])
    create_if_not_exists index(:posts, [:is_published])
    create_if_not_exists index(:posts, [:published_at])
    create_if_not_exists index(:posts, [:tags])

    # ============================================================================
    # PAGES
    # ============================================================================

    create_if_not_exists table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :excerpt, :text
      add :is_published, :boolean, default: false
      add :published_at, :utc_datetime
      add :meta_description, :string
      add :meta_keywords, :string
      add :template_type, :string, default: "default"
      add :featured_image, :string
      add :category, :string
      add :order, :integer, default: 0
      add :show_share_buttons, :boolean, default: true
      add :share_platforms, {:array, :string}, default: ["twitter", "facebook", "linkedin", "reddit", "email"]
      add :share_buttons_colored, :boolean, default: false
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:pages, [:slug])
    create_if_not_exists index(:pages, [:is_published])
    create_if_not_exists index(:pages, [:author_id])

    # ============================================================================
    # COMMENTS
    # ============================================================================

    create_if_not_exists table(:comments, primary_key: false) do
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

    create_if_not_exists index(:comments, [:post_id])
    create_if_not_exists index(:comments, [:user_id])
    create_if_not_exists index(:comments, [:parent_id])
    create_if_not_exists index(:comments, [:is_approved])
    create_if_not_exists index(:comments, [:inserted_at])

    # ============================================================================
    # MEDIA MANAGEMENT
    # ============================================================================
    
    # User media table - stores uploaded assets
    create_if_not_exists table(:user_media, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :filename, :string, null: false
      add :original_filename, :string, null: false
      add :file_type, :string, null: false  # image, video, audio, 3d, document
      add :mime_type, :string, null: false
      add :file_size, :bigint, null: false
      add :file_path, :text, null: false
      add :url, :text, null: false
      add :alt_text, :text
      add :caption, :text
      add :width, :integer
      add :height, :integer
      add :duration, :integer
      add :metadata, :map
      add :usage_context, :string
      add :is_public, :boolean, default: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:user_media, [:user_id])
    create_if_not_exists index(:user_media, [:file_type])
    create_if_not_exists index(:user_media, [:usage_context])
    create_if_not_exists index(:user_media, [:inserted_at])

    # User files (legacy file storage)
    create_if_not_exists table(:user_files, primary_key: false) do
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

    create_if_not_exists index(:user_files, [:user_id])
    create_if_not_exists index(:user_files, [:content_type])
    create_if_not_exists index(:user_files, [:is_public])
    create_if_not_exists index(:user_files, [:inserted_at])
  end
end
