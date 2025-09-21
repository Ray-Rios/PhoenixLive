defmodule PhoenixApp.Repo.Migrations.AddSecurityFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Email verification
      add :email_verified_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
      
      # Security & rate limiting
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :password_reset_token, :string
      add :password_reset_sent_at, :utc_datetime
      
      # Admin approval (optional)
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, type: :binary_id)
      
      # Account status tracking
      add :registration_ip, :string
      add :last_login_ip, :string
      add :last_login_at, :utc_datetime
    end

    create index(:users, [:email_verification_token])
    create index(:users, [:password_reset_token])
    create index(:users, [:locked_until])
    create index(:users, [:email_verified_at])
  end
end