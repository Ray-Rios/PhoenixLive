defmodule PhoenixApp.Games.HoloSimState do
  @moduledoc """
  Persisted world state for a Holo-sim. ONE ROW PER SIM.

  It was originally keyed by `(holo_sim_id, user_id)`, on the assumption that
  every player got their own copy of a sim. Once instances became shared —
  public sims are joined by many people at once — that stopped making sense:
  a shared instance holds ONE world in memory, so it can only have one saved
  state. Per-player state was not a smaller version of this; it was incoherent.

  Who is allowed to cause a save is `HoloSim.visitors_can_build`:

    * false (default) — only the owner's changes persist. Visitors interact with
      the world live and nothing they do survives them leaving. Safe against
      griefing on a public sim, which has no undo.
    * true — anyone inside may leave a permanent mark.

  `last_saved_by_user_id` records who wrote it, which is what makes moderation
  possible once visitors can build.

  `state` is opaque to the hub. The game server decides what it contains —
  destroyed bodies, built pieces, positions, score. Same arrangement as
  `game_characters.stats`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "holo_sim_states" do
    field :state, :map, default: %{}
    field :saved_at, :utc_datetime
    field :last_saved_by_user_id, :binary_id

    # Retained from the per-player era so no data is lost on migration. Not part
    # of the key and not read by anything; last_saved_by_user_id supersedes it.
    field :user_id, :binary_id

    belongs_to :holo_sim, PhoenixApp.Games.HoloSim

    timestamps(type: :utc_datetime)
  end

  def changeset(sim_state, attrs) do
    sim_state
    |> cast(attrs, [:holo_sim_id, :state, :saved_at, :last_saved_by_user_id, :user_id])
    |> validate_required([:holo_sim_id])
    |> foreign_key_constraint(:holo_sim_id)
    |> unique_constraint(:holo_sim_id)
  end
end
