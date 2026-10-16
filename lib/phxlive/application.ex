defmodule Phxlive.Application do
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
    pubsub_child = {Phoenix.PubSub, name: Phxlive.PubSub}

    # Get libcluster topologies
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Start the Cluster Supervisor
      {Cluster.Supervisor, [topologies, [name: Phxlive.ClusterSupervisor]]},
      # Log buffer must start early to capture startup logs
      Phxlive.LogBuffer,
      Phxlive.Repo,
      Phxlive.GamesRepo,
      pubsub_child,
      PhxliveWeb.Presence,
      {Finch, name: Phxlive.Finch},
      # Task.Supervisor for async email sending
      {Task.Supervisor, name: Phxlive.EmailTaskSupervisor},
      Phxlive.UserSession,
      Phxlive.PresenceTracker,
      Phxlive.Accounts.RateLimit,
      Phxlive.RateLimiter,
      Phxlive.NotFoundTracker,
      # Scheduler Worker for cron-like event execution
      Phxlive.Scheduler.Worker,
      # Drive maintenance: 30-day purge + blob GC (PHXLIVE.md §7)
      Phxlive.Drive.Janitor,
      # Plugins (PHXLIVE.md §9): active plugins' processes, kept in step with
      # /admin/plugins across the cluster by Plugins.Runtime.
      {DynamicSupervisor, name: Phxlive.PluginSupervisor, strategy: :one_for_one},
      Phxlive.Plugins.Runtime,
      PhxliveWeb.Endpoint
    ] ++ redis_children()

    # Attach Email Logger
    Phxlive.EmailLogging.TelemetryHandler.attach()

    opts = [strategy: :one_for_one, name: Phxlive.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp redis_url do
    Application.get_env(:phxlive, :redis_url) || "redis://localhost:6379/0"
  end

  defp redis_children do
    enable_redis = Application.get_env(:phxlive, :enable_redis, false)
    
    if enable_redis do
      [
        # Redis connection for MMO scaling
        {Redix, {redis_url(), [name: :redix]}},
        %{
          id: Redix.PubSub,
          start: {Redix.PubSub, :start_link, [redis_url(), [name: :redix_pubsub]]}
        },
        # Start GenServer that listens for Redis pubsub messages and forwards into Phoenix.PubSub
        Phxlive.RedisPubSub
      ]
    else
      []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    PhxliveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end