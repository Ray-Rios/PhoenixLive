defmodule PhoenixApp.Commerce.Product do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
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

    belongs_to :category, PhoenixApp.Commerce.Category
    has_many :order_items, PhoenixApp.Commerce.OrderItem
    has_many :cart_items, PhoenixApp.Commerce.CartItem

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :price, :sku, :stock_quantity, :is_active, :weight, :dimensions, :stripe_price_id, :category_id])
    |> cast_attachments(attrs, [:image])
    |> validate_required([:name, :price, :sku])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:stock_quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end
end