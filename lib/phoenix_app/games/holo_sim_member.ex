defmodule PhoenixApp.Games.HoloSimMember do
  @moduledoc """
  An invitation to a Holo-sim.

  A row means "invited". `accepted_at` being set means the invitee has
  acknowledged it. Access is granted on invitation rather than on acceptance —
  acceptance only controls whether the sim appears in their "Shared with me"
  list, so an invite is usable immediately.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Only viewer is meaningful today. The others exist so the column does not
  # need a migration when collaboration lands.
  @roles ~w(viewer builder co_owner)

  schema "holo_sim_members" do
    field :user_id, :binary_id
    field :role, :string, default: "viewer"
    field :invited_by_user_id, :binary_id
    field :invited_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :holo_sim, PhoenixApp.Games.HoloSim

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:holo_sim_id, :user_id, :role, :invited_by_user_id, :invited_at, :accepted_at])
    |> validate_required([:holo_sim_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> foreign_key_constraint(:holo_sim_id)
    |> unique_constraint([:holo_sim_id, :user_id])
  end

  def roles, do: @roles
end
