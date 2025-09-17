defmodule PhoenixApp.Repo.Migrations.BackfillPasswordHashAndDropHashedPassword do
  use Ecto.Migration

  def up do
    # Copy any existing hashed_password values into password_hash where password_hash is NULL
    execute("UPDATE users SET password_hash = hashed_password WHERE password_hash IS NULL AND hashed_password IS NOT NULL;")

    # Drop the old column if it exists
    execute("ALTER TABLE users DROP COLUMN IF EXISTS hashed_password;")
  end

  def down do
    # Recreate the old column and copy values back from password_hash
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS hashed_password text;")
    execute("UPDATE users SET hashed_password = password_hash WHERE hashed_password IS NULL AND password_hash IS NOT NULL;")
  end
end
