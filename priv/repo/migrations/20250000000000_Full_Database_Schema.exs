defmodule PhoenixApp.Repo.Migrations.FullDatabaseSchema do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    # ============================================================================
    # CMS OPTIONS
    # ============================================================================
    
    create table(:cms_options) do
      add :option_name, :string, null: false
      add :option_value, :text, null: false, default: ""
      add :autoload, :string, null: false, default: "yes"

      timestamps()
    end

    create unique_index(:cms_options, [:option_name])
    create index(:cms_options, [:autoload])

    # ============================================================================
    # USERS SYSTEM
    # ============================================================================
    
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :password_hash, :string, null: false
      add :confirmed_at, :utc_datetime
      add :is_online, :boolean, default: false
      add :is_admin, :boolean, default: true
      add :last_activity, :utc_datetime
      add :avatar_shape, :string, default: "circle"
      add :avatar_color, :string, default: "#3B82F6"
      add :avatar_file, :string
      add :avatar_url, :string
      add :status, :string, default: "active"
      add :role, :string, default: "subscriber"
      add :two_factor_secret, :string
      add :two_factor_enabled, :boolean, default: false
      add :two_factor_backup_codes, {:array, :string}, default: []
      add :position_x, :float, default: 400.0
      add :position_y, :float, default: 300.0
      
      # Security & verification fields (from 20250920000001_add_security_fields_to_users.exs)
      add :email_verified_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :password_reset_token, :string
      add :password_reset_sent_at, :utc_datetime
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, type: :binary_id)
      add :registration_ip, :string
      add :last_login_ip, :string
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:is_admin])
    create index(:users, [:two_factor_enabled])
    create index(:users, [:email_verification_token])
    create index(:users, [:password_reset_token])
    create index(:users, [:locked_until])
    create index(:users, [:email_verified_at])

    # Handle duplicate usernames and create unique constraint (from 20250922000001_add_unique_username_constraint.exs)
    execute """
    WITH duplicate_names AS (
      SELECT name, COUNT(*) as count
      FROM users 
      WHERE name IS NOT NULL
      GROUP BY name 
      HAVING COUNT(*) > 1
    ),
    numbered_duplicates AS (
      SELECT u.id, u.name,
             ROW_NUMBER() OVER (PARTITION BY u.name ORDER BY u.inserted_at) as rn
      FROM users u
      INNER JOIN duplicate_names d ON u.name = d.name
    )
    UPDATE users 
    SET name = users.name || '_' || (numbered_duplicates.rn - 1)
    FROM numbered_duplicates
    WHERE users.id = numbered_duplicates.id 
    AND numbered_duplicates.rn > 1;
    """

    create unique_index(:users, [:name], name: :users_name_unique_index)

    # User tokens
    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    # ============================================================================
    # CMS TAXONOMIES AND TERMS
    # ============================================================================
    
    create table(:cms_taxonomies) do
      add :name, :string, null: false
      add :label, :string, null: false
      add :description, :text, null: false, default: ""
      add :hierarchical, :boolean, null: false, default: false
      add :public, :boolean, null: false, default: true
      add :object_type, {:array, :string}, null: false, default: []

      timestamps()
    end

    create unique_index(:cms_taxonomies, [:name])
    create index(:cms_taxonomies, [:hierarchical])
    create index(:cms_taxonomies, [:public])

    create table(:cms_terms) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text, null: false, default: ""
      add :count, :integer, null: false, default: 0
      add :parent_id, references(:cms_terms, on_delete: :nilify_all)
      add :taxonomy_id, references(:cms_taxonomies, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:cms_terms, [:taxonomy_id])
    create index(:cms_terms, [:parent_id])
    create index(:cms_terms, [:slug])
    create unique_index(:cms_terms, [:slug, :taxonomy_id])

    create table(:cms_term_meta) do
      add :term_id, references(:cms_terms, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""

      timestamps()
    end

    create index(:cms_term_meta, [:term_id])
    create index(:cms_term_meta, [:meta_key])
    create index(:cms_term_meta, [:term_id, :meta_key])

    # ============================================================================
    # ECOMMERCE SYSTEM
    # ============================================================================
    
    # Categories
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :slug, :string, null: false
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])
    create index(:categories, [:is_active])

    # Products
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :sku, :string
      add :stock_quantity, :integer, default: 0
      add :is_active, :boolean, default: true
      add :image_url, :string
      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      add :weight, :decimal, precision: 8, scale: 2
      add :dimensions, :string
      add :image, :string
      add :stripe_price_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:sku])
    create index(:products, [:category_id])
    create index(:products, [:is_active])
    create index(:products, [:stripe_price_id])

    # Carts
    create table(:carts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:carts, [:user_id])

    # Cart Items
    create table(:cart_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false, default: 1
      add :cart_id, references(:carts, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cart_items, [:cart_id, :product_id])
    create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])

    # Orders
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "pending"
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_payment_intent_id, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:stripe_payment_intent_id])

    # Order Items
    create table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])

    # ============================================================================
    # FILE MANAGEMENT
    # ============================================================================
    
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

    # ============================================================================
    # CHAT SYSTEM
    # ============================================================================
    
    # Chat Channels
    create table(:chat_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :topic, :string
      add :channel_type, :string, default: "text"
      add :is_private, :boolean, default: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :position, :integer, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:chat_channels, [:channel_type])
    create index(:chat_channels, [:is_private])
    create index(:chat_channels, [:created_by_id])
    create index(:chat_channels, [:position])

    # Chat Threads (must be created before messages due to reference)
    create table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :is_archived, :boolean, default: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_threads, [:channel_id])
    create index(:chat_threads, [:is_archived])

    # Chat Messages
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :is_pinned, :boolean, default: false
      add :edited_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)
      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end
    
    create index(:chat_messages, [:thread_id])
    create index(:chat_messages, [:channel_id])
    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:message_type])
    create index(:chat_messages, [:is_pinned])
    create index(:chat_messages, [:reply_to_id])
    create index(:chat_messages, [:inserted_at])

    # Now add the parent_message_id to chat_threads
    alter table(:chat_threads) do
      add :parent_message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
    end

    create index(:chat_threads, [:parent_message_id])

    # Chat Message Attachments
    create table(:chat_message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string
      add :file_size, :integer
      add :file, :string, null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_message_attachments, [:message_id])

    # Chat Reactions
    create table(:chat_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_reactions, [:user_id, :message_id, :emoji])
    create index(:chat_reactions, [:message_id])

    # ============================================================================
    # CONTENT MANAGEMENT (POSTS & PAGES)
    # ============================================================================
    
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

    # ============================================================================
    # CMS POSTS SYSTEM (WordPress-style)
    # ============================================================================
    
    create table(:cms_posts) do
      add :title, :text, null: false, default: ""
      add :content, :text, null: false, default: ""
      add :excerpt, :text, null: false, default: ""
      add :status, :string, null: false, default: "draft"
      add :post_type, :string, null: false, default: "post"
      add :slug, :string, null: false, default: ""
      add :password, :string, null: false, default: ""
      add :comment_status, :string, null: false, default: "open"
      add :ping_status, :string, null: false, default: "open"
      add :menu_order, :integer, null: false, default: 0
      add :post_parent_id, references(:cms_posts, on_delete: :nilify_all)
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :guid, :string, null: false, default: ""
      add :comment_count, :integer, null: false, default: 0
      add :post_date, :naive_datetime
      add :post_date_gmt, :naive_datetime
      add :post_modified, :naive_datetime
      add :post_modified_gmt, :naive_datetime

      timestamps()
    end

    create index(:cms_posts, [:author_id])
    create index(:cms_posts, [:post_parent_id])
    create index(:cms_posts, [:status])
    create index(:cms_posts, [:post_type])
    create index(:cms_posts, [:slug])
    create index(:cms_posts, [:post_date])
    create unique_index(:cms_posts, [:slug, :post_type])

    create table(:cms_post_meta) do
      add :post_id, references(:cms_posts, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""

      timestamps()
    end

    create index(:cms_post_meta, [:post_id])
    create index(:cms_post_meta, [:meta_key])
    create index(:cms_post_meta, [:post_id, :meta_key])

    create table(:cms_post_term_relationships) do
      add :post_id, references(:cms_posts, on_delete: :delete_all), null: false
      add :term_id, references(:cms_terms, on_delete: :delete_all), null: false
      add :term_order, :integer, null: false, default: 0

      timestamps()
    end

    create index(:cms_post_term_relationships, [:post_id])
    create index(:cms_post_term_relationships, [:term_id])
    create unique_index(:cms_post_term_relationships, [:post_id, :term_id])

    # CMS Comments
    create table(:cms_comments) do
      add :post_id, references(:cms_posts, on_delete: :delete_all), null: false
      add :author_name, :string, null: false, default: ""
      add :author_email, :string, null: false, default: ""
      add :author_url, :string, null: false, default: ""
      add :author_ip, :string, null: false, default: ""
      add :content, :text, null: false, default: ""
      add :approved, :string, null: false, default: "1"
      add :agent, :string, null: false, default: ""
      add :type, :string, null: false, default: "comment"
      add :parent_id, references(:cms_comments, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :comment_date, :naive_datetime
      add :comment_date_gmt, :naive_datetime

      timestamps()
    end

    create index(:cms_comments, [:post_id])
    create index(:cms_comments, [:parent_id])
    create index(:cms_comments, [:user_id])
    create index(:cms_comments, [:approved])
    create index(:cms_comments, [:comment_date])
    create index(:cms_comments, [:type])

    create table(:cms_comment_meta) do
      add :comment_id, references(:cms_comments, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""

      timestamps()
    end

    create index(:cms_comment_meta, [:comment_id])
    create index(:cms_comment_meta, [:meta_key])
    create index(:cms_comment_meta, [:comment_id, :meta_key])
  end

  def down do
    # Drop tables in reverse order to avoid foreign key constraints
    drop_if_exists table(:cms_comment_meta)
    drop_if_exists table(:cms_comments)
    drop_if_exists table(:cms_post_term_relationships)
    drop_if_exists table(:cms_post_meta)
    drop_if_exists table(:cms_posts)
    drop_if_exists table(:comments)
    drop_if_exists table(:pages)
    drop_if_exists table(:posts)
    drop_if_exists table(:chat_reactions)
    drop_if_exists table(:chat_message_attachments)
    drop_if_exists table(:chat_messages)
    drop_if_exists table(:chat_threads)
    drop_if_exists table(:chat_channels)
    drop_if_exists table(:user_files)
    drop_if_exists table(:order_items)
    drop_if_exists table(:orders)
    drop_if_exists table(:cart_items)
    drop_if_exists table(:carts)
    drop_if_exists table(:products)
    drop_if_exists table(:categories)
    drop_if_exists table(:cms_term_meta)
    drop_if_exists table(:cms_terms)
    drop_if_exists table(:cms_taxonomies)
    drop_if_exists table(:users_tokens)
    drop_if_exists table(:users)
    drop_if_exists table(:cms_options)
  end
end