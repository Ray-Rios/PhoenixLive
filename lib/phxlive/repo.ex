defmodule Phxlive.Repo do
  use Ecto.Repo,
    otp_app: :phxlive,
    adapter: Ecto.Adapters.Postgres
end