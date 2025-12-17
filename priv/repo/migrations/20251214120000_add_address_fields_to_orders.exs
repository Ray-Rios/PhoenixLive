defmodule PhoenixApp.Repo.Migrations.AddAddressFieldsToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :billing_address, :map
      add :shipping_address, :map
      add :notes, :text
    end
  end
end
