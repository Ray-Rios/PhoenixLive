defmodule Phxlive.Store.Product do
  @moduledoc "Something for sale: a Gem pack now; subscription plans and items later."
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(gem_pack subscription_plan item)

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "store_products" do
    field :slug, :string
    field :kind, :string
    field :name, :string
    field :description, :string
    field :price_cents, :integer
    field :currency, :string, default: "usd"
    field :gems, :integer
    field :bonus_gems, :integer, default: 0
    field :promo_starts_at, :utc_datetime
    field :promo_ends_at, :utc_datetime
    field :badge, :string
    field :active, :boolean, default: true
    field :sort_order, :integer, default: 0
    field :stripe_price_id, :string
    field :paypal_plan_id, :string
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:slug, :kind, :name, :description, :price_cents, :currency, :gems, :bonus_gems,
                    :promo_starts_at, :promo_ends_at, :badge, :active, :sort_order, :stripe_price_id, :paypal_plan_id])
    |> validate_required([:slug, :kind, :name, :price_cents, :currency])
    |> validate_inclusion(:kind, @kinds)
    |> validate_format(:slug, ~r/\A[a-z0-9_]+\z/)
    |> validate_number(:price_cents, greater_than: 0)
    |> validate_number(:bonus_gems, greater_than_or_equal_to: 0)
    |> validate_gems()
    |> unique_constraint(:slug)
  end

  # A Gem pack sells Gems at the house rate (Phxlive.Store.gems_per_dollar/0):
  # its Gems are its price. Extra Gems are only ever a time-limited promotion.
  defp validate_gems(changeset) do
    if get_field(changeset, :kind) == "gem_pack" do
      changeset
      |> validate_required([:gems])
      |> validate_number(:gems, greater_than: 0)
      |> then(fn cs ->
        price = get_field(cs, :price_cents)
        gems = get_field(cs, :gems)

        if is_integer(price) and is_integer(gems) and gems * 100 != price * Phxlive.Store.gems_per_dollar(),
          do: add_error(cs, :gems, "must be the price at #{Phxlive.Store.gems_per_dollar()} Gems per dollar; use bonus Gems for a promotion"),
          else: cs
      end)
    else
      changeset
    end
  end
end
