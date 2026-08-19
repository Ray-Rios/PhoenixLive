defmodule PhoenixApp.Games.HoloSimSlot do
  @moduledoc """
  How many Holo-sims one account may own, per game.

  Two counters rather than one total: `granted_slots` is the free allowance and
  `purchased_slots` is what the player paid for. Keeping them apart means the
  free allowance can be raised later without silently giving paying players
  nothing for their money.

  A missing row means the default allowance — no row is written until a player
  either exceeds the default or buys more.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "holo_sim_slots" do
    field :user_id, :binary_id
    field :granted_slots, :integer, default: 10
    field :purchased_slots, :integer, default: 0

    belongs_to :game, PhoenixApp.Games.Game

    timestamps(type: :utc_datetime)
  end

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:game_id, :user_id, :granted_slots, :purchased_slots])
    |> validate_required([:game_id, :user_id])
    |> validate_number(:granted_slots, greater_than_or_equal_to: 0)
    |> validate_number(:purchased_slots, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :user_id])
  end

  def total(%__MODULE__{granted_slots: g, purchased_slots: p}), do: g + p
end
