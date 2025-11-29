defmodule PhoenixApp.Repo.Migrations.AddAvatarOpacityToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :avatar_opacity, :integer, default: 100
    end
  end
end
