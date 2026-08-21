defmodule PhoenixApp.Games.GameCharacter do
  @moduledoc """
  A player's character within a specific game.

  `stats` and `settings` are flexible JSONB maps so each game (RaysSpaceSim,
  and future titles) can store its own shape of data without new migrations.
  Real-time gameplay state should live in the dedicated game server / Redis;
  this record is the periodic/disconnect checkpoint that gets persisted here.

  `user_id` intentionally has no foreign key constraint - it references the
  `users.id` in the main `PhoenixApp.Repo` database, which this repo cannot
  reference directly across databases.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_characters" do
    field :user_id, :binary_id
    field :name, :string
    field :stats, :map, default: %{}
    field :settings, :map, default: %{}
    field :last_played_at, :utc_datetime

    belongs_to :game, PhoenixApp.Games.Game

    timestamps(type: :utc_datetime)
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [:user_id, :game_id, :name, :stats, :settings, :last_played_at])
    |> update_change(:name, &(&1 |> to_string() |> String.trim()))
    |> validate_required([:user_id, :game_id, :name])
    |> validate_length(:name, min: 1, max: 24)
    # Letters (any script), digits, spaces, apostrophes and hyphens. Nothing
    # about this is a security boundary - `name` never reaches a shell, a
    # query template, or another player's client unescaped - it is here so a
    # character sheet is a name a player would recognise as their own instead
    # of a swearword-shaped string a client with no validation happened to let
    # through.
    |> validate_format(:name, ~r/^[\p{L}\p{N} '\-]+$/u,
      message: "can only contain letters, numbers, spaces, apostrophes and hyphens")
    |> foreign_key_constraint(:game_id)
    # Unique per game, not per (game, user) - a character name is what other
    # players see, so two different accounts cannot both be "Wesley" in the
    # same game. Matches the games_repo migration's game_characters_game_id_name_index.
    |> unique_constraint([:game_id, :name], name: :game_characters_game_id_name_index)
  end
end
