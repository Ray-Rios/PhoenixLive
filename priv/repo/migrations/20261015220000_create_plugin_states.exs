defmodule Phxlive.Repo.Migrations.CreatePluginStates do
  use Ecto.Migration

  @moduledoc """
  Which plugins an admin has activated on /admin/plugins (PHXLIVE.md §9).

  One row per plugin that an admin has ever toggled. A plugin with no row uses
  `config :phxlive, :default_active_plugins`. Deliberately its own table rather
  than a `cms_options` entry: that table's schema and migration disagree
  (PHXLIVE.md §13), and plugin activation must not depend on it.
  """

  def change do
    create table(:plugin_states, primary_key: false) do
      add :slug, :string, primary_key: true
      add :active, :boolean, null: false
      add :changed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime_usec)
    end
  end
end
