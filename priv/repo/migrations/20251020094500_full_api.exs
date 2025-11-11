defmodule PhoenixApp.Repo.Migrations.FullApiConsolidated do
  use Ecto.Migration
  @disable_ddl_transaction true

  @moduledoc """
  ============================================================================
  COMPLETE DATABASE SCHEMA - CONSOLIDATED MIGRATION
  ============================================================================
  """

  def up do
    # ============================================================================
    # CMS OPTIONS
    # ============================================================================
    
    create_if_not_exists table(:cms_options) do
      add :option_name, :string, null: false
      add :option_value, :text, null: false, default: ""
      add :autoload, :string, null: false, default: "yes"
      timestamps()
    end

    create_if_not_exists unique_index(:cms_options, [:option_name])
    create_if_not_exists index(:cms_options, [:autoload])

    # ============================================================================
    # USERS SYSTEM
    # ============================================================================
    
    create_if_not_exists table(:users, primary_key: false) do
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
      
      # Security & verification fields
      add :email_verified_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :password_reset_token, :string
      add :password_reset_sent_at, :utc_datetime
      add :approved_at, :utc_datetime
      add :approved_by_id, :binary_id  # Self-referencing FK, added below
      add :registration_ip, :string
      add :last_login_ip, :string
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Add self-referencing foreign key for approved_by_id with SET NULL on delete
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'users_approved_by_id_fkey'
      ) THEN
        ALTER TABLE users 
        ADD CONSTRAINT users_approved_by_id_fkey 
        FOREIGN KEY (approved_by_id) 
        REFERENCES users(id) 
        ON DELETE SET NULL;
      END IF;
    END $$;
    """

    create_if_not_exists unique_index(:users, [:email])
    create_if_not_exists index(:users, [:is_admin])
    create_if_not_exists index(:users, [:two_factor_enabled])
    create_if_not_exists index(:users, [:email_verification_token])
    create_if_not_exists index(:users, [:password_reset_token])
    create_if_not_exists index(:users, [:locked_until])
    create_if_not_exists index(:users, [:email_verified_at])

    # Handle duplicate usernames and create unique constraint
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

    create_if_not_exists unique_index(:users, [:name], name: :users_name_unique_index)

    # User tokens
    create_if_not_exists table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false, type: :utc_datetime)
    end

    create_if_not_exists index(:users_tokens, [:user_id])
    create_if_not_exists unique_index(:users_tokens, [:context, :token])

    # ============================================================================
    # SECURITY & TRACKING TABLES (from 20251012000001)
    # ============================================================================
    
    # Login attempts tracking
    create_if_not_exists table(:login_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :attempt_count, :integer, default: 0
      add :last_attempt_at, :utc_datetime
      add :ip_address, :string
      add :user_agent, :text
      add :successful, :boolean, default: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:login_attempts, [:identifier])
    create_if_not_exists index(:login_attempts, [:identifier_type])
    create_if_not_exists index(:login_attempts, [:ip_address])
    create_if_not_exists index(:login_attempts, [:last_attempt_at])
    create_if_not_exists index(:login_attempts, [:user_id])

    # Blocked identifiers (IP/fingerprint blocklist)
    create_if_not_exists table(:blocked_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :reason, :text
      add :blocked_at, :utc_datetime, null: false
      add :blocked_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :expires_at, :utc_datetime
      add :auto_blocked, :boolean, default: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:blocked_identifiers, [:identifier, :identifier_type])
    create_if_not_exists index(:blocked_identifiers, [:blocked_at])
    create_if_not_exists index(:blocked_identifiers, [:expires_at])
    create_if_not_exists index(:blocked_identifiers, [:auto_blocked])

    # Device fingerprints
    create_if_not_exists table(:device_fingerprints, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :fingerprint_hash, :string, null: false
      add :user_agent, :text
      add :platform, :string
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :trusted, :boolean, default: false
      add :metadata, :map
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:device_fingerprints, [:fingerprint_hash])
    create_if_not_exists index(:device_fingerprints, [:user_id])
    create_if_not_exists index(:device_fingerprints, [:first_seen_at])
    create_if_not_exists index(:device_fingerprints, [:last_seen_at])
    create_if_not_exists index(:device_fingerprints, [:trusted])

    # Behavioral analysis data
    create_if_not_exists table(:behavioral_data, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_id, :string
      add :device_fingerprint_id, references(:device_fingerprints, on_delete: :delete_all, type: :uuid)
      add :mouse_movements, :integer, default: 0
      add :keystrokes, :integer, default: 0
      add :form_focus_time, :integer
      add :time_to_submit, :integer
      add :seems_human, :boolean, default: false
      add :timestamp, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:behavioral_data, [:device_fingerprint_id])
    create_if_not_exists index(:behavioral_data, [:session_id])
    create_if_not_exists index(:behavioral_data, [:timestamp])
    create_if_not_exists index(:behavioral_data, [:seems_human])

    # Allowlist for trusted identifiers
    create_if_not_exists table(:allowed_identifiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :identifier, :string, null: false
      add :identifier_type, :string, null: false
      add :reason, :text
      add :added_at, :utc_datetime, null: false
      add :added_by_user_id, references(:users, on_delete: :nilify_all, type: :uuid)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:allowed_identifiers, [:identifier, :identifier_type])
    create_if_not_exists index(:allowed_identifiers, [:added_at])

    # ============================================================================
    # CMS TAXONOMIES AND TERMS
    # ============================================================================
    
    create_if_not_exists table(:cms_taxonomies) do
      add :name, :string, null: false
      add :label, :string, null: false
      add :description, :text, null: false, default: ""
      add :hierarchical, :boolean, null: false, default: false
      add :public, :boolean, null: false, default: true
      add :object_type, {:array, :string}, null: false, default: []
      timestamps()
    end

    create_if_not_exists unique_index(:cms_taxonomies, [:name])
    create_if_not_exists index(:cms_taxonomies, [:hierarchical])
    create_if_not_exists index(:cms_taxonomies, [:public])

    create_if_not_exists table(:cms_terms) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text, null: false, default: ""
      add :count, :integer, null: false, default: 0
      add :parent_id, references(:cms_terms, on_delete: :nilify_all)
      add :taxonomy_id, references(:cms_taxonomies, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:cms_terms, [:taxonomy_id])
    create_if_not_exists index(:cms_terms, [:parent_id])
    create_if_not_exists index(:cms_terms, [:slug])
    create_if_not_exists unique_index(:cms_terms, [:slug, :taxonomy_id])

    create_if_not_exists table(:cms_term_meta) do
      add :term_id, references(:cms_terms, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""
      timestamps()
    end

    create_if_not_exists index(:cms_term_meta, [:term_id])
    create_if_not_exists index(:cms_term_meta, [:meta_key])
    create_if_not_exists index(:cms_term_meta, [:term_id, :meta_key])

    # ============================================================================
    # ECOMMERCE SYSTEM
    # ============================================================================
    
    # Categories
    create_if_not_exists table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :slug, :string, null: false
      add :is_active, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:categories, [:slug])
    create_if_not_exists index(:categories, [:is_active])

    # Products
    create_if_not_exists table(:products, primary_key: false) do
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

    create_if_not_exists unique_index(:products, [:sku])
    create_if_not_exists index(:products, [:category_id])
    create_if_not_exists index(:products, [:is_active])
    create_if_not_exists index(:products, [:stripe_price_id])

    # Carts
    create_if_not_exists table(:carts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:carts, [:user_id])

    # Cart Items
    create_if_not_exists table(:cart_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false, default: 1
      add :cart_id, references(:carts, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:cart_items, [:cart_id, :product_id])
    create_if_not_exists index(:cart_items, [:cart_id])
    create_if_not_exists index(:cart_items, [:product_id])

    # Orders
    create_if_not_exists table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "pending"
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_payment_intent_id, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:orders, [:user_id])
    create_if_not_exists index(:orders, [:status])
    create_if_not_exists index(:orders, [:stripe_payment_intent_id])

    # Order Items
    create_if_not_exists table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:order_items, [:order_id])
    create_if_not_exists index(:order_items, [:product_id])

    # ============================================================================
    # FILE MANAGEMENT
    # ============================================================================
    
    # User Files (legacy system - consider migrating to user_media)
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

    # ============================================================================
    # CHAT SYSTEM
    # ============================================================================
    
    # Chat Channels
    create_if_not_exists table(:chat_channels, primary_key: false) do
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

    create_if_not_exists index(:chat_channels, [:channel_type])
    create_if_not_exists index(:chat_channels, [:is_private])
    create_if_not_exists index(:chat_channels, [:created_by_id])
    create_if_not_exists index(:chat_channels, [:position])

    # Chat Threads (must be created before messages due to reference)
    create_if_not_exists table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :is_archived, :boolean, default: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:chat_threads, [:channel_id])
    create_if_not_exists index(:chat_threads, [:is_archived])

    # Chat Messages
    create_if_not_exists table(:chat_messages, primary_key: false) do
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
    
    create_if_not_exists index(:chat_messages, [:thread_id])
    create_if_not_exists index(:chat_messages, [:channel_id])
    create_if_not_exists index(:chat_messages, [:user_id])
    create_if_not_exists index(:chat_messages, [:message_type])
    create_if_not_exists index(:chat_messages, [:is_pinned])
    create_if_not_exists index(:chat_messages, [:reply_to_id])
    create_if_not_exists index(:chat_messages, [:inserted_at])

    # Add parent_message_id to chat_threads (circular reference handled after messages table exists)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_threads' AND column_name = 'parent_message_id'
      ) THEN
        ALTER TABLE chat_threads 
        ADD COLUMN parent_message_id uuid REFERENCES chat_messages(id) ON DELETE CASCADE;
      END IF;
    END $$;
    """, ""

    create_if_not_exists index(:chat_threads, [:parent_message_id])

    # Chat Message Attachments
    create_if_not_exists table(:chat_message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string
      add :file_size, :integer
      add :file, :string, null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:chat_message_attachments, [:message_id])

    # Chat Reactions
    create_if_not_exists table(:chat_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:chat_reactions, [:user_id, :message_id, :emoji])
    create_if_not_exists index(:chat_reactions, [:message_id])

    # ============================================================================
    # CONTENT MANAGEMENT (POSTS & PAGES)
    # ============================================================================
    
    # Posts (modern blog system)
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
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:posts, [:slug])
    create_if_not_exists index(:posts, [:user_id])
    create_if_not_exists index(:posts, [:is_published])
    create_if_not_exists index(:posts, [:published_at])
    create_if_not_exists index(:posts, [:tags])

    # Pages
    create_if_not_exists table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :is_published, :boolean, default: false
      add :meta_description, :string
      add :template, :string, default: "default"
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:pages, [:slug])
    create_if_not_exists index(:pages, [:is_published])

    # Comments (for posts)
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
    # CMS POSTS SYSTEM (WordPress-style legacy)
    # ============================================================================
    
    create_if_not_exists table(:cms_posts) do
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

    create_if_not_exists index(:cms_posts, [:author_id])
    create_if_not_exists index(:cms_posts, [:post_parent_id])
    create_if_not_exists index(:cms_posts, [:status])
    create_if_not_exists index(:cms_posts, [:post_type])
    create_if_not_exists index(:cms_posts, [:slug])
    create_if_not_exists index(:cms_posts, [:post_date])
    create_if_not_exists unique_index(:cms_posts, [:slug, :post_type])

    create_if_not_exists table(:cms_post_meta) do
      add :post_id, references(:cms_posts, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""
      timestamps()
    end

    create_if_not_exists index(:cms_post_meta, [:post_id])
    create_if_not_exists index(:cms_post_meta, [:meta_key])
    create_if_not_exists index(:cms_post_meta, [:post_id, :meta_key])

    create_if_not_exists table(:cms_post_term_relationships) do
      add :post_id, references(:cms_posts, on_delete: :delete_all), null: false
      add :term_id, references(:cms_terms, on_delete: :delete_all), null: false
      add :term_order, :integer, null: false, default: 0
      timestamps()
    end

    create_if_not_exists index(:cms_post_term_relationships, [:post_id])
    create_if_not_exists index(:cms_post_term_relationships, [:term_id])
    create_if_not_exists unique_index(:cms_post_term_relationships, [:post_id, :term_id])

    # CMS Comments
    create_if_not_exists table(:cms_comments) do
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

    create_if_not_exists index(:cms_comments, [:post_id])
    create_if_not_exists index(:cms_comments, [:parent_id])
    create_if_not_exists index(:cms_comments, [:user_id])
    create_if_not_exists index(:cms_comments, [:approved])
    create_if_not_exists index(:cms_comments, [:comment_date])
    create_if_not_exists index(:cms_comments, [:type])

    create_if_not_exists table(:cms_comment_meta) do
      add :comment_id, references(:cms_comments, on_delete: :delete_all), null: false
      add :meta_key, :string, null: false, default: ""
      add :meta_value, :text, null: false, default: ""
      timestamps()
    end

    create_if_not_exists index(:cms_comment_meta, [:comment_id])
    create_if_not_exists index(:cms_comment_meta, [:meta_key])
    create_if_not_exists index(:cms_comment_meta, [:comment_id, :meta_key])

    # ============================================================================
    # MEDIA MANAGEMENT SYSTEM (NEW - WordPress-like media library)
    # ============================================================================
    
    # User media table - stores uploaded assets (images, video, audio, 3d models, documents)
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
      add :width, :integer  # For images/video
      add :height, :integer  # For images/video
      add :duration, :integer  # For video/audio (seconds)
      add :metadata, :map  # JSONB for thumbnails, EXIF, etc.
      add :usage_context, :string  # blog_featured, profile, product, etc.
      add :is_public, :boolean, default: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:user_media, [:user_id])
    create_if_not_exists index(:user_media, [:file_type])
    create_if_not_exists index(:user_media, [:usage_context])
    create_if_not_exists index(:user_media, [:inserted_at])

    # Media tags for organization
    create_if_not_exists table(:media_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_media_id, references(:user_media, type: :binary_id, on_delete: :delete_all), null: false
      add :tag, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:media_tags, [:user_media_id])
    create_if_not_exists index(:media_tags, [:tag])

    # Link table for posts -> media (many-to-many usage tracking)
    create_if_not_exists table(:post_media, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :media_id, references(:user_media, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "inline"  # inline, featured, gallery, cover
      add :order, :integer, default: 0  # Display order for galleries
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:post_media, [:post_id])
    create_if_not_exists index(:post_media, [:media_id])
    create_if_not_exists index(:post_media, [:role])
  end

  def down do
    # Drop tables in reverse order to handle foreign key dependencies
    drop_if_exists table(:post_media)
    drop_if_exists table(:media_tags)
    drop_if_exists table(:user_media)
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
    drop_if_exists table(:allowed_identifiers)
    drop_if_exists table(:behavioral_data)
    drop_if_exists table(:device_fingerprints)
    drop_if_exists table(:blocked_identifiers)
    drop_if_exists table(:login_attempts)
    drop_if_exists table(:users_tokens)
    
    # Drop the foreign key constraint before dropping users table
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_approved_by_id_fkey"
    
    drop_if_exists table(:users)
    drop_if_exists table(:cms_options)
  end
end
