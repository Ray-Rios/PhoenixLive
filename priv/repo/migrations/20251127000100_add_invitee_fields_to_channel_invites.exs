defmodule PhoenixApp.Repo.Migrations.AddInviteeFieldsToChannelInvites do
  use Ecto.Migration

  def change do
    alter table(:channel_invites) do
      add :invitee_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :is_revoked, :boolean, default: false
    end

    create index(:channel_invites, [:invitee_id])
    create index(:channel_invites, [:is_revoked])
  end
end
