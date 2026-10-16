defmodule Phxlive.Commerce.Cart do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "carts" do
    belongs_to :user, Phxlive.Accounts.User
    has_many :cart_items, Phxlive.Commerce.CartItem

    timestamps(type: :utc_datetime)
  end

  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
  end
end