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
