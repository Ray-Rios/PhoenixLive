defmodule PhoenixApp.Game.GameEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_events" do
    field :event_type, :string
    field :event_data, :map
    field :server_timestamp, :utc_datetime_usec
    field :client_timestamp, :utc_datetime_usec
    field :processed, :boolean, default: false

    belongs_to :session, PhoenixApp.Game.GameSession, foreign_key: :session_id
    belongs_to :player, PhoenixApp.Accounts.User, foreign_key: :player_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(game_event, attrs) do
    game_event
    |> cast(attrs, [:session_id, :player_id, :event_type, :event_data,
                    :server_timestamp, :client_timestamp, :processed])
    |> validate_required([:event_type])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:player_id)
  end
end