defmodule PhoenixApp.Game.PlayerStats do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_stats" do
    field :total_score, :integer, default: 0
    field :total_playtime, :integer, default: 0
    field :games_played, :integer, default: 0
    field :highest_level, :integer, default: 1
    field :achievements, :map, default: %{}
    field :preferences, :map, default: %{}

    belongs_to :user, PhoenixApp.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(player_stats, attrs) do
    player_stats
    |> cast(attrs, [:user_id, :total_score, :total_playtime, :games_played,
                    :highest_level, :achievements, :preferences])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end