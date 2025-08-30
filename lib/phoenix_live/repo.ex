defmodule PhoenixLive.Repo do
  use Ecto.Repo,
    otp_app: :phoenixlive,
    adapter: Ecto.Adapters.Postgres

  # CockroachDB migration PK
  def init(_, opts) do
    {:ok, Keyword.put(opts, :migration_primary_key, [type: :bigserial])}
  end
end
