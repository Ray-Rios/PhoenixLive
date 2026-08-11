defmodule PhoenixApp.Games.GameServer do
  @moduledoc """
  A registered dedicated game server (shard) for a title.

  Rows are written by the dedicated servers themselves via a heartbeat, never
  by players — see `PhoenixAppWeb.Api.GamesController.heartbeat_server/2`,
  which refuses anything not authenticated with the server API key. If a
  player could write here they could advertise a server they control to every
  other player, which is a phishing vector rather than a cheat.

  Liveness is heartbeat-based, not shutdown-based. A crashed server never gets
  the chance to deregister, so the presence of a row means nothing on its own;
  only `last_heartbeat_at` being recent does.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(online draining offline)

  schema "game_servers" do
    field :host, :string
    field :port, :integer
    field :name, :string
    field :region, :string, default: "unknown"
    field :status, :string, default: "online"
    field :current_players, :integer, default: 0
    field :max_players, :integer, default: 64
    field :map_name, :string
    field :version, :string
    field :last_heartbeat_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :game, PhoenixApp.Games.Game

    timestamps(type: :utc_datetime)
  end

  def changeset(server, attrs) do
    server
    |> cast(attrs, [
      :game_id,
      :host,
      :port,
      :name,
      :region,
      :status,
      :current_players,
      :max_players,
      :map_name,
      :version,
      :last_heartbeat_at,
      :metadata
    ])
    |> validate_required([:game_id, :host, :port, :name, :last_heartbeat_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> validate_number(:current_players, greater_than_or_equal_to: 0)
    |> validate_number(:max_players, greater_than: 0)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :host, :port], name: :game_servers_game_id_host_port_index)
  end

  def statuses, do: @statuses
end
