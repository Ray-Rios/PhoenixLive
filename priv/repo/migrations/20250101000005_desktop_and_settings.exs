defmodule PhoenixApp.Repo.Migrations.DesktopAndSettings do
  @moduledoc """
  ============================================================================
  DESKTOP & SETTINGS TABLES
  ============================================================================
  Window layouts, calendar notes, and CMS options for the desktop environment.
  """
  use Ecto.Migration

  def change do
    execute """
    DO $$
    BEGIN
      -- WINDOW LAYOUTS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'window_layouts') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'window_layouts' AND column_name = 'is_default') THEN
          ALTER TABLE window_layouts ADD COLUMN is_default boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'window_layouts' AND column_name = 'layout_name') THEN
          ALTER TABLE window_layouts ADD COLUMN layout_name text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'window_layouts' AND column_name = 'windows_config') THEN
          ALTER TABLE window_layouts ADD COLUMN windows_config jsonb DEFAULT '{}';
        END IF;

        -- Fix empty layout_names
        UPDATE window_layouts SET layout_name = id::text WHERE layout_name = '';
      END IF;

      -- CALENDAR NOTES
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'calendar_notes') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'is_all_day') THEN
          ALTER TABLE calendar_notes ADD COLUMN is_all_day boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'starts_at') THEN
          ALTER TABLE calendar_notes ADD COLUMN starts_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'ends_at') THEN
          ALTER TABLE calendar_notes ADD COLUMN ends_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'color') THEN
          ALTER TABLE calendar_notes ADD COLUMN color text DEFAULT '#3b82f6';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'reminder') THEN
          ALTER TABLE calendar_notes ADD COLUMN reminder boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'calendar_notes' AND column_name = 'reminder_at') THEN
          ALTER TABLE calendar_notes ADD COLUMN reminder_at timestamp(0) without time zone;
        END IF;
      END IF;

      -- CMS OPTIONS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cms_options') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cms_options' AND column_name = 'key') THEN
          ALTER TABLE cms_options ADD COLUMN key text NOT NULL DEFAULT '';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cms_options' AND column_name = 'value') THEN
          ALTER TABLE cms_options ADD COLUMN value text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cms_options' AND column_name = 'autoload') THEN
          ALTER TABLE cms_options ADD COLUMN autoload boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cms_options' AND column_name = 'category') THEN
          ALTER TABLE cms_options ADD COLUMN category text DEFAULT 'general';
        END IF;

        -- Fix empty keys
        UPDATE cms_options SET key = id::text WHERE key = '';
      END IF;

      -- USER SESSIONS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_sessions') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'session_data') THEN
          ALTER TABLE user_sessions ADD COLUMN session_data jsonb DEFAULT '{}';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'desktop_state') THEN
          ALTER TABLE user_sessions ADD COLUMN desktop_state jsonb DEFAULT '{}';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'last_activity_at') THEN
          ALTER TABLE user_sessions ADD COLUMN last_activity_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'user_agent') THEN
          ALTER TABLE user_sessions ADD COLUMN user_agent text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'ip_address') THEN
          ALTER TABLE user_sessions ADD COLUMN ip_address text;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_sessions' AND column_name = 'device_type') THEN
          ALTER TABLE user_sessions ADD COLUMN device_type text;
        END IF;
      END IF;

      -- NOTIFICATION PREFERENCES
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_preferences') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'email_notifications') THEN
          ALTER TABLE notification_preferences ADD COLUMN email_notifications boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'push_notifications') THEN
          ALTER TABLE notification_preferences ADD COLUMN push_notifications boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'desktop_notifications') THEN
          ALTER TABLE notification_preferences ADD COLUMN desktop_notifications boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'chat_mentions') THEN
          ALTER TABLE notification_preferences ADD COLUMN chat_mentions boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'chat_direct_messages') THEN
          ALTER TABLE notification_preferences ADD COLUMN chat_direct_messages boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'order_updates') THEN
          ALTER TABLE notification_preferences ADD COLUMN order_updates boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'marketing_emails') THEN
          ALTER TABLE notification_preferences ADD COLUMN marketing_emails boolean DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'digest_frequency') THEN
          ALTER TABLE notification_preferences ADD COLUMN digest_frequency text DEFAULT 'daily';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'quiet_hours_start') THEN
          ALTER TABLE notification_preferences ADD COLUMN quiet_hours_start time without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'quiet_hours_end') THEN
          ALTER TABLE notification_preferences ADD COLUMN quiet_hours_end time without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notification_preferences' AND column_name = 'timezone') THEN
          ALTER TABLE notification_preferences ADD COLUMN timezone text DEFAULT 'UTC';
        END IF;
      END IF;

      -- ANNOUNCEMENTS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'announcements') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'announcement_type') THEN
          ALTER TABLE announcements ADD COLUMN announcement_type text DEFAULT 'info';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'is_active') THEN
          ALTER TABLE announcements ADD COLUMN is_active boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'is_dismissible') THEN
          ALTER TABLE announcements ADD COLUMN is_dismissible boolean DEFAULT true;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'starts_at') THEN
          ALTER TABLE announcements ADD COLUMN starts_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'ends_at') THEN
          ALTER TABLE announcements ADD COLUMN ends_at timestamp(0) without time zone;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'target_audience') THEN
          ALTER TABLE announcements ADD COLUMN target_audience text DEFAULT 'all';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'display_location') THEN
          ALTER TABLE announcements ADD COLUMN display_location text[] DEFAULT '{"all"}';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'created_by_id') THEN
          ALTER TABLE announcements ADD COLUMN created_by_id uuid REFERENCES users(id) ON DELETE SET NULL;
        END IF;
      END IF;

      -- DISMISSED ANNOUNCEMENTS
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dismissed_announcements') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dismissed_announcements' AND column_name = 'dismissed_at') THEN
          ALTER TABLE dismissed_announcements ADD COLUMN dismissed_at timestamp(0) without time zone NOT NULL DEFAULT NOW();
        END IF;
      END IF;

    END $$;
    """, ""

    # ============================================================================
    # WINDOW LAYOUTS (Desktop Environment)
    # ============================================================================

    create_if_not_exists table(:window_layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :layout_name, :string, null: false
      add :windows_config, :map, default: %{}
      add :is_default, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:window_layouts, [:user_id])
    create_if_not_exists index(:window_layouts, [:is_default])
    create_if_not_exists unique_index(:window_layouts, [:user_id, :layout_name])

    # ============================================================================
    # CALENDAR NOTES
    # ============================================================================

    create_if_not_exists table(:calendar_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :content, :text
      add :is_all_day, :boolean, default: true
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :color, :string, default: "#3b82f6"
      add :reminder, :boolean, default: false
      add :reminder_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists index(:calendar_notes, [:user_id])
    create_if_not_exists index(:calendar_notes, [:date])
    create_if_not_exists index(:calendar_notes, [:user_id, :date])
    create_if_not_exists index(:calendar_notes, [:reminder, :reminder_at])

    # ============================================================================
    # CMS OPTIONS (Site-wide Settings)
    # ============================================================================

    create_if_not_exists table(:cms_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text
      add :autoload, :boolean, default: true
      add :category, :string, default: "general"
      timestamps()
    end

    create_if_not_exists unique_index(:cms_options, [:key])
    create_if_not_exists index(:cms_options, [:autoload])
    create_if_not_exists index(:cms_options, [:category])

    # ============================================================================
    # USER SESSIONS (for desktop state persistence)
    # ============================================================================
    # Note: user sessions for authentication are handled via users_tokens
    # This is specifically for desktop environment state

    create_if_not_exists table(:user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_data, :map, default: %{}
      add :desktop_state, :map, default: %{}
      add :last_activity_at, :utc_datetime
      add :user_agent, :string
      add :ip_address, :string
      add :device_type, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:user_sessions, [:user_id])
    create_if_not_exists index(:user_sessions, [:last_activity_at])

    # ============================================================================
    # NOTIFICATION PREFERENCES
    # ============================================================================

    create_if_not_exists table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_notifications, :boolean, default: true
      add :push_notifications, :boolean, default: true
      add :desktop_notifications, :boolean, default: true
      add :chat_mentions, :boolean, default: true
      add :chat_direct_messages, :boolean, default: true
      add :order_updates, :boolean, default: true
      add :marketing_emails, :boolean, default: false
      add :digest_frequency, :string, default: "daily"  # none, daily, weekly
      add :quiet_hours_start, :time
      add :quiet_hours_end, :time
      add :timezone, :string, default: "UTC"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create_if_not_exists unique_index(:notification_preferences, [:user_id])

    # ============================================================================
    # SITE ANNOUNCEMENTS
    # ============================================================================

    create_if_not_exists table(:announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text, null: false
      add :announcement_type, :string, default: "info"  # info, warning, error, success
      add :is_active, :boolean, default: true
      add :is_dismissible, :boolean, default: true
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :target_audience, :string, default: "all"  # all, authenticated, guests, premium
      add :display_location, {:array, :string}, default: ["all"]  # all, home, dashboard, shop
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:announcements, [:is_active])
    create_if_not_exists index(:announcements, [:starts_at])
    create_if_not_exists index(:announcements, [:ends_at])
    create_if_not_exists index(:announcements, [:announcement_type])
    create_if_not_exists index(:announcements, [:target_audience])
    create_if_not_exists index(:announcements, [:created_by_id])

    # ============================================================================
    # DISMISSED ANNOUNCEMENTS (User tracking)
    # ============================================================================

    create_if_not_exists table(:dismissed_announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :announcement_id, references(:announcements, type: :binary_id, on_delete: :delete_all), null: false
      add :dismissed_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:dismissed_announcements, [:user_id, :announcement_id])
    create_if_not_exists index(:dismissed_announcements, [:announcement_id])
  end
end
