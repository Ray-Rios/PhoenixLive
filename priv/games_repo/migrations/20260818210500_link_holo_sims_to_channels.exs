defmodule PhoenixApp.GamesRepo.Migrations.LinkHoloSimsToChannels do
  use Ecto.Migration

  @moduledoc """
  A Holo-sim belongs to a forum channel.

  NO FOREIGN KEY IS POSSIBLE HERE, AND THAT IS NOT AN OVERSIGHT.

  `chat_channels` lives in the main database (phoenixapp_prod, PhoenixApp.Repo).
  `holo_sims` lives in the games database (phoenix_games_prod,
  PhoenixApp.GamesRepo). Postgres cannot reference across databases, so this is
  a plain uuid column and integrity is the application's job. Concretely:

    * a channel can be deleted while a sim still points at it. Deleting a channel
      must delete the sim explicitly - see PhoenixApp.Forum.delete_channel/1.
    * there is no ON DELETE CASCADE to fall back on, so an orphaned sim is a
      real state the code has to handle rather than one the database prevents.
    * the two writes cannot share a transaction. Creating a channel and its sim
      is two commits, and the gap between them is a state the system can be
      observed in: channel exists, sim does not. That is the SAME state as an
      existing channel whose owner has not built a sim yet, which is why it is
      safe - the system already has to render it.

  UNIQUE, PARTIAL. One channel, at most one sim. The index is partial so the
  many sims with a NULL channel_id - every sim that predates this migration -
  do not collide with each other, since NULLs are distinct in a plain unique
  index but a partial index states the intent instead of relying on that.
  """

  def up do
    alter table(:holo_sims) do
      add :channel_id, :binary_id
    end

    create unique_index(:holo_sims, [:channel_id],
             where: "channel_id IS NOT NULL",
             name: :holo_sims_channel_id_index
           )

    # Finding a sim by its channel is the hot path: it happens every time a
    # player walks through the door, and every time channel membership changes
    # and we need to know whether an instance must be told about it.
    create index(:holo_sims, [:game_id, :channel_id])
  end

  def down do
    drop index(:holo_sims, [:game_id, :channel_id])
    drop index(:holo_sims, [:channel_id], name: :holo_sims_channel_id_index)

    alter table(:holo_sims) do
      remove :channel_id
    end
  end
end
