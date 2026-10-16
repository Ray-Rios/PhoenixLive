defmodule Phxlive.GamesRepo do
  @moduledoc """
  Isolated Ecto repo for multiplayer game data (characters, stats, settings).

  Kept separate from `Phxlive.Repo` (accounts/web content) so that game data
  for RaysSpaceSim and future titles can evolve, scale, and be backed up
  independently of the main site database. Player identity still lives in
  `Phxlive.Repo` (`users` table); records here reference `user_id` by value
  only (no cross-database foreign key).
  """

  use Ecto.Repo,
    otp_app: :phxlive,
    adapter: Ecto.Adapters.Postgres
end
