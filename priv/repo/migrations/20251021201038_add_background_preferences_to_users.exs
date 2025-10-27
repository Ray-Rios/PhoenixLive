defmodule PhoenixApp.Repo.Migrations.AddBackgroundPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Background type: 'galaxy', 'nebula', 'starfield', 'gradient', 'solid', 'void'
      add :background_preference, :string, default: "galaxy"
      
      # JSON field for storing custom background settings
      # e.g., colors, speeds, particle counts, etc.
      add :background_custom_data, :map, default: %{}
    end
  end
end
