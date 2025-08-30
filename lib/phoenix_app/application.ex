defmodule PhoenixApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Create ETS table for user sessions
    :ets.new(:user_sessions, [:set, :public, :named_table])
    
    children = [
      PhoenixApp.Repo,
      {Phoenix.PubSub, name: PhoenixApp.PubSub},
      {Finch, name: PhoenixApp.Finch},
      PhoenixApp.UserSession,
      PhoenixAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PhoenixApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PhoenixAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end