defmodule Phxlive.Repo.Migrations.CreateDriveAndEntitlements do
  use Ecto.Migration

  @moduledoc """
  Milestone 1 (PHXLIVE.md §7): one storage system for user files.

  * `drive_blobs`   - content-addressed file bodies (SHA-256). Many files may
                      share one blob; GC removes blobs no file references.
  * `drive_folders` - a tree per owner. `parent_id` NULL = the owner's root.
  * `drive_files`   - a named file in a folder, pointing at a blob.
                      `visibility`: private | link | public. `share_token`
                      is set while visibility = link.
  * `drive_usage`   - one row per user: the row that is locked (FOR UPDATE)
                      while a file is added, so the quota check cannot race.
                      Also carries the Guest/Banned lock and 30-day purge date.
  * `entitlements`  - what a user has been granted (storage tiers now; VIP
                      channels, game items later). See §8.

  The legacy `user_files` / `user_folders` tables and the `uploads/users/` tree
  are left untouched; `Phxlive.Drive.Import` copies from them.
  """

  def change do
    create table(:drive_blobs, primary_key: false) do
      add :sha256, :string, size: 64, primary_key: true
      add :size, :bigint, null: false
      add :content_type, :string
      # Bumped every time an upload re-uses this blob. GC only considers blobs
      # whose last reference is older than its grace period, which is what
      # stops it deleting a blob an in-flight upload is about to point at.
      add :last_referenced_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:drive_blobs, [:last_referenced_at])

    create table(:drive_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:drive_folders, type: :binary_id, on_delete: :delete_all)
      add :name, :string, size: 255, null: false
      timestamps(type: :utc_datetime_usec)
    end

    # Sibling names are unique. Two partial indexes because NULL parent_id
    # (root level) never collides in an ordinary unique index.
    create unique_index(:drive_folders, [:owner_id, :parent_id, :name],
             where: "parent_id IS NOT NULL", name: :drive_folders_sibling_name_index)
    create unique_index(:drive_folders, [:owner_id, :name],
             where: "parent_id IS NULL", name: :drive_folders_root_name_index)

    create table(:drive_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :folder_id, references(:drive_folders, type: :binary_id, on_delete: :delete_all)
      add :name, :string, size: 255, null: false
      add :blob_sha256, references(:drive_blobs, column: :sha256, type: :string, on_delete: :restrict), null: false
      add :size, :bigint, null: false
      add :content_type, :string, null: false
      add :visibility, :string, null: false, default: "private"
      add :share_token, :string
      # "user_file:<id>" or "fs:<relative path>" for rows created by the legacy
      # import, so re-running the import is a no-op.
      add :legacy_ref, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:drive_files, [:owner_id, :folder_id])
    create index(:drive_files, [:blob_sha256])
    create unique_index(:drive_files, [:share_token], where: "share_token IS NOT NULL")
    create unique_index(:drive_files, [:legacy_ref], where: "legacy_ref IS NOT NULL")
    create unique_index(:drive_files, [:owner_id, :folder_id, :name],
             where: "folder_id IS NOT NULL", name: :drive_files_sibling_name_index)
    create unique_index(:drive_files, [:owner_id, :name],
             where: "folder_id IS NULL", name: :drive_files_root_name_index)

    create constraint(:drive_files, :drive_files_visibility_check,
             check: "visibility IN ('private', 'link', 'public')")
    create constraint(:drive_files, :drive_files_share_token_check,
             check: "(visibility = 'link') = (share_token IS NOT NULL)")

    create table(:drive_usage, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), primary_key: true
      add :bytes_used, :bigint, null: false, default: 0
      add :file_count, :integer, null: false, default: 0
      # Set when the user's role becomes guest/banned. While set, the owner
      # cannot see, download, share or upload; staff still can.
      add :locked_at, :utc_datetime_usec
      # Files are deleted by Phxlive.Drive.Janitor after this time unless the
      # role is restored first (which clears both columns).
      add :purge_after, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create index(:drive_usage, [:purge_after], where: "purge_after IS NOT NULL")

    create table(:entitlements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :key, :string, null: false
      # Kind-specific amount, e.g. GB for a storage tier.
      add :quantity, :integer
      # Where it came from: "subscription", "order", "admin", ...
      add :source_type, :string, null: false
      add :source_id, :string
      add :starts_at, :utc_datetime_usec, null: false
      add :ends_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revoked_reason, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:entitlements, [:user_id, :kind])
    create index(:entitlements, [:source_type, :source_id])
  end
end
