defmodule PhoenixApp.Repo.Migrations.Commerce do
  @moduledoc """
  ============================================================================
  COMMERCE TABLES
  ============================================================================
  Categories, products, carts, orders, subscriptions, and download tokens
  for digital goods and recurring billing.
  """
  use Ecto.Migration

  def change do
    execute """
    DO $$
    BEGIN
      -- CATEGORIES
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'categories') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'categories' AND column_name = 'parent_id') THEN
          ALTER TABLE categories ADD COLUMN parent_id uuid REFERENCES categories(id) ON DELETE SET NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'categories' AND column_name = 'position') THEN
          ALTER TABLE categories ADD COLUMN position integer DEFAULT 0;
        END IF;
      END IF;

      -- PRODUCTS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'name') THEN
          ALTER TABLE products ADD COLUMN name text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'slug') THEN
          ALTER TABLE products ADD COLUMN slug text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'description') THEN
          ALTER TABLE products ADD COLUMN description text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'price') THEN
          ALTER TABLE products ADD COLUMN price numeric(10,2) NOT NULL DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'original_price') THEN
          ALTER TABLE products ADD COLUMN original_price numeric(10,2);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'currency') THEN
          ALTER TABLE products ADD COLUMN currency text DEFAULT 'USD';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'sku') THEN
          ALTER TABLE products ADD COLUMN sku text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'stock') THEN
          ALTER TABLE products ADD COLUMN stock integer DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'product_type') THEN
          ALTER TABLE products ADD COLUMN product_type text DEFAULT 'physical';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'download_url') THEN
          ALTER TABLE products ADD COLUMN download_url text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'download_limit') THEN
          ALTER TABLE products ADD COLUMN download_limit integer;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'download_expires_after_days') THEN
          ALTER TABLE products ADD COLUMN download_expires_after_days integer;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'file_size_bytes') THEN
          ALTER TABLE products ADD COLUMN file_size_bytes bigint;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'file_name') THEN
          ALTER TABLE products ADD COLUMN file_name text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'billing_interval') THEN
          ALTER TABLE products ADD COLUMN billing_interval text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'trial_days') THEN
          ALTER TABLE products ADD COLUMN trial_days integer DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'stripe_product_id') THEN
          ALTER TABLE products ADD COLUMN stripe_product_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'stripe_price_id') THEN
          ALTER TABLE products ADD COLUMN stripe_price_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'grants_storage_bytes') THEN
          ALTER TABLE products ADD COLUMN grants_storage_bytes bigint;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'grants_premium_features') THEN
          ALTER TABLE products ADD COLUMN grants_premium_features boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'feature_flags') THEN
          ALTER TABLE products ADD COLUMN feature_flags jsonb DEFAULT '{}';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'category_id') THEN
          ALTER TABLE products ADD COLUMN category_id uuid REFERENCES categories(id) ON DELETE SET NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'position') THEN
          ALTER TABLE products ADD COLUMN position integer DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_active') THEN
          ALTER TABLE products ADD COLUMN is_active boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_featured') THEN
          ALTER TABLE products ADD COLUMN is_featured boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_digital') THEN
          ALTER TABLE products ADD COLUMN is_digital boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'main_image') THEN
          ALTER TABLE products ADD COLUMN main_image text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'images') THEN
          ALTER TABLE products ADD COLUMN images text[] DEFAULT '{}';
        END IF;
        
        -- Fix empty slugs to prevent unique index violation
        UPDATE products SET slug = id::text WHERE slug = '';
      END IF;

      -- CARTS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'carts') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carts' AND column_name = 'user_id') THEN
          ALTER TABLE carts ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carts' AND column_name = 'status') THEN
          ALTER TABLE carts ADD COLUMN status text DEFAULT 'active';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carts' AND column_name = 'session_id') THEN
          ALTER TABLE carts ADD COLUMN session_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carts' AND column_name = 'guest_email') THEN
          ALTER TABLE carts ADD COLUMN guest_email text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carts' AND column_name = 'guest_name') THEN
          ALTER TABLE carts ADD COLUMN guest_name text;
        END IF;
      END IF;

      -- CART ITEMS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cart_items') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'cart_id') THEN
          ALTER TABLE cart_items ADD COLUMN cart_id uuid REFERENCES carts(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'product_id') THEN
          ALTER TABLE cart_items ADD COLUMN product_id uuid REFERENCES products(id) ON DELETE CASCADE;
        END IF;
      END IF;

      -- ORDERS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'order_number') THEN
          ALTER TABLE orders ADD COLUMN order_number text NOT NULL DEFAULT '';
        END IF;
        
        -- Fix empty order_numbers
        UPDATE orders SET order_number = id::text WHERE order_number = '';

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'user_id') THEN
          ALTER TABLE orders ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE SET NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'status') THEN
          ALTER TABLE orders ADD COLUMN status text DEFAULT 'pending';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
          ALTER TABLE orders ADD COLUMN payment_status text DEFAULT 'pending';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'fulfillment_status') THEN
          ALTER TABLE orders ADD COLUMN fulfillment_status text DEFAULT 'unfulfilled';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'total') THEN
          ALTER TABLE orders ADD COLUMN total numeric(10,2) NOT NULL DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'subtotal') THEN
          ALTER TABLE orders ADD COLUMN subtotal numeric(10,2);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'tax') THEN
          ALTER TABLE orders ADD COLUMN tax numeric(10,2) DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'discount') THEN
          ALTER TABLE orders ADD COLUMN discount numeric(10,2) DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'currency') THEN
          ALTER TABLE orders ADD COLUMN currency text DEFAULT 'USD';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_method') THEN
          ALTER TABLE orders ADD COLUMN payment_method text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_intent_id') THEN
          ALTER TABLE orders ADD COLUMN payment_intent_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'stripe_session_id') THEN
          ALTER TABLE orders ADD COLUMN stripe_session_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'notes') THEN
          ALTER TABLE orders ADD COLUMN notes text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'shipping_address') THEN
          ALTER TABLE orders ADD COLUMN shipping_address jsonb;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'billing_address') THEN
          ALTER TABLE orders ADD COLUMN billing_address jsonb;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'guest_email') THEN
          ALTER TABLE orders ADD COLUMN guest_email text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'guest_name') THEN
          ALTER TABLE orders ADD COLUMN guest_name text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'metadata') THEN
          ALTER TABLE orders ADD COLUMN metadata jsonb DEFAULT '{}';
        END IF;
      END IF;

      -- ORDER ITEMS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'order_id') THEN
          ALTER TABLE order_items ADD COLUMN order_id uuid REFERENCES orders(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'product_id') THEN
          ALTER TABLE order_items ADD COLUMN product_id uuid REFERENCES products(id) ON DELETE SET NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'quantity') THEN
          ALTER TABLE order_items ADD COLUMN quantity integer DEFAULT 1 NOT NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'price') THEN
          ALTER TABLE order_items ADD COLUMN price numeric(10,2) NOT NULL DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'total') THEN
          ALTER TABLE order_items ADD COLUMN total numeric(10,2) NOT NULL DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'product_name') THEN
          ALTER TABLE order_items ADD COLUMN product_name text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'product_sku') THEN
          ALTER TABLE order_items ADD COLUMN product_sku text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'is_digital') THEN
          ALTER TABLE order_items ADD COLUMN is_digital boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'order_items' AND column_name = 'download_granted') THEN
          ALTER TABLE order_items ADD COLUMN download_granted boolean DEFAULT false;
        END IF;
      END IF;

      -- SUBSCRIPTIONS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'user_id') THEN
          ALTER TABLE subscriptions ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'product_id') THEN
          ALTER TABLE subscriptions ADD COLUMN product_id uuid REFERENCES products(id) ON DELETE RESTRICT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'status') THEN
          ALTER TABLE subscriptions ADD COLUMN status text DEFAULT 'active';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'stripe_subscription_id') THEN
          ALTER TABLE subscriptions ADD COLUMN stripe_subscription_id text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'current_period_start') THEN
          ALTER TABLE subscriptions ADD COLUMN current_period_start timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'current_period_end') THEN
          ALTER TABLE subscriptions ADD COLUMN current_period_end timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'cancel_at_period_end') THEN
          ALTER TABLE subscriptions ADD COLUMN cancel_at_period_end boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'canceled_at') THEN
          ALTER TABLE subscriptions ADD COLUMN canceled_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'ended_at') THEN
          ALTER TABLE subscriptions ADD COLUMN ended_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'trial_start') THEN
          ALTER TABLE subscriptions ADD COLUMN trial_start timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'trial_end') THEN
          ALTER TABLE subscriptions ADD COLUMN trial_end timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'metadata') THEN
          ALTER TABLE subscriptions ADD COLUMN metadata jsonb DEFAULT '{}';
        END IF;
      END IF;

      -- DOWNLOAD TOKENS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'download_tokens') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'user_id') THEN
          ALTER TABLE download_tokens ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'product_id') THEN
          ALTER TABLE download_tokens ADD COLUMN product_id uuid REFERENCES products(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'order_id') THEN
          ALTER TABLE download_tokens ADD COLUMN order_id uuid REFERENCES orders(id) ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'token') THEN
          ALTER TABLE download_tokens ADD COLUMN token text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'download_count') THEN
          ALTER TABLE download_tokens ADD COLUMN download_count integer DEFAULT 0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'max_downloads') THEN
          ALTER TABLE download_tokens ADD COLUMN max_downloads integer;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'expires_at') THEN
          ALTER TABLE download_tokens ADD COLUMN expires_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'first_downloaded_at') THEN
          ALTER TABLE download_tokens ADD COLUMN first_downloaded_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'last_downloaded_at') THEN
          ALTER TABLE download_tokens ADD COLUMN last_downloaded_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'download_tokens' AND column_name = 'ip_address') THEN
          ALTER TABLE download_tokens ADD COLUMN ip_address text;
        END IF;
      END IF;

    END $$;
    """, ""

    # ============================================================================
    # CATEGORIES
    # ============================================================================

    create_if_not_exists table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :image, :string
      add :position, :integer, default: 0
      add :parent_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create_if_not_exists unique_index(:categories, [:slug])
    create_if_not_exists index(:categories, [:parent_id])
    create_if_not_exists index(:categories, [:position])

    # ============================================================================
    # PRODUCTS
    # ============================================================================

    create_if_not_exists table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :original_price, :decimal, precision: 10, scale: 2
      add :currency, :string, default: "USD"
      add :sku, :string
      add :stock, :integer, default: 0
      add :is_active, :boolean, default: true
      add :is_featured, :boolean, default: false
      add :is_digital, :boolean, default: false
      add :position, :integer, default: 0
      add :main_image, :string
      add :images, {:array, :string}, default: []

      # Digital product fields
      add :product_type, :string, default: "physical"  # physical, digital, subscription
      add :download_url, :string
      add :download_limit, :integer
      add :download_expires_after_days, :integer
      add :file_size_bytes, :bigint
      add :file_name, :string

      # Subscription fields
      add :billing_interval, :string  # monthly, yearly, one_time
      add :trial_days, :integer, default: 0
      add :stripe_product_id, :string
      add :stripe_price_id, :string

      # Feature grants for subscriptions
      add :grants_storage_bytes, :bigint
      add :grants_premium_features, :boolean, default: false
      add :feature_flags, :map, default: %{}

      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create_if_not_exists unique_index(:products, [:slug])
    create_if_not_exists unique_index(:products, [:sku], where: "sku IS NOT NULL")
    create_if_not_exists index(:products, [:category_id])
    create_if_not_exists index(:products, [:is_active])
    create_if_not_exists index(:products, [:is_featured])
    create_if_not_exists index(:products, [:is_digital])
    create_if_not_exists index(:products, [:position])
    create_if_not_exists index(:products, [:product_type])
    create_if_not_exists index(:products, [:billing_interval])
    create_if_not_exists index(:products, [:stripe_product_id])
    create_if_not_exists index(:products, [:stripe_price_id])

    # ============================================================================
    # CARTS
    # ============================================================================

    create_if_not_exists table(:carts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "active"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :session_id, :string
      add :guest_email, :string
      add :guest_name, :string
      timestamps()
    end

    create_if_not_exists index(:carts, [:user_id])
    create_if_not_exists index(:carts, [:session_id])
    create_if_not_exists index(:carts, [:status])

    # ============================================================================
    # CART ITEMS
    # ============================================================================

    create_if_not_exists table(:cart_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, default: 1
      add :price_at_add, :decimal, precision: 10, scale: 2
      add :cart_id, references(:carts, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:cart_items, [:cart_id])
    create_if_not_exists index(:cart_items, [:product_id])
    create_if_not_exists unique_index(:cart_items, [:cart_id, :product_id])

    # ============================================================================
    # ORDERS
    # ============================================================================

    create_if_not_exists table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_number, :string, null: false
      add :status, :string, default: "pending"
      add :payment_status, :string, default: "pending"
      add :fulfillment_status, :string, default: "unfulfilled"
      add :total, :decimal, precision: 10, scale: 2, null: false
      add :subtotal, :decimal, precision: 10, scale: 2
      add :tax, :decimal, precision: 10, scale: 2, default: 0
      add :discount, :decimal, precision: 10, scale: 2, default: 0
      add :currency, :string, default: "USD"
      add :payment_method, :string
      add :payment_intent_id, :string
      add :stripe_session_id, :string
      add :notes, :text
      add :shipping_address, :map
      add :billing_address, :map
      add :guest_email, :string
      add :guest_name, :string
      add :metadata, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create_if_not_exists unique_index(:orders, [:order_number])
    create_if_not_exists unique_index(:orders, [:stripe_session_id], where: "stripe_session_id IS NOT NULL")
    create_if_not_exists index(:orders, [:user_id])
    create_if_not_exists index(:orders, [:status])
    create_if_not_exists index(:orders, [:payment_status])
    create_if_not_exists index(:orders, [:fulfillment_status])
    create_if_not_exists index(:orders, [:payment_intent_id])
    create_if_not_exists index(:orders, [:inserted_at])

    # ============================================================================
    # ORDER ITEMS
    # ============================================================================

    create_if_not_exists table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, default: 1, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :total, :decimal, precision: 10, scale: 2, null: false
      add :product_name, :string, null: false
      add :product_sku, :string
      add :is_digital, :boolean, default: false
      add :download_granted, :boolean, default: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create_if_not_exists index(:order_items, [:order_id])
    create_if_not_exists index(:order_items, [:product_id])
    create_if_not_exists index(:order_items, [:is_digital])
    create_if_not_exists index(:order_items, [:download_granted])

    # ============================================================================
    # SUBSCRIPTIONS
    # ============================================================================

    create_if_not_exists table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "active"
      add :stripe_subscription_id, :string
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false
      add :canceled_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :trial_start, :utc_datetime
      add :trial_end, :utc_datetime
      add :metadata, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:subscriptions, [:stripe_subscription_id], where: "stripe_subscription_id IS NOT NULL")
    create_if_not_exists index(:subscriptions, [:user_id])
    create_if_not_exists index(:subscriptions, [:product_id])
    create_if_not_exists index(:subscriptions, [:status])
    create_if_not_exists index(:subscriptions, [:current_period_end])
    create_if_not_exists index(:subscriptions, [:user_id, :status])

    # ============================================================================
    # DOWNLOAD TOKENS (for digital product delivery)
    # ============================================================================

    create_if_not_exists table(:download_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :download_count, :integer, default: 0
      add :max_downloads, :integer
      add :expires_at, :utc_datetime
      add :first_downloaded_at, :utc_datetime
      add :last_downloaded_at, :utc_datetime
      add :ip_address, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:download_tokens, [:token])
    create_if_not_exists index(:download_tokens, [:user_id])
    create_if_not_exists index(:download_tokens, [:product_id])
    create_if_not_exists index(:download_tokens, [:order_id])
    create_if_not_exists index(:download_tokens, [:expires_at])
    create_if_not_exists index(:download_tokens, [:user_id, :product_id])
  end
end
