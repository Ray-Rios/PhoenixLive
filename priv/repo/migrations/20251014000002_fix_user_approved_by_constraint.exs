defmodule PhoenixApp.Repo.Migrations.FixUserApprovedByConstraint do
  use Ecto.Migration

  def up do
    # Drop the existing foreign key constraint on approved_by_id
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_approved_by_id_fkey"
    
    # Add it back with ON DELETE SET NULL
    execute """
    ALTER TABLE users 
    ADD CONSTRAINT users_approved_by_id_fkey 
    FOREIGN KEY (approved_by_id) 
    REFERENCES users(id) 
    ON DELETE SET NULL
    """
  end

  def down do
    # Drop the constraint with ON DELETE SET NULL
    execute "ALTER TABLE users DROP CONSTRAINT users_approved_by_id_fkey"
    
    # Add it back without cascade (original behavior)
    execute """
    ALTER TABLE users 
    ADD CONSTRAINT users_approved_by_id_fkey 
    FOREIGN KEY (approved_by_id) 
    REFERENCES users(id)
    """
  end
end
