defmodule PhoenixApp.Repo.Migrations.AddIconToChannels do
  use Ecto.Migration

  def change do
    alter table(:chat_channels) do
      add :icon_path, :string
    end
  end
end
