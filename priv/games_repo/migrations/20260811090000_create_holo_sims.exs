defmodule PhoenixApp.GamesRepo.Migrations.CreateHoloSims do
  use Ecto.Migration

  def up do
    # ---------------------------------------------------------------
    # holo_sims - the definition a player authored
    # ---------------------------------------------------------------
    create_if_not_exists table(:holo_sims, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false

      # No FK: users live in the main Repo, which this database cannot
      # reference. Same arrangement as game_characters.user_id.
      add :owner_user_id, :binary_id, null: false

      add :name, :string, null: false
      add :description, :text

      # private | invite | unlisted | public
      #
      # A plain string rather than a Postgres enum so adding a level later is a
      # code change, not a migration that locks the table.
      add :visibility, :string, null: false, default: "private"

      # planet | system
      add :kind, :string, null: false, default: "system"

      # THE FSolarSystemSpec, verbatim.
      #
      # This is the same JSON setup_cosmic_demo5.py writes and
      # UCosmosWorldBuilder::BuildFromJson already consumes. Keeping it as one
      # opaque blob is deliberate: the schema evolves in C++, and mirroring it
      # into columns here would mean a migration every time a field is added.
      add :spec, :map, null: false, default: %{}

      # Which gallery entry this started from. Informational.
      add :template_id, :string

      # Moderation. is_locked freezes edits without deleting anything, so an
      # admin can stop a sim being changed while a report is reviewed.
      add :is_published, :boolean, null: false, default: false
      add :is_locked, :boolean, null: false, default: false

      add :last_launched_at, :utc_datetime
      add :launch_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:holo_sims, [:game_id, :owner_user_id])
    create_if_not_exists index(:holo_sims, [:game_id, :visibility])

    # A player cannot have two sims with the same name - the door list would be
    # ambiguous and support requests unanswerable.
    create_if_not_exists unique_index(:holo_sims, [:game_id, :owner_user_id, :name],
                           name: :holo_sims_owner_name_index
                         )

    # ---------------------------------------------------------------
    # holo_sim_members - the invite list
    # ---------------------------------------------------------------
    create_if_not_exists table(:holo_sim_members, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :holo_sim_id, references(:holo_sims, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, :binary_id, null: false

      # viewer for now. The column exists so builder / co-owner can be added
      # without a migration once collaboration is wanted.
      add :role, :string, null: false, default: "viewer"

      add :invited_by_user_id, :binary_id
      add :invited_at, :utc_datetime
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:holo_sim_members, [:holo_sim_id, :user_id])
    create_if_not_exists index(:holo_sim_members, [:user_id])

    # ---------------------------------------------------------------
    # holo_sim_slots - how many sims an account may own
    # ---------------------------------------------------------------
    create_if_not_exists table(:holo_sim_slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :binary_id, null: false

      # Purchased slots are tracked separately from the free grant so the
      # default can be raised later without silently giving paying players
      # nothing extra.
      add :granted_slots, :integer, null: false, default: 10
      add :purchased_slots, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:holo_sim_slots, [:game_id, :user_id])

    # ---------------------------------------------------------------
    # holo_sim_states - persisted world state, PER PLAYER
    # ---------------------------------------------------------------
    #
    # Keyed by (holo_sim_id, user_id), not by sim alone. That is a direct
    # consequence of two decisions taken together:
    #
    #   * every player who launches a sim gets their OWN server instance
    #   * sims persist what happened inside them
    #
    # With state keyed by sim alone, two visitors to a public sim would write
    # over each other, and any visitor could vandalise the owner's world. The
    # owner's row is the canonical one; a visitor gets a private save of their
    # own visit.
    #
    # Collapsing this to per-sim later is a data merge, not a schema change.
    create_if_not_exists table(:holo_sim_states, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :holo_sim_id, references(:holo_sims, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, :binary_id, null: false

      # Opaque to the hub. The game server decides what "state" means -
      # destroyed bodies, built pieces, player position, score.
      add :state, :map, null: false, default: %{}

      add :saved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:holo_sim_states, [:holo_sim_id, :user_id])
  end

  def down do
    drop_if_exists table(:holo_sim_states)
    drop_if_exists table(:holo_sim_slots)
    drop_if_exists table(:holo_sim_members)
    drop_if_exists table(:holo_sims)
  end
end
