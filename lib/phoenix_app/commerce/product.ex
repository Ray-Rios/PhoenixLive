defmodule PhoenixApp.Commerce.Product do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  @product_types ~w(physical digital service subscription)
  @billing_intervals ~w(one_time monthly yearly lifetime)
  
  schema "products" do
    field :name, :string
    field :description, :string
    field :price, :decimal
    field :sku, :string
    field :stock_quantity, :integer
    field :is_active, :boolean, default: true
    field :weight, :decimal
    field :dimensions, :string
    field :image, PhoenixApp.ProductImage.Type
    field :stripe_price_id, :string
    field :stripe_product_id, :string
    
    # Product type and digital delivery
    field :product_type, :string, default: "physical"  # physical, digital, service, subscription
    field :download_url, :string  # For digital products
    field :download_limit, :integer  # Max downloads allowed (nil = unlimited)
    
    # Subscription/recurring billing
    field :billing_interval, :string, default: "one_time"  # one_time, monthly, yearly, lifetime
    field :trial_days, :integer, default: 0
    
    # Quota/benefit grants (for subscriptions that grant storage, etc.)
    field :grants_storage_bytes, :integer  # Extra storage in bytes this product grants
    field :grants_role, :string  # Role upgrade (e.g., "premium", "editor")
    field :grants_features, {:array, :string}, default: []  # Feature flags granted
    
    # Display
    field :featured, :boolean, default: false
    field :sort_order, :integer, default: 0
    field :badge_text, :string  # e.g., "Popular", "Best Value", "New"

    belongs_to :category, PhoenixApp.Commerce.Category
    has_many :order_items, PhoenixApp.Commerce.OrderItem
    has_many :cart_items, PhoenixApp.Commerce.CartItem

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name, :description, :price, :sku, :stock_quantity, :is_active, 
      :weight, :dimensions, :stripe_price_id, :stripe_product_id, :category_id,
      :product_type, :download_url, :download_limit,
      :billing_interval, :trial_days,
      :grants_storage_bytes, :grants_role, :grants_features,
      :featured, :sort_order, :badge_text
    ])
    |> cast_attachments(attrs, [:image])
    |> validate_required([:name, :price])
    |> validate_inclusion(:product_type, @product_types)
    |> validate_inclusion(:billing_interval, @billing_intervals)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:stock_quantity, greater_than_or_equal_to: 0)
    |> validate_number(:trial_days, greater_than_or_equal_to: 0)
    |> maybe_generate_sku()
    |> unique_constraint(:sku)
  end
  
  defp maybe_generate_sku(changeset) do
    case get_field(changeset, :sku) do
      nil ->
        # Auto-generate SKU from name if not provided
        name = get_field(changeset, :name) || ""
        prefix = name |> String.upcase() |> String.replace(~r/[^A-Z0-9]/, "") |> String.slice(0, 6)
        random = :crypto.strong_rand_bytes(3) |> Base.encode16()
        put_change(changeset, :sku, "#{prefix}-#{random}")
      "" ->
        name = get_field(changeset, :name) || ""
        prefix = name |> String.upcase() |> String.replace(~r/[^A-Z0-9]/, "") |> String.slice(0, 6)
        random = :crypto.strong_rand_bytes(3) |> Base.encode16()
        put_change(changeset, :sku, "#{prefix}-#{random}")
      _ ->
        changeset
    end
  end
  
  def product_types, do: @product_types
  def billing_intervals, do: @billing_intervals
end