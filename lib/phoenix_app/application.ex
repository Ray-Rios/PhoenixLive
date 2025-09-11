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
    ] ++ redis_children()

    opts = [strategy: :one_for_one, name: PhoenixApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp redis_url do
    Application.get_env(:phoenix_app, :redis_url) || "redis://localhost:6379/0"
  end

  defp redis_children do
    enable_redis = Application.get_env(:phoenix_app, :enable_redis, false)
    IO.puts("Redis enabled: #{enable_redis}")
    
    if enable_redis do
      [
        # Redis connection for MMO scaling
        {Redix, {redis_url(), [name: :redix]}},
        %{
          id: Redix.PubSub,
          start: {Redix.PubSub, :start_link, [redis_url(), [name: :redix_pubsub]]}
        },
        # MMO Game Server Manager
        PhoenixApp.MMO.GameServerManager
      ]
    else
      []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    PhoenixAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end