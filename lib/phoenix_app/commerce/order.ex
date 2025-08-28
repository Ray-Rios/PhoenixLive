defmodule PhoenixApp.Commerce.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orders" do
    field :status, :string, default: "pending"
    field :total_amount, :decimal
    field :stripe_payment_intent_id, :string
    field :billing_address, :map
    field :shipping_address, :map
    field :notes, :string

    belongs_to :user, PhoenixApp.Accounts.User
    has_many :order_items, PhoenixApp.Commerce.OrderItem

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :total_amount, :stripe_payment_intent_id, :billing_address, :shipping_address, :notes])
    |> validate_required([:status, :total_amount])
    |> validate_inclusion(:status, ["pending", "processing", "shipped", "delivered", "cancelled"])
  end
end