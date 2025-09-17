defmodule PhoenixApp.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_app,
    adapter: Ecto.Adapters.Postgres
  # AshPostgres calls these hooks on the repo during transactions. Provide
  # minimal no-op implementations so the data layer can invoke them.
  def on_transaction_begin(_info), do: :ok
  def on_transaction_commit(_info), do: :ok
  def on_transaction_rollback(_info), do: :ok
end