defmodule PhoenixApp.Game.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_sessions" do
    field :session_token, :string
    field :player_x, :float, default: 0.0
    field :player_y, :float, default: 0.0
    field :player_z, :float, default: 0.0
    field :rotation_x, :float, default: 0.0
    field :rotation_y, :float, default: 0.0
    field :rotation_z, :float, default: 0.0
    field :health, :integer, default: 100
    field :score, :integer, default: 0
    field :level, :integer, default: 1
    field :experience, :integer, default: 0
    field :is_active, :boolean, default: true
    field :last_heartbeat, :utc_datetime_usec

    belongs_to :user, PhoenixApp.Accounts.User
    has_many :game_events, PhoenixApp.Game.GameEvent, foreign_key: :session_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:user_id, :session_token, :player_x, :player_y, :player_z,
                    :rotation_x, :rotation_y, :rotation_z, :health, :score,
                    :level, :experience, :is_active, :last_heartbeat])
    |> validate_required([:user_id, :session_token])
    |> unique_constraint(:session_token)
    |> foreign_key_constraint(:user_id)
  end
end