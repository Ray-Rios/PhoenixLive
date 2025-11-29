defmodule PhoenixApp.Repo.Migrations.AddRoleToChannelMembers do
  use Ecto.Migration

  def change do
    # Add role field to channel_members (no-op if column already exists)
    execute("ALTER TABLE channel_members ADD COLUMN IF NOT EXISTS role varchar DEFAULT 'member';")

    # Add index for faster role queries (safe if index already exists)
    execute("CREATE INDEX IF NOT EXISTS index_channel_members_on_role ON channel_members (role);")
    # Update existing members: set creator/owner to "owner" role
    execute """
    UPDATE channel_members cm
    SET role = 'owner'
    FROM chat_channels c
    WHERE cm.channel_id = c.id 
    AND (cm.user_id = c.owner_id OR cm.user_id = c.created_by_id)
    """, ""
  end
end
