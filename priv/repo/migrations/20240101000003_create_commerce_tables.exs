defmodule PhoenixApp.Repo.Migrations.CreateCommerceTables do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
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

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:sku])
    create index(:products, [:category_id])
    create index(:products, [:is_active])

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
  end
end