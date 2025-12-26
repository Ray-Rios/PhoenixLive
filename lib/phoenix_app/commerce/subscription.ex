defmodule PhoenixApp.Commerce.Subscription do
  @moduledoc """
  User subscription/membership records.
  Tracks active subscriptions and their benefits.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  @statuses ~w(active paused cancelled expired trial)
  
  schema "subscriptions" do
    field :status, :string, default: "active"
    field :starts_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :trial_ends_at, :utc_datetime
    
    # Stripe integration
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    
    # Cached benefits (denormalized from product for quick access)
    field :storage_bytes_granted, :integer, default: 0
    field :role_granted, :string
    field :features_granted, {:array, :string}, default: []
    
    # Billing info
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false

    belongs_to :user, PhoenixApp.Accounts.User
    belongs_to :product, PhoenixApp.Commerce.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :status, :starts_at, :expires_at, :cancelled_at, :trial_ends_at,
      :stripe_subscription_id, :stripe_customer_id,
      :storage_bytes_granted, :role_granted, :features_granted,
      :current_period_start, :current_period_end, :cancel_at_period_end,
      :user_id, :product_id
    ])
    |> validate_required([:user_id, :product_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:product_id)
  end
  
  def statuses, do: @statuses
  
  @doc """
  Returns true if the subscription is currently active and valid.
  """
  def active?(%__MODULE__{} = sub) do
    sub.status in ["active", "trial"] and
      (is_nil(sub.expires_at) or DateTime.compare(sub.expires_at, DateTime.utc_now()) == :gt)
  end
  
  @doc """
  Returns true if the subscription is in trial period.
  """
  def in_trial?(%__MODULE__{} = sub) do
    sub.status == "trial" or
      (not is_nil(sub.trial_ends_at) and DateTime.compare(sub.trial_ends_at, DateTime.utc_now()) == :gt)
  end
end
