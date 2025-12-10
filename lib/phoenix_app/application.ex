defmodule PhoenixApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Create ETS tables for sessions and rate limiting
    :ets.new(:user_sessions, [:set, :public, :named_table])
    :ets.new(:rate_limit_table, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(:blocked_ips, [:set, :public, :named_table])
    :ets.new(:honeypot_tracker, [:set, :public, :named_table])
    
    # Create ETS table for Y.js collaborative editing documents
    :ets.new(:yjs_documents, [:set, :public, :named_table])
    
    # Configure PubSub - just use standard adapter, Redis bridging is handled separately
    pubsub_child = {Phoenix.PubSub, name: PhoenixApp.PubSub}

    # Get libcluster topologies
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Start the Cluster Supervisor
      {Cluster.Supervisor, [topologies, [name: PhoenixApp.ClusterSupervisor]]},
      PhoenixApp.Repo,
      pubsub_child,
      PhoenixAppWeb.Presence,
      {Finch, name: PhoenixApp.Finch},
      PhoenixApp.UserSession,
      PhoenixApp.PresenceTracker,
      PhoenixApp.Accounts.RateLimit,
      PhoenixApp.RateLimiter,
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
    
    if enable_redis do
      [
        # Redis connection for MMO scaling
        {Redix, {redis_url(), [name: :redix]}},
        %{
          id: Redix.PubSub,
          start: {Redix.PubSub, :start_link, [redis_url(), [name: :redix_pubsub]]}
        },
        # Start GenServer that listens for Redis pubsub messages and forwards into Phoenix.PubSub
        PhoenixApp.RedisPubSub
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