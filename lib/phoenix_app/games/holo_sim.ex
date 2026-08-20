defmodule PhoenixApp.Games.HoloSim do
  @moduledoc """
  A player-authored Holo-sim: a world definition plus who may enter it.

  `spec` is the `FSolarSystemSpec` the Unreal client emits, stored verbatim as
  JSONB. `UCosmosWorldBuilder::BuildFromJson` consumes it unchanged, which is
  why the field is opaque here — the schema evolves in C++ and mirroring it into
  columns would mean a migration for every new field.

  Visibility:

    * `private`  — owner only
    * `invite`   — owner plus invited members
    * `unlisted` — invited members, and hidden from listings
    * `public`   — listed, and anyone may enter

  INSTANCES ARE SHARED. One sim, one running instance, however many players are
  inside it. `public` means "everyone plays together", not "everyone gets their
  own copy". An instance belongs to the sim it is running, and lives as long as
  anyone is in it — so the owner walking out does not evict the visitors, and
  does not stop the owner opening a different sim.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @visibilities ~w(private invite unlisted public)
  @kinds ~w(planet system)

  schema "holo_sims" do
    field :owner_user_id, :binary_id

    # THE FORUM CHANNEL THIS SIM BELONGS TO. Lives in the OTHER database
    # (phoenixapp_prod), so this is a bare uuid with no foreign key and no
    # association - see the migration for what that costs.
    #
    # Nil is a legitimate, permanent state, not a migration artefact: every
    # channel created on the website has no sim until its owner builds one in
    # game, and sims that predate the link have no channel. Code that reads this
    # must handle nil rather than treating it as "not set up yet".
    field :channel_id, :binary_id

    field :name, :string
    field :description, :string
    field :visibility, :string, default: "private"
    field :kind, :string, default: "system"
    field :spec, :map, default: %{}
    field :template_id, :string
    field :is_published, :boolean, default: false
    field :is_locked, :boolean, default: false

    # May anyone but the owner leave a permanent mark?
    #
    # False by default: a visitor to a public sim interacts with the world live,
    # but nothing they do survives them leaving. There is no undo on a shared
    # world, so opting IN to collaboration is the safe direction for the default
    # to point.
    field :visitors_can_build, :boolean, default: false
    field :last_launched_at, :utc_datetime
    field :launch_count, :integer, default: 0

    belongs_to :game, PhoenixApp.Games.Game
    has_many :members, PhoenixApp.Games.HoloSimMember
    has_many :states, PhoenixApp.Games.HoloSimState

    timestamps(type: :utc_datetime)
  end

  def changeset(sim, attrs) do
    sim
    |> cast(attrs, [
      :game_id,
      :owner_user_id,
      :channel_id,
      :name,
      :description,
      :visibility,
      :kind,
      :spec,
      :template_id,
      :is_published,
      :is_locked,
      :visitors_can_build,
      :last_launched_at,
      :launch_count
    ])
    |> validate_required([:game_id, :owner_user_id, :name])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_length(:description, max: 2000)
    |> validate_inclusion(:visibility, @visibilities)
    |> validate_inclusion(:kind, @kinds)
    |> validate_spec()
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :owner_user_id, :name], name: :holo_sims_owner_name_index)
    |> unique_constraint(:channel_id, name: :holo_sims_channel_id_index)
  end

  @doc """
  Changeset for edits made by the owner.

  Deliberately narrower than `changeset/2`: ownership, moderation flags and
  launch counters are not player-editable. Without this split, a hand-built
  params map from a controller could let a player unlock their own sim.

  `channel_id` is absent for a sharper reason than the rest. It is the sim's
  entire access control list now, so an owner who could edit it could re-point
  their sim at a channel with a thousand members - or at somebody else's private
  channel - and inherit that membership wholesale. The link is set once, at
  creation, by the code that just verified the caller owns the channel.
  """
  def owner_changeset(sim, attrs) do
    sim
    |> cast(attrs, [:name, :description, :visibility, :kind, :spec, :template_id, :visitors_can_build])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_length(:description, max: 2000)
    |> validate_inclusion(:visibility, @visibilities)
    |> validate_inclusion(:kind, @kinds)
    |> validate_spec()
    |> unique_constraint([:game_id, :owner_user_id, :name], name: :holo_sims_owner_name_index)
  end

  # A spec that cannot build is worse than no spec: the player pays a cold
  # start, the pod boots, the build fails, and they see a loading screen that
  # never ends. Reject the obviously-broken shapes here instead.
  defp validate_spec(changeset) do
    case get_change(changeset, :spec) do
      nil ->
        changeset

      spec when is_map(spec) ->
        arena = Map.get(spec, "Arena", %{})
        radius = Map.get(arena, "Radius", 0)
        scale = Map.get(spec, "Scale", 0)

        cond do
          not is_number(radius) or radius <= 0 ->
            add_error(changeset, :spec, "Arena.Radius must be a positive number")

          not is_number(scale) or scale <= 0 ->
            add_error(changeset, :spec, "Scale must be a positive number")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :spec, "must be an object")
    end
  end

  def visibilities, do: @visibilities
  def kinds, do: @kinds
end
