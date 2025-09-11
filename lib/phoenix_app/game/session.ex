defmodule PhoenixApp.Game.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_sessions" do
    field :user_id, :string
    field :status, :string, default: "active"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating game sessions.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :status])
    |> validate_required([:status])
    |> validate_inclusion(:status, ["active", "inactive", "expired"])
  end

  @doc """
  Changeset for creating a new session with default values.
  """
  def create_changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:user_id])
    |> put_change(:status, "active")
    |> validate_required([:status])
  end
end