defmodule PhoenixApp.Repo.Migrations.AddMissingProductFields do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :weight, :decimal, precision: 8, scale: 2
      add :dimensions, :string
      add :image, :string
      add :stripe_price_id, :string
    end

    create index(:products, [:stripe_price_id])
  end
end
