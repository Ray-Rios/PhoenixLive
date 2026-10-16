defmodule Phxlive.Repo.Migrations.AddEarliestFinishAtToTasks do
  use Ecto.Migration

  @moduledoc """
  `Phxlive.Scheduler.Engine.compute_schedule/1` computes and saves
  `earliest_finish_at` (and reads it back when scheduling dependent tasks), but
  20251229000000_create_scheduler_tables.exs never created the column, so every
  schedule computation raised. Found 2026-10-15 when the test suite first ran.

  `IF NOT EXISTS` in case a long-lived database already has it; `down` is a
  no-op for the same reason.
  """

  def up do
    execute "ALTER TABLE tasks ADD COLUMN IF NOT EXISTS earliest_finish_at timestamp(0) without time zone"
  end

  def down, do: :ok
end
