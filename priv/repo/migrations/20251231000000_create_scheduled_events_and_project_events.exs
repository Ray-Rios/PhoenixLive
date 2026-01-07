defmodule PhoenixApp.Repo.Migrations.CreateScheduledEventsAndProjectEvents do
  use Ecto.Migration

  def change do
    # Scheduled events table - for cron jobs, one-time events, webhooks, triggers
    create table(:scheduled_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :event_type, :string, null: false, default: "one_time"  # one_time, recurring, webhook, project_trigger
      add :status, :string, default: "active"  # active, paused, completed, failed
      
      # Scheduling
      add :scheduled_at, :utc_datetime
      add :cron_expression, :string
      add :timezone, :string, default: "UTC"
      add :next_run_at, :utc_datetime
      add :last_run_at, :utc_datetime
      add :run_count, :integer, default: 0
      add :max_runs, :integer  # nil = unlimited
      
      # Action configuration
      add :action_type, :string  # http_request, create_project, complete_project, send_email, run_script, notify
      add :action_config, :map, default: %{}
      
      # Webhook configuration
      add :webhook_secret, :string
      add :webhook_url, :string
      
      # Project integration
      add :trigger_project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      add :trigger_on, :string  # project_start, project_complete, task_complete
      add :target_project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      
      # Ownership
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      
      # Execution tracking
      add :last_error, :text
      add :metadata, :map, default: %{}
      
      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_events, [:event_type])
    create index(:scheduled_events, [:status])
    create index(:scheduled_events, [:next_run_at])
    create index(:scheduled_events, [:trigger_project_id])
    create index(:scheduled_events, [:target_project_id])
    create index(:scheduled_events, [:created_by_id])
    create unique_index(:scheduled_events, [:webhook_secret], where: "webhook_secret IS NOT NULL")

    # Project events table - audit log and triggers
    create table(:project_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :occurred_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}
      
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all)
      add :triggered_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      
      # Track which scheduled events were triggered by this project event
      add :triggered_events, {:array, :binary_id}, default: []
      
      timestamps(type: :utc_datetime)
    end

    create index(:project_events, [:project_id])
    create index(:project_events, [:task_id])
    create index(:project_events, [:event_type])
    create index(:project_events, [:occurred_at])

    # Execution log for scheduled events
    create table(:scheduled_event_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scheduled_event_id, references(:scheduled_events, type: :binary_id, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :status, :string, default: "running"  # running, success, failed
      add :result, :map, default: %{}
      add :error, :text
      add :duration_ms, :integer
      
      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_event_runs, [:scheduled_event_id])
    create index(:scheduled_event_runs, [:started_at])
    create index(:scheduled_event_runs, [:status])
  end
end
