defmodule PhoenixApp.Games.InstanceLauncher do
  @moduledoc """
  Turns "launch this Holo-sim" into a Kubernetes Job.

  This is the M5 half of the launch path. Nothing else about launching moves:
  the client already polls `/status`, the access check already guards the door,
  and the instance still announces itself by heartbeat. All that changes is who
  starts the process - a Job here instead of `run_holosim_server.bat` on a
  desktop.

  ## The Job is named from the sim, not randomly

  `holosim-<sim id>` is deterministic, so two players opening the same door at
  the same moment produce one Job and one `409 AlreadyExists`, which the
  launcher reports as success. A random name would give you two processes
  serving one world, both heartbeating, each overwriting the other's saves.

  ## The instance still tells the hub where it is

  The launcher assigns a port and passes it in, but the pod reports its own
  address on its heartbeat exactly as a hand-started server does. That keeps one
  path for "how does an instance become joinable" rather than two that can
  disagree - and it is why a Job that starts but never heartbeats shows up
  correctly as "still pending" instead of as a joinable server that refuses
  connections.
  """

  require Logger

  alias PhoenixApp.Games
  alias PhoenixApp.Kubernetes

  @label "holosim"

  @doc "True when instances can actually be started. False outside a cluster."
  def available?, do: Kubernetes.in_cluster?() and not is_nil(config(:image))

  @doc """
  Start an instance for a sim.

  `{:ok, :started}`, `{:ok, :already_starting}`, or `{:error, reason}`. The two
  success cases are distinguished for logging only - to a caller they both mean
  "a process is on its way, keep polling".
  """
  def launch(game, sim, user_id) do
    cond do
      not Kubernetes.in_cluster?() ->
        {:error, :not_in_cluster}

      is_nil(config(:image)) ->
        {:error, :no_image_configured}

      true ->
        do_launch(game, sim, user_id)
    end
  end

  @doc "Delete an instance's Job and its pod. Idempotent."
  def terminate(sim_id) do
    with true <- Kubernetes.in_cluster?(),
         ns when is_binary(ns) <- namespace() do
      Kubernetes.delete_job(ns, job_name(sim_id))
    else
      _ -> {:error, :not_in_cluster}
    end
  end

  @doc "Every instance Job currently known to the cluster."
  def list_jobs do
    with true <- Kubernetes.in_cluster?(),
         ns when is_binary(ns) <- namespace() do
      Kubernetes.list_jobs(ns, "app=#{@label}")
    else
      _ -> {:ok, []}
    end
  end

  # -------------------------------------------------------------------------

  defp do_launch(game, sim, user_id) do
    ns = namespace()

    case allocate_port(game.id) do
      {:ok, port} ->
        manifest = manifest(sim, user_id, port, ns)

        case Kubernetes.create_job(ns, manifest) do
          {:ok, name} ->
            Logger.info("Launched Holo-sim instance #{name} on port #{port}")
            {:ok, :started}

          {:error, :already_exists} ->
            # Not a failure. See the moduledoc - deterministic naming is what
            # makes a simultaneous double-open produce one world.
            Logger.info("Holo-sim #{sim.id} is already starting")
            {:ok, :already_starting}

          {:error, reason} = error ->
            Logger.error("Failed to launch Holo-sim #{sim.id}: #{inspect(reason)}")
            error
        end

      {:error, :no_free_port} = error ->
        Logger.error("No free instance port for Holo-sim #{sim.id}")
        error
    end
  end

  # PORT ALLOCATION, AND ITS HONEST LIMIT.
  #
  # Ports come from a configured range, skipping any a live server already
  # advertises. This is read-then-use, so two launches landing in the same
  # instant can pick the same port; the loser's heartbeat then fails the
  # {game, host, port} unique index and it never becomes joinable.
  #
  # Left as-is deliberately rather than papered over with a lock: the window is
  # milliseconds, the failure is visible in the admin section as a Job with no
  # heartbeat, and a real fix belongs with a per-instance Service rather than
  # host ports. Worth revisiting the moment instances stop sharing a node.
  defp allocate_port(game_id) do
    {from, to} = config(:port_range)

    taken =
      game_id
      |> Games.list_servers_for_admin()
      |> Enum.reject(&Games.server_stale?/1)
      |> MapSet.new(& &1.port)

    case Enum.find(from..to, &(not MapSet.member?(taken, &1))) do
      nil -> {:error, :no_free_port}
      port -> {:ok, port}
    end
  end

  defp manifest(sim, user_id, port, namespace) do
    name = job_name(sim.id)

    %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{
        "name" => name,
        "namespace" => namespace,
        "labels" => %{
          "app" => @label,
          "holo-sim-id" => to_string(sim.id)
        }
      },
      "spec" => %{
        # NO RETRIES. A crashed instance must not come back by itself: it would
        # reclaim the same port with a fresh empty world while the hub still
        # believes the old one, and the player would be dropped into a sim that
        # silently lost their work. A failed launch should stay failed and be
        # visible.
        "backoffLimit" => 0,

        # Cleanup without a cron. The Job and its pod are removed this long
        # after finishing, so the namespace does not fill with completed
        # instances and the port comes back on its own.
        "ttlSecondsAfterFinished" => config(:ttl_seconds),

        # A backstop, not the normal path. Instances retire themselves once
        # empty (EmptyInstanceShutdownSeconds); this catches one that wedges.
        "activeDeadlineSeconds" => config(:max_lifetime_seconds),
        "template" => %{
          "metadata" => %{
            "labels" => %{"app" => @label, "holo-sim-id" => to_string(sim.id)}
          },
          "spec" => %{
            "restartPolicy" => "Never",
            "containers" => [
              # Pruned: an unset "command" must be ABSENT, not null. Kubernetes
              # rejects a null there, so leaving the key in would break every
              # launch in the normal case where no override is configured.
              prune(%{
                "name" => "instance",
                "image" => config(:image),
                "imagePullPolicy" => config(:image_pull_policy),

                # ENTRYPOINT OVERRIDE, FOR PROVING THE PATH WITHOUT A SERVER.
                #
                # The real image runs the packaged server and takes the args
                # below as-is, so this stays unset in production. A stub image
                # does not understand `-HoloSimId=`, and without an override it
                # would try to execute it and crash - which fails the Job for
                # the wrong reason and tells you nothing about whether the
                # orchestration works.
                #
                # HOLOSIM_COMMAND='["sleep","3600"]' with HOLOSIM_IMAGE=busybox
                # exercises create, status, TTL cleanup and port allocation end
                # to end. It will never heartbeat, so the sim stays `pending` -
                # which is correct, and is itself worth seeing.
                "command" => config(:command),
                "args" => [
                  "-HoloSimId=#{sim.id}",
                  "-HoloSimUserId=#{user_id}",
                  "-PhxHost=#{config(:public_host)}",
                  "-PhxPort=#{port}",
                  "-Port=#{port}"
                ],
                "ports" => [
                  %{
                    "containerPort" => port,
                    # hostPort because a game client connects directly over UDP
                    # and cannot go through the HTTP ingress. Ties an instance to
                    # its node, which is fine on single-node k3s and is the first
                    # thing to replace when it stops being single-node.
                    "hostPort" => port,
                    "protocol" => "UDP"
                  }
                ],
                "env" => [
                  # The server key, from the same secret the web pods use. It is
                  # what lets the instance validate joins at all - without it
                  # every player is refused and the instance looks broken rather
                  # than unconfigured.
                  %{
                    "name" => "PHX_GAMES_SERVER_API_KEY",
                    "valueFrom" => %{
                      "secretKeyRef" => %{
                        "name" => config(:secret_name),
                        "key" => "GAMES_SERVER_API_KEY"
                      }
                    }
                  },
                  %{"name" => "PHX_API_BASE_URL", "value" => config(:hub_url)}
                ],
                "resources" => config(:resources)
              })
            ]
          }
        }
      }
    }
  end

  # DNS-1123: lowercase alphanumerics and hyphens, and a UUID already qualifies
  # once the prefix is added. Kept whole rather than truncated - a shortened id
  # can collide, and a collision here means two sims sharing one Job.
  defp job_name(sim_id), do: "holosim-" <> String.downcase(to_string(sim_id))

  defp namespace do
    config(:namespace) || Kubernetes.namespace()
  end

  defp config(key) do
    :phoenix_app
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default(key))
  end

  defp prune(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

  defp default(:image), do: nil
  defp default(:command), do: nil
  defp default(:image_pull_policy), do: "IfNotPresent"
  defp default(:namespace), do: nil
  defp default(:public_host), do: "127.0.0.1"
  defp default(:port_range), do: {7800, 7899}
  defp default(:ttl_seconds), do: 600
  defp default(:max_lifetime_seconds), do: 14_400
  defp default(:secret_name), do: "phoenix-secrets"
  defp default(:hub_url), do: "http://phoenix-web.phoenixapp.svc.cluster.local:4000"

  defp default(:resources),
    do: %{
      "requests" => %{"cpu" => "500m", "memory" => "1Gi"},
      "limits" => %{"cpu" => "2", "memory" => "4Gi"}
    }

  defp default(_), do: nil
end
