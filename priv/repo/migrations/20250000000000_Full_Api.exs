defmodule PhoenixApp.Repo.Migrations.FullApi do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
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
      add :name, :string  # Missing field from schema
      add :password_hash, :string, null: false
      add :confirmed_at, :utc_datetime
      add :is_online, :boolean, default: false
      add :is_admin, :boolean, default: true  # Set to true by default as per migration 003
      add :last_activity, :utc_datetime
      add :avatar_shape, :string, default: "circle"
      add :avatar_color, :string, default: "#3B82F6"
      add :avatar_file, :string
      add :avatar_url, :string
      add :status, :string, default: "active"
      add :role, :string, default: "subscriber"  # Missing field from schema
      add :two_factor_secret, :string
      add :two_factor_enabled, :boolean, default: false
      add :two_factor_backup_codes, {:array, :string}, default: []
      add :position_x, :float, default: 400.0
      add :position_y, :float, default: 300.0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:is_admin])
    create index(:users, [:two_factor_enabled])

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
      # Additional fields from migration 016
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
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)  # Fixed reference to users table with correct type
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
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)  # Fixed reference to users table with correct type
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

    # ============================================================================
    # EQEMU INTEGRATION SYSTEM
    # ============================================================================
    
    # EQEmu accounts (maps to Phoenix users)
    create table(:eqemu_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id), null: false
      add :eqemu_id, :integer, null: false  # Original account ID from PEQ
      add :name, :string, size: 30, null: false
      add :charname, :string, size: 64
      add :sharedplat, :integer, default: 0
      add :password, :string, size: 50
      add :status, :integer, default: 0
      add :ls_id, :string, size: 31
      add :lsaccount_id, :integer, default: 0
      add :gmspeed, :integer, default: 0
      add :revoked, :integer, default: 0
      add :karma, :integer, default: 0
      add :minilogin_ip, :string, size: 32
      add :hideme, :integer, default: 0
      add :rulesflag, :integer, default: 0
      add :suspendeduntil, :utc_datetime, default: fragment("now()")
      add :time_creation, :integer, default: 0
      add :expansion, :integer, default: 8

      timestamps()
    end

    create unique_index(:eqemu_accounts, [:eqemu_id])
    create unique_index(:eqemu_accounts, [:name])
    create unique_index(:eqemu_accounts, [:user_id])

    # Main character data table (based on PEQ character_data)
    create table(:eqemu_characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id), null: false
      
      # Original EQEmu fields
      add :eqemu_id, :integer, null: false  # Original character ID from PEQ
      add :account_id, :integer, null: false
      add :name, :string, size: 64, null: false
      add :last_name, :string, size: 64
      add :title, :string, size: 32
      add :suffix, :string, size: 32
      add :zone_id, :integer, default: 1
      add :zone_instance, :integer, default: 0
      add :y, :float, default: 0.0
      add :x, :float, default: 0.0
      add :z, :float, default: 0.0
      add :heading, :float, default: 0.0
      add :gender, :integer, default: 0
      add :race, :integer, default: 1
      add :class, :integer, default: 1
      add :level, :integer, default: 1
      add :deity, :integer, default: 396
      add :birthday, :integer, default: 0
      add :last_login, :integer, default: 0
      add :time_played, :integer, default: 0
      add :level2, :integer, default: 0
      add :anon, :integer, default: 0
      add :gm, :integer, default: 0
      add :face, :integer, default: 1
      add :hair_color, :integer, default: 1
      add :hair_style, :integer, default: 1
      add :beard, :integer, default: 0
      add :beard_color, :integer, default: 1
      add :eye_color_1, :integer, default: 1
      add :eye_color_2, :integer, default: 1
      add :drakkin_heritage, :integer, default: 0
      add :drakkin_tattoo, :integer, default: 0
      add :drakkin_details, :integer, default: 0
      
      # Stats
      add :hp, :integer, default: 100
      add :mana, :integer, default: 0
      add :endurance, :integer, default: 100
      add :intoxication, :integer, default: 0
      add :str, :integer, default: 75
      add :sta, :integer, default: 75
      add :cha, :integer, default: 75
      add :dex, :integer, default: 75
      add :int, :integer, default: 75
      add :agi, :integer, default: 75
      add :wis, :integer, default: 75
      
      # Currency
      add :platinum, :integer, default: 0
      add :gold, :integer, default: 0
      add :silver, :integer, default: 0
      add :copper, :integer, default: 0
      add :platinum_bank, :integer, default: 0
      add :gold_bank, :integer, default: 0
      add :silver_bank, :integer, default: 0
      add :copper_bank, :integer, default: 0
      add :platinum_cursor, :integer, default: 0
      add :gold_cursor, :integer, default: 0
      add :silver_cursor, :integer, default: 0
      add :copper_cursor, :integer, default: 0
      add :radiant_crystals, :integer, default: 0
      add :career_radiant_crystals, :integer, default: 0
      add :ebon_crystals, :integer, default: 0
      add :career_ebon_crystals, :integer, default: 0
      
      # Experience
      add :exp, :integer, default: 0
      add :exp_enabled, :integer, default: 1
      add :aa_points_spent, :integer, default: 0
      add :aa_exp, :integer, default: 0
      add :aa_points, :integer, default: 0
      add :group_leadership_exp, :integer, default: 0
      add :raid_leadership_exp, :integer, default: 0
      add :group_leadership_points, :integer, default: 0
      add :raid_leadership_points, :integer, default: 0
      
      # PvP and Karma
      add :pvp_status, :integer, default: 0
      add :pvp_kills, :integer, default: 0
      add :pvp_deaths, :integer, default: 0
      add :pvp_current_points, :integer, default: 0
      add :pvp_career_points, :integer, default: 0
      add :pvp_best_kill_streak, :integer, default: 0
      add :pvp_worst_death_streak, :integer, default: 0
      add :pvp_current_kill_streak, :integer, default: 0
      add :pvp2, :integer, default: 0
      add :pvp_type, :integer, default: 0
      add :show_helm, :integer, default: 1
      add :fatigue, :integer, default: 0
      
      # Tribute and other systems
      add :tribute_time_remaining, :integer, default: 0
      add :tribute_career_points, :integer, default: 0
      add :tribute_points, :integer, default: 0
      add :tribute_active, :integer, default: 0
      add :endurance_percent, :integer, default: 100
      add :grouping_disabled, :integer, default: 0
      add :raid_grouped, :integer, default: 0
      add :mailkey, :string, size: 16
      add :xtargets, :integer, default: 5
      add :firstlogon, :integer, default: 0
      add :e_aa_effects, :integer, default: 0
      add :e_percent_to_aa, :integer, default: 0
      add :e_expended_aa_spent, :integer, default: 0
      add :boatname, :string, size: 16
      add :boatid, :integer, default: 0
      
      # Timestamps
      timestamps()
    end

    create unique_index(:eqemu_characters, [:eqemu_id])
    create unique_index(:eqemu_characters, [:name])
    create index(:eqemu_characters, [:user_id])
    create index(:eqemu_characters, [:account_id])
    create index(:eqemu_characters, [:level])
    create index(:eqemu_characters, [:zone_id])
    create index(:eqemu_characters, [:race])
    create index(:eqemu_characters, [:class])

    # Items table (based on PEQ items) - truncated for brevity, keeping essential fields
    create table(:eqemu_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :eqemu_id, :integer, null: false  # Original item ID from PEQ
      add :minstatus, :integer, default: 0
      add :name, :string, size: 64, null: false
      add :aagi, :integer, default: 0
      add :ac, :integer, default: 0
      add :accuracy, :integer, default: 0
      add :acha, :integer, default: 0
      add :adex, :integer, default: 0
      add :aint, :integer, default: 0
      add :artifactflag, :integer, default: 0
      add :asta, :integer, default: 0
      add :astr, :integer, default: 0
      add :attack, :integer, default: 0
      add :augrestrict, :integer, default: 0
      add :augslot1type, :integer, default: 0
      add :augslot1visible, :integer, default: 0
      add :augslot2type, :integer, default: 0
      add :augslot2visible, :integer, default: 0
      add :augslot3type, :integer, default: 0
      add :augslot3visible, :integer, default: 0
      add :augslot4type, :integer, default: 0
      add :augslot4visible, :integer, default: 0
      add :augslot5type, :integer, default: 0
      add :augslot5visible, :integer, default: 0
      add :augslot6type, :integer, default: 0
      add :augslot6visible, :integer, default: 0
      add :augtype, :integer, default: 0
      add :avoidance, :integer, default: 0
      add :awis, :integer, default: 0
      add :bagsize, :integer, default: 0
      add :bagslots, :integer, default: 0
      add :bagtype, :integer, default: 0
      add :bagwr, :integer, default: 0
      add :banedmgamt, :integer, default: 0
      add :banedmgraceamt, :integer, default: 0
      add :banedmgbody, :integer, default: 0
      add :banedmgrace, :integer, default: 0
      add :bardtype, :integer, default: 0
      add :bardvalue, :integer, default: 0
      add :book, :integer, default: 0
      add :casttime, :integer, default: 0
      add :casttime_, :integer, default: 0
      add :charmfile, :string, size: 32
      add :charmfileid, :string, size: 32
      add :classes, :integer, default: 0
      add :color, :integer, default: 0
      add :combateffects, :string, size: 10
      add :extradmgskill, :integer, default: 0
      add :extradmgamt, :integer, default: 0
      add :price, :integer, default: 0
      add :cr, :integer, default: 0
      add :damage, :integer, default: 0
      add :damageshield, :integer, default: 0
      add :deity, :integer, default: 0
      add :delay, :integer, default: 0
      add :augdistiller, :integer, default: 0
      add :dotshielding, :integer, default: 0
      add :dr, :integer, default: 0
      add :clicktype, :integer, default: 0
      add :clicklevel2, :integer, default: 0
      add :elemdmgtype, :integer, default: 0
      add :elemdmgamt, :integer, default: 0
      add :endur, :integer, default: 0
      add :factionamt1, :integer, default: 0
      add :factionamt2, :integer, default: 0
      add :factionamt3, :integer, default: 0
      add :factionamt4, :integer, default: 0
      add :factionmod1, :integer, default: 0
      add :factionmod2, :integer, default: 0
      add :factionmod3, :integer, default: 0
      add :factionmod4, :integer, default: 0
      add :filename, :string, size: 32
      add :focuseffect, :integer, default: 0
      add :fr, :integer, default: 0
      add :fvnodrop, :integer, default: 0
      add :haste, :integer, default: 0
      add :clicklevel, :integer, default: 0
      add :hp, :integer, default: 0
      add :regen, :integer, default: 0
      add :icon, :integer, default: 0
      add :idfile, :string, size: 30
      add :itemclass, :integer, default: 0
      add :itemtype, :integer, default: 0
      add :ldonprice, :integer, default: 0
      add :ldontheme, :integer, default: 0
      add :ldonsold, :integer, default: 0
      add :light, :integer, default: 0
      add :lore, :string, size: 80
      add :loregroup, :integer, default: 0
      add :magic, :integer, default: 0
      add :mana, :integer, default: 0
      add :manaregen, :integer, default: 0
      add :enduranceregen, :integer, default: 0
      add :material, :integer, default: 0
      add :herosforgemodel, :integer, default: 0
      add :maxcharges, :integer, default: 0
      add :mr, :integer, default: 0
      add :nodrop, :integer, default: 0
      add :norent, :integer, default: 0
      add :pendingloreflag, :integer, default: 0
      add :pr, :integer, default: 0
      add :procrate, :integer, default: 0
      add :races, :integer, default: 0
      add :range, :integer, default: 0
      add :reclevel, :integer, default: 0
      add :recskill, :integer, default: 0
      add :reqlevel, :integer, default: 0
      add :sellrate, :float, default: 1.0
      add :shielding, :integer, default: 0
      add :size, :integer, default: 0
      add :skillmodtype, :integer, default: 0
      add :skillmodvalue, :integer, default: 0
      add :slots, :integer, default: 0
      add :clickeffect, :integer, default: 0
      add :spellshield, :integer, default: 0
      add :strikethrough, :integer, default: 0
      add :stunresist, :integer, default: 0
      add :summonedflag, :integer, default: 0
      add :tradeskills, :integer, default: 0
      add :favor, :integer, default: 0
      add :weight, :integer, default: 0
      add :updated, :utc_datetime, default: fragment("now()")
      add :comment, :text
      add :attuneable, :integer, default: 0
      add :nopet, :integer, default: 0
      add :stacksize, :integer, default: 0
      add :notransfer, :integer, default: 0
      add :stackable, :integer, default: 0
      add :proceffect, :integer, default: 0
      add :proctype, :integer, default: 0
      add :proclevel2, :integer, default: 0
      add :proclevel, :integer, default: 0
      add :worneffect, :integer, default: 0
      add :worntype, :integer, default: 0
      add :wornlevel2, :integer, default: 0
      add :wornlevel, :integer, default: 0
      add :focustype, :integer, default: 0
      add :focuslevel2, :integer, default: 0
      add :focuslevel, :integer, default: 0
      add :scrolleffect, :integer, default: 0
      add :scrolltype, :integer, default: 0
      add :scrolllevel2, :integer, default: 0
      add :scrolllevel, :integer, default: 0
      add :serialized, :utc_datetime
      add :verified, :utc_datetime
      add :serialization, :text
      add :source, :string, size: 20, default: "Unknown"
      add :lorefile, :string, size: 32
      add :svcorruption, :integer, default: 0
      add :skillmodmax, :integer, default: 0
      add :questitemflag, :integer, default: 0
      add :clickname, :string, size: 64
      add :procname, :string, size: 64
      add :wornname, :string, size: 64
      add :focusname, :string, size: 64
      add :scrollname, :string, size: 64
      add :dsmitigation, :integer, default: 0
      add :heroic_str, :integer, default: 0
      add :heroic_int, :integer, default: 0
      add :heroic_wis, :integer, default: 0
      add :heroic_agi, :integer, default: 0
      add :heroic_dex, :integer, default: 0
      add :heroic_sta, :integer, default: 0
      add :heroic_cha, :integer, default: 0
      add :heroic_pr, :integer, default: 0
      add :heroic_dr, :integer, default: 0
      add :heroic_fr, :integer, default: 0
      add :heroic_cr, :integer, default: 0
      add :heroic_mr, :integer, default: 0
      add :heroic_svcorrup, :integer, default: 0
      add :healamt, :integer, default: 0
      add :spelldmg, :integer, default: 0
      add :clairvoyance, :integer, default: 0
      add :backstabdmg, :integer, default: 0
      add :created, :string, size: 64
      add :elitematerial, :integer, default: 0
      add :ldonsellbackrate, :integer, default: 70
      add :scriptfileid, :integer, default: 0
      add :expendablearrow, :integer, default: 0
      add :powersourcecapacity, :integer, default: 0
      add :bardeffect, :integer, default: 0
      add :bardeffecttype, :integer, default: 0
      add :bardlevel2, :integer, default: 0
      add :bardlevel, :integer, default: 0
      add :bardname, :string, size: 64
      add :subtype, :integer, default: 0
      add :heirloom, :integer, default: 0
      add :placeable, :integer, default: 0
      add :epicitem, :integer, default: 0

      timestamps()
    end

    create unique_index(:eqemu_items, [:eqemu_id])
    create index(:eqemu_items, [:name])
    create index(:eqemu_items, [:itemtype])
    create index(:eqemu_items, [:classes])
    create index(:eqemu_items, [:races])
    create index(:eqemu_items, [:reqlevel])

    # Character inventory (simplified from PEQ character_inventory)
    create table(:eqemu_character_inventory, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character_id, references(:eqemu_characters, type: :binary_id), null: false
      add :item_id, references(:eqemu_items, type: :binary_id), null: false
      add :slot_id, :integer, null: false
      add :charges, :integer, default: 1
      add :color, :integer, default: 0
      add :augment_1, references(:eqemu_items, type: :binary_id)
      add :augment_2, references(:eqemu_items, type: :binary_id)
      add :augment_3, references(:eqemu_items, type: :binary_id)
      add :augment_4, references(:eqemu_items, type: :binary_id)
      add :augment_5, references(:eqemu_items, type: :binary_id)
      add :augment_6, references(:eqemu_items, type: :binary_id)
      add :instnodrop, :integer, default: 0
      add :custom_data, :text
      add :ornamenticon, :integer, default: 0
      add :ornamentidfile, :string, size: 32
      add :ornament_hero_model, :integer, default: 0

      timestamps()
    end

    create unique_index(:eqemu_character_inventory, [:character_id, :slot_id])
    create index(:eqemu_character_inventory, [:item_id])

    # Guilds table (based on PEQ guilds)
    create table(:eqemu_guilds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :eqemu_id, :integer, null: false  # Original guild ID from PEQ
      add :name, :string, size: 32, null: false
      add :leader, :integer, default: 0
      add :moto_of_the_day, :text
      add :channel, :string, size: 128
      add :url, :text
      add :favor, :integer, default: 0
      add :tribute, :integer, default: 0

      timestamps()
    end

    create unique_index(:eqemu_guilds, [:eqemu_id])
    create unique_index(:eqemu_guilds, [:name])

    # Guild members (based on PEQ guild_members)
    create table(:eqemu_guild_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :guild_id, references(:eqemu_guilds, type: :binary_id), null: false
      add :character_id, references(:eqemu_characters, type: :binary_id), null: false
      add :rank, :integer, default: 0
      add :tribute, :integer, default: 0
      add :last_tribute, :integer, default: 0
      add :banker, :integer, default: 0
      add :public_note, :text
      add :officer_note, :text
      add :total_tribute, :integer, default: 0
      add :last_tribute_time, :integer, default: 0

      timestamps()
    end

    create unique_index(:eqemu_guild_members, [:guild_id, :character_id])
    create index(:eqemu_guild_members, [:character_id])

    # Zones table (based on PEQ zone)
    create table(:eqemu_zones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :eqemu_id, :integer, null: false  # Original zone ID from PEQ
      add :short_name, :string, size: 32, null: false
      add :long_name, :text, null: false
      add :map_file_name, :string, size: 100
      add :safe_x, :float, default: 0.0
      add :safe_y, :float, default: 0.0
      add :safe_z, :float, default: 0.0
      add :safe_heading, :float, default: 0.0
      add :graveyard_id, :float, default: 0.0
      add :min_level, :integer, default: 1
      add :max_level, :integer, default: 255
      add :min_status, :integer, default: 0
      add :zoneidnumber, :integer, default: 0
      add :version, :integer, default: 0
      add :timezone, :integer, default: 0
      add :maxclients, :integer, default: 0
      add :ruleset, :integer, default: 0
      add :note, :string, size: 80
      add :underworld, :float, default: 0.0
      add :minclip, :float, default: 450.0
      add :maxclip, :float, default: 450.0
      add :fog_minclip, :float, default: 450.0
      add :fog_maxclip, :float, default: 450.0
      add :fog_blue, :integer, default: 0
      add :fog_red, :integer, default: 0
      add :fog_green, :integer, default: 0
      add :sky, :integer, default: 1
      add :ztype, :integer, default: 1
      add :zone_exp_multiplier, :decimal, default: 0.00
      add :walkspeed, :float, default: 0.4
      add :time_type, :integer, default: 2
      add :fog_red1, :integer, default: 0
      add :fog_green1, :integer, default: 0
      add :fog_blue1, :integer, default: 0
      add :fog_minclip1, :float, default: 450.0
      add :fog_maxclip1, :float, default: 450.0
      add :fog_red2, :integer, default: 0
      add :fog_green2, :integer, default: 0
      add :fog_blue2, :integer, default: 0
      add :fog_minclip2, :float, default: 450.0
      add :fog_maxclip2, :float, default: 450.0
      add :fog_red3, :integer, default: 0
      add :fog_green3, :integer, default: 0
      add :fog_blue3, :integer, default: 0
      add :fog_minclip3, :float, default: 450.0
      add :fog_maxclip3, :float, default: 450.0
      add :fog_red4, :integer, default: 0
      add :fog_green4, :integer, default: 0
      add :fog_blue4, :integer, default: 0
      add :fog_minclip4, :float, default: 450.0
      add :fog_maxclip4, :float, default: 450.0
      add :flag_needed, :string, size: 128
      add :canbind, :integer, default: 1
      add :cancombat, :integer, default: 1
      add :canlevitate, :integer, default: 1
      add :castoutdoor, :integer, default: 1
      add :hotzone, :integer, default: 0
      add :insttype, :integer, default: 0
      add :shutdowndelay, :bigint, default: 5000
      add :peqzone, :integer, default: 1
      add :expansion, :integer, default: 0
      add :suspendbuffs, :integer, default: 0
      add :rain_chance1, :integer, default: 0
      add :rain_chance2, :integer, default: 0
      add :rain_chance3, :integer, default: 0
      add :rain_chance4, :integer, default: 0
      add :rain_duration1, :integer, default: 0
      add :rain_duration2, :integer, default: 0
      add :rain_duration3, :integer, default: 0
      add :rain_duration4, :integer, default: 0
      add :snow_chance1, :integer, default: 0
      add :snow_chance2, :integer, default: 0
      add :snow_chance3, :integer, default: 0
      add :snow_chance4, :integer, default: 0
      add :snow_duration1, :integer, default: 0
      add :snow_duration2, :integer, default: 0
      add :snow_duration3, :integer, default: 0
      add :snow_duration4, :integer, default: 0
      add :gravity, :float, default: 0.4
      add :type, :integer, default: 0
      add :skylock, :integer, default: 0
      add :fast_regen_hp, :integer, default: 180
      add :fast_regen_mana, :integer, default: 180
      add :fast_regen_endurance, :integer, default: 180
      add :npc_max_aggro_dist, :integer, default: 600
      add :max_movement_update_range, :integer, default: 600

      timestamps()
    end

    create unique_index(:eqemu_zones, [:eqemu_id])
    create unique_index(:eqemu_zones, [:short_name])
    create index(:eqemu_zones, [:long_name])
    create index(:eqemu_zones, [:expansion])

    # ============================================================================
    # ADDITIONAL PERFORMANCE INDEXES
    # ============================================================================
    
    # Performance indexes for common queries
    create index(:eqemu_characters, [:zone_id, :level])
    create index(:eqemu_characters, [:race, :class])
    create index(:eqemu_characters, [:last_login])
    create index(:eqemu_items, [:itemtype, :reqlevel])
    create index(:eqemu_items, [:classes, :races])
    create index(:eqemu_character_inventory, [:character_id, :item_id])
    create index(:eqemu_zones, [:min_level, :max_level])
  end
end