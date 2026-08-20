defmodule PhoenixApp.Repo.Migrations.AddChannelAllowanceToUsers do
  use Ecto.Migration

  @moduledoc """
  How many channels a user may create.

  Replaces a `5` hardcoded in `PhoenixApp.Forum.Channel.validate_channel_limit/1`.
  The number was already a product decision rather than a technical one, and it
  is about to become a purchasable one - /shop will sell channel slots - so it
  needs somewhere to live that a purchase can increment.

  A COLUMN, NOT A CONFIG VALUE. The limit varies per user the moment anyone buys
  anything, and a config default with a per-user override table is two places to
  look for one number.

  Backfilled to 5 so nobody's allowance changes on deploy. Anyone already over
  the limit - possible if the old check was ever bypassed - keeps what they have;
  the check only blocks NEW creates, it never deletes.
  """

  def up do
    alter table(:users) do
      add :channel_allowance, :integer, default: 5, null: false
    end

    execute "UPDATE users SET channel_allowance = 5 WHERE channel_allowance IS NULL"
  end

  def down do
    alter table(:users) do
      remove :channel_allowance
    end
  end
end
