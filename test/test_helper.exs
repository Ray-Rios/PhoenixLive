ExUnit.start()

# Configure SQL sandbox for ecto tests (manual by default)
if Code.ensure_loaded?(Ecto.Adapters.SQL) do
  Ecto.Adapters.SQL.Sandbox.mode(PhoenixApp.Repo, :manual)
end
