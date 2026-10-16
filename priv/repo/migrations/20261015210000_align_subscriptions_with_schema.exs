defmodule Phxlive.Repo.Migrations.AlignSubscriptionsWithSchema do
  use Ecto.Migration

  @moduledoc """
  `Phxlive.Commerce.Subscription` declares fields that
  20250101000004_commerce.exs never creates, and Ecto selects every schema
  field - so on a database built from the migrations, *every* subscription
  query failed with "column does not exist". Found 2026-10-15 by the drive
  tests (role change -> cancel subscriptions).

  `cancelled_at` vs the real `canceled_at` column is handled in the schema
  (`source: :canceled_at`). The rest are added here. `IF NOT EXISTS` because a
  long-lived database may already have some of them (the commerce migration is
  itself written with create_if_not_exists). Commerce is redesigned in
  milestone 4 (PHXLIVE.md §8); this only makes the current schema loadable.

  `down` is a no-op: these columns may have existed before this migration.
  """

  def up do
    execute """
    ALTER TABLE subscriptions
      ADD COLUMN IF NOT EXISTS starts_at timestamp(0) without time zone,
      ADD COLUMN IF NOT EXISTS expires_at timestamp(0) without time zone,
      ADD COLUMN IF NOT EXISTS trial_ends_at timestamp(0) without time zone,
      ADD COLUMN IF NOT EXISTS stripe_customer_id varchar(255),
      ADD COLUMN IF NOT EXISTS storage_bytes_granted bigint DEFAULT 0,
      ADD COLUMN IF NOT EXISTS role_granted varchar(255),
      ADD COLUMN IF NOT EXISTS features_granted varchar(255)[] DEFAULT '{}'
    """
  end

  def down, do: :ok
end
