defmodule PhoenixApp.Repo.Migrations.AddPositionToChatChannels do
  use Ecto.Migration

  def change do
    alter table(:chat_channels) do
      add :position, :integer, default: 0
    end

    create index(:chat_channels, [:position])
  end
end