defmodule PhoenixApp.Commerce.CartItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cart_items" do
    field :quantity, :integer

    belongs_to :cart, PhoenixApp.Commerce.Cart
    belongs_to :product, PhoenixApp.Commerce.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:quantity, :cart_id, :product_id])
    |> validate_required([:quantity])
    |> validate_number(:quantity, greater_than: 0)
  end
end