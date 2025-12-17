defmodule PhoenixApp.Repo.Migrations.AddChannelOrderToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :channel_order, {:array, :binary_id}, default: []
    end
  end
end
