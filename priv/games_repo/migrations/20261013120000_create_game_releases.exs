defmodule PhoenixApp.GamesRepo.Migrations.CreateGameReleases do
  use Ecto.Migration

  @moduledoc """
  Client releases for the RaysSpaceSim launcher.

  A release is a MANIFEST, not a file: every file the client needs, with its
  size and SHA-256. The bytes live content-addressed on the releases volume
  (`/app/client_releases/blobs/<sha256>`), so a file that did not change between two
  builds is stored - and downloaded - once. That is what makes an update a few
  hundred megabytes instead of the whole game.

  `build_id` is the same git tag the server image carries. The server refuses
  a client whose build differs (ARSSGameModeBase::PreLoginAsync), so the live
  release must always be the one matching the live server image.
  """

  def change do
    create table(:game_releases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false

      add :build_id, :string, null: false

      # %{"files" => [%{"path", "size", "sha256"}], "launcher" => %{"size", "sha256", "version"}}
      add :manifest, :map, null: false, default: %{}

      add :total_bytes, :bigint, null: false, default: 0
      add :notes, :text

      # Exactly one live release per game; publishing a new one clears the rest.
      add :is_live, :boolean, null: false, default: false
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_releases, [:game_id, :build_id])
    create index(:game_releases, [:game_id, :is_live])
  end
end
