defmodule PhoenixApp.Repo.Migrations.AddUniqueUsernameConstraint do
  use Ecto.Migration

  def up do
    # First, check for and remove any duplicate usernames
    # This will keep the first user with each name and rename duplicates
    execute """
    WITH duplicate_names AS (
      SELECT name, COUNT(*) as count
      FROM users 
      WHERE name IS NOT NULL
      GROUP BY name 
      HAVING COUNT(*) > 1
    ),
    numbered_duplicates AS (
      SELECT u.id, u.name,
             ROW_NUMBER() OVER (PARTITION BY u.name ORDER BY u.inserted_at) as rn
      FROM users u
      INNER JOIN duplicate_names d ON u.name = d.name
    )
    UPDATE users 
    SET name = users.name || '_' || (numbered_duplicates.rn - 1)
    FROM numbered_duplicates
    WHERE users.id = numbered_duplicates.id 
    AND numbered_duplicates.rn > 1;
    """

    # Now create the unique index
    create unique_index(:users, [:name], name: :users_name_unique_index)
  end

  def down do
    drop index(:users, [:name], name: :users_name_unique_index)
  end
end