defmodule Phxlive.Repo.Migrations.DropLegacyLobbyTables do
  use Ecto.Migration

  @moduledoc """
  Web Lobby moved into plugins/web_lobby, with its tables in the games
  database (PHXLIVE.md §9). Its old site-database tables are dropped; the
  characters in them were not carried over (decision: start fresh).

  The migrations that created them were removed, so on a fresh database this
  is a no-op. Irreversible: rolling back does not bring the tables back.
  """

  def up do
    # Children first (foreign keys).
    for table <- ~w(character_equipment character_inventory character_spells items spells characters zones)a do
      drop_if_exists table(table)
    end
  end

  def down, do: :ok
end
