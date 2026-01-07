defmodule PhoenixApp.Repo.Migrations.CreateEmailLogs do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:email_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :to, :string
      add :from, :string
      add :subject, :string
      add :html_body, :text
      add :text_body, :text
      add :provider, :string
      add :status, :string
      add :error, :text
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:email_logs, [:to])
    create_if_not_exists index(:email_logs, [:sent_at])
  end
end
