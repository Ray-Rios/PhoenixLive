defmodule Phxlive.Store.Order do
  @moduledoc """
  One purchase. Status moves only through `Phxlive.Store`:

      awaiting_payment -> paid -> fulfilled
                       -> failed | cancelled
      fulfilled -> disputed -> fulfilled (won) | charged_back (lost)

  There is no refunded state: sales are final (PHXLIVE.md §2).
  """
  use Ecto.Schema

  @statuses ~w(awaiting_payment paid fulfilled failed cancelled disputed charged_back)
  def statuses, do: @statuses

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "store_orders" do
    field :status, :string
    field :provider, :string
    field :provider_ref, :string
    field :product_name, :string
    field :amount_cents, :integer
    field :currency, :string
    field :gems, :integer, default: 0
    field :terms_accepted_at, :utc_datetime_usec
    field :paid_at, :utc_datetime_usec
    field :fulfilled_at, :utc_datetime_usec
    field :failure_reason, :string
    belongs_to :user, Phxlive.Accounts.User
    belongs_to :product, Phxlive.Store.Product
    timestamps(type: :utc_datetime_usec)
  end
end
