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

  ## Every instance gets its own LoadBalancer Service (2026-10-08)

  Until 2026-10-08 an instance had only a pod `hostPort`, and was unreachable.
  Under Docker Desktop the node is a Linux VM and a hostPort is never published
  to the Windows host - §5b cause #11, fixed for the world server on 2026-08-22
  and never carried over here. The instance booted, heartbeated, was reported
  `ready` at `phxlive.net:78xx`, and the client sent UDP into nothing for two
  minutes ("Initial Connect Diagnostics ... no packets received yet") while the
  instance sat empty, hit its 60 s idle shutdown and exited. Nothing anywhere
  said why.

  `holosim-<sim id>-<port>` is created right after the Job, owned by it
  (ownerReferences), so the Job's TTL cleanup takes the Service with it. A
  Service that cannot be created FAILS THE LAUNCH and deletes the Job: an
  instance with no Service is exactly the silent failure this replaced.

  ## A finished Job is replaced, not reported as "already starting"

  The Job outlives its process by `ttl_seconds` (600). A sim reopened inside
  that window used to hit 409 on create, which was reported as
  `:already_starting`, and the player polled a dead Job until the door timed
  out. A finished Job is now deleted and recreated.
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

  @doc """
  Delete an instance's Job, its pod and its Service(s). Idempotent.

  The Services are deleted explicitly as well as by owner-reference garbage
  collection, because GC is asynchronous and a relaunch straight after this
  must not find the old Service still holding the port.
  """
  def terminate(sim_id) do
    with true <- Kubernetes.in_cluster?(),
         ns when is_binary(ns) <- namespace() do
      job_result = Kubernetes.delete_job(ns, job_name(sim_id))
      _ = delete_services_for(ns, sim_id)
      job_result
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

  @doc """
  Everything the admin screen needs about instances in the cluster, one map per
  Job: which sim, which port, what the pod is doing and why, and whether its
  Service has actually been published.

  `{:ok, list}`, or `{:error, reason}` when the cluster could not be asked.
  Outside a cluster it is `{:ok, []}` - nothing to show is the honest answer.
  """
  def list_instances do
    with true <- Kubernetes.in_cluster?(),
         ns when is_binary(ns) <- namespace(),
         {:ok, jobs} <- Kubernetes.list_jobs(ns, "app=#{@label}") do
      pods = by_sim(Kubernetes.list_pods(ns, "app=#{@label}"))
      services = by_sim(Kubernetes.list_services(ns, "app=#{@label}"))

      instances =
        jobs
        |> Enum.map(fn job ->
          sim_id = get_in(job, ["metadata", "labels", "holo-sim-id"])
          pod = Map.get(pods, sim_id)
          service = Map.get(services, sim_id)

          %{
            sim_id: sim_id,
            job_name: get_in(job, ["metadata", "name"]),
            port: port_label(job),
            created_at: get_in(job, ["metadata", "creationTimestamp"]),
            finished?: job_finished?(job),
            succeeded?: (get_in(job, ["status", "succeeded"]) || 0) > 0,
            pod_name: pod && get_in(pod, ["metadata", "name"]),
            pod_phase: pod && get_in(pod, ["status", "phase"]),
            pod_detail: pod && pod_detail(pod),
            service_name: service && get_in(service, ["metadata", "name"]),
            service_published?:
              not is_nil(service) and
                (get_in(service, ["status", "loadBalancer", "ingress"]) || []) != []
          }
        end)
        |> Enum.sort_by(& &1.created_at, :desc)

      {:ok, instances}
    else
      false -> {:ok, []}
      nil -> {:ok, []}
      {:error, _} = error -> error
    end
  end

  @doc "Tail the logs of a sim's instance pod."
  def logs(sim_id, opts \\ []) do
    with true <- Kubernetes.in_cluster?(),
         ns when is_binary(ns) <- namespace(),
         {:ok, pods} <- Kubernetes.list_pods(ns, "app=#{@label},holo-sim-id=#{sim_id}") do
      case Enum.max_by(pods, &get_in(&1, ["metadata", "creationTimestamp"]), fn -> nil end) do
        nil -> {:error, :no_pod}
        pod -> Kubernetes.pod_logs(ns, get_in(pod, ["metadata", "name"]), opts)
      end
    else
      false -> {:error, :not_in_cluster}
      nil -> {:error, :not_in_cluster}
      {:error, _} = error -> error
    end
  end

  # -------------------------------------------------------------------------

  defp do_launch(game, sim, user_id) do
    ns = namespace()

    case Kubernetes.get_job(ns, job_name(sim.id)) do
      {:error, :not_found} ->
        create_instance(game, sim, user_id, ns, false)

      {:ok, job} ->
        if job_finished?(job) do
          # A Job kept around by its TTL after the instance retired. Its name
          # blocks a new create, and it will never heartbeat again - so it is
          # replaced, not waited on. See the moduledoc.
          Logger.info("Holo-sim #{sim.id}: previous instance has finished; replacing it")
          _ = terminate(sim.id)
          create_instance(game, sim, user_id, ns, true)
        else
          # Not a failure. Deterministic naming is what makes a simultaneous
          # double-open produce one world.
          Logger.info("Holo-sim #{sim.id} is already starting")
          {:ok, :already_starting}
        end

      {:error, reason} = error ->
        Logger.error("Holo-sim #{sim.id}: could not read its Job: #{inspect(reason)}")
        error
    end
  end

  # A background-propagated delete returns before the Job object is gone, so a
  # create straight after it can still 409. When we have just deleted a finished
  # Job, a 409 means "not gone yet", not "someone else is starting it" - retry
  # for a few seconds rather than reporting a launch that is not happening.
  @replace_attempts 6
  @replace_wait_ms 750

  defp create_instance(game, sim, user_id, ns, replacing?, attempt \\ 1) do
    with {:ok, port} <- allocate_port(game.id, ns) do
      case Kubernetes.create_job(ns, manifest(sim, user_id, port, ns)) do
        {:ok, name} ->
          Logger.info("Launched Holo-sim instance #{name} on port #{port}")
          expose(ns, sim, name, port)

        {:error, :already_exists} when replacing? and attempt < @replace_attempts ->
          Process.sleep(@replace_wait_ms)
          create_instance(game, sim, user_id, ns, replacing?, attempt + 1)

        {:error, :already_exists} when replacing? ->
          {:error, :previous_instance_ending}

        {:error, :already_exists} ->
          Logger.info("Holo-sim #{sim.id} is already starting")
          {:ok, :already_starting}

        {:error, reason} = error ->
          Logger.error("Failed to launch Holo-sim #{sim.id}: #{inspect(reason)}")
          error
      end
    else
      {:error, :no_free_port} = error ->
        Logger.error("No free instance port for Holo-sim #{sim.id}")
        error

      {:error, reason} = error ->
        Logger.error("Holo-sim #{sim.id}: could not allocate a port: #{inspect(reason)}")
        error
    end
  end

  # FATAL ON FAILURE, unlike the world server's ensure_service. A world server
  # without a Service is something an admin is looking at; an instance without
  # one is a player at a door being told "ready" for a world they can never
  # reach. Delete the Job and say so instead.
  defp expose(ns, sim, job_name, port) do
    result =
      with {:ok, job} <- Kubernetes.get_job(ns, job_name),
           uid when is_binary(uid) <- get_in(job, ["metadata", "uid"]) || {:error, :no_job_uid} do
        Kubernetes.create_service(ns, service_manifest(sim, job_name, uid, port, ns))
      end

    case result do
      {:ok, name} ->
        Logger.info("Exposed Holo-sim #{sim.id} via Service #{name} on UDP #{port}")
        {:ok, :started}

      # Same name means same sim AND same port, and allocate_port skips ports
      # an existing Service holds - so this is a leftover from a terminate
      # whose delete has not landed. Replace it rather than trust its owner.
      {:error, :already_exists} ->
        _ = Kubernetes.delete_service(ns, service_name(sim.id, port))
        Process.sleep(@replace_wait_ms)

        case Kubernetes.create_service(ns, service_manifest(sim, job_name, nil, port, ns)) do
          {:ok, _} -> {:ok, :started}
          error -> expose_failed(ns, sim, job_name, error)
        end

      error ->
        expose_failed(ns, sim, job_name, error)
    end
  end

  defp expose_failed(ns, sim, job_name, error) do
    Logger.error(
      "Holo-sim #{sim.id}: could not create its Service, deleting the Job: #{inspect(error)}"
    )

    _ = Kubernetes.delete_job(ns, job_name)

    case error do
      {:error, reason} -> {:error, {:service, reason}}
      other -> {:error, {:service, other}}
    end
  end

  defp service_manifest(sim, job_name, job_uid, port, ns) do
    owner =
      if job_uid do
        [
          %{
            "apiVersion" => "batch/v1",
            "kind" => "Job",
            "name" => job_name,
            "uid" => job_uid,
            "controller" => false,
            "blockOwnerDeletion" => false
          }
        ]
      end

    %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" =>
        prune(%{
          "name" => service_name(sim.id, port),
          "namespace" => ns,
          "labels" => %{
            "app" => @label,
            "holo-sim-id" => to_string(sim.id),
            "holo-sim-port" => to_string(port)
          },
          "ownerReferences" => owner
        }),
      "spec" => %{
        "type" => "LoadBalancer",
        "selector" => %{"app" => @label, "holo-sim-id" => to_string(sim.id)},
        "ports" => [
          %{"name" => "game", "protocol" => "UDP", "port" => port, "targetPort" => port}
        ]
      }
    }
  end

  defp delete_services_for(ns, sim_id) do
    case Kubernetes.list_services(ns, "app=#{@label},holo-sim-id=#{sim_id}") do
      {:ok, services} ->
        Enum.each(services, fn svc ->
          Kubernetes.delete_service(ns, get_in(svc, ["metadata", "name"]))
        end)

      error ->
        error
    end
  end

  defp job_finished?(job) do
    status = Map.get(job, "status", %{})

    (status["succeeded"] || 0) > 0 or (status["failed"] || 0) > 0 or
      Enum.any?(status["conditions"] || [], fn c ->
        c["type"] in ["Complete", "Failed"] and c["status"] == "True"
      end)
  end

  defp port_label(obj) do
    case get_in(obj, ["metadata", "labels", "holo-sim-port"]) do
      nil -> nil
      p -> String.to_integer(p)
    end
  rescue
    ArgumentError -> nil
  end

  # Newest object per sim id, from a list_* result. A failed listing degrades to
  # "unknown" on the admin screen rather than blanking the whole panel.
  defp by_sim({:ok, items}) do
    items
    |> Enum.sort_by(&get_in(&1, ["metadata", "creationTimestamp"]))
    |> Map.new(&{get_in(&1, ["metadata", "labels", "holo-sim-id"]), &1})
  end

  defp by_sim(_), do: %{}

  # The one-line answer to "why is this pod not running": ImagePullBackOff,
  # CreateContainerConfigError (the Secret), OOMKilled, exit 1...
  defp pod_detail(pod) do
    state =
      pod
      |> get_in(["status", "containerStatuses"])
      |> List.wrap()
      |> List.first()
      |> case do
        nil -> %{}
        cs -> Map.get(cs, "state", %{})
      end

    cond do
      w = state["waiting"] ->
        Enum.join(Enum.reject([w["reason"], w["message"]], &is_nil/1), ": ")

      t = state["terminated"] ->
        "#{t["reason"]} (exit #{t["exitCode"]})"

      true ->
        pod
        |> get_in(["status", "conditions"])
        |> List.wrap()
        |> Enum.find(&(&1["status"] == "False" and &1["message"]))
        |> case do
          nil -> nil
          c -> c["message"]
        end
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
  # milliseconds, and the failure is visible in the admin section as a Job with
  # no heartbeat.
  #
  # ALSO SKIPS PORTS A JOB OR SERVICE STILL HOLDS (2026-10-08). The heartbeat
  # table alone is not enough: an instance that is still booting has not
  # heartbeated yet, and a finished one's Service keeps its host port published
  # for up to ttl_seconds. Fails CLOSED if the cluster cannot be listed - a
  # guessed port that collides produces an unreachable instance and no error.
  defp allocate_port(game_id, ns) do
    {from, to} = config(:port_range)

    with {:ok, jobs} <- Kubernetes.list_jobs(ns, "app=#{@label}"),
         {:ok, services} <- Kubernetes.list_services(ns, "app=#{@label}") do
      heartbeating =
        game_id
        |> Games.list_servers_for_admin()
        |> Enum.reject(&Games.server_stale?/1)
        |> Enum.map(& &1.port)

      held =
        (jobs ++ services)
        |> Enum.map(&port_label/1)
        |> Enum.reject(&is_nil/1)

      taken = MapSet.new(heartbeating ++ held)

      case Enum.find(from..to, &(not MapSet.member?(taken, &1))) do
        nil -> {:error, :no_free_port}
        port -> {:ok, port}
      end
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
          "holo-sim-id" => to_string(sim.id),
          # Read back by allocate_port and the admin screen. A label rather
          # than digging the port out of the pod spec, so a listing answers it.
          "holo-sim-port" => to_string(port)
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
                  "-Port=#{port}",
                  # UPhxAccountSettings::GetNormalizedBaseUrl only ever reads
                  # -PhxBaseUrl= off the command line (or the ini baked in at cook
                  # time) - there is no environment-variable path for it. Without
                  # this the instance talks to whatever hub was baked into the
                  # image, which is wrong the moment that image gets deployed
                  # anywhere else. Left UNQUOTED: this list is handed straight to
                  # the container's ENTRYPOINT as argv, no shell in between, so
                  # literal `"` characters would become part of the value instead
                  # of being stripped the way they are in run_world_server.bat.
                  "-PhxBaseUrl=#{config(:hub_url)}"
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
                  #
                  # No env var for the hub URL: FPlatformMisc::GetEnvironmentVariable
                  # is only ever called for ServerApiKeyEnvVar. The hub address goes
                  # in as -PhxBaseUrl= above instead, which is what the plugin
                  # actually reads.
                  %{
                    "name" => "PHX_GAMES_SERVER_API_KEY",
                    "valueFrom" => %{
                      "secretKeyRef" => %{
                        "name" => config(:secret_name),
                        "key" => "GAMES_SERVER_API_KEY"
                      }
                    }
                  }
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

  # 8 + 36 + 1 + up to 5 = 50 characters, inside the 63 a Service name allows.
  # The port is in the name so a replacement instance on a new port never
  # collides with its predecessor's Service while that one is being deleted.
  defp service_name(sim_id, port), do: "#{job_name(sim_id)}-#{port}"

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
  # raysspacesim, beside the world server, since 2026-10-08. Instances parse
  # untrusted network input exactly as the world server does; they used to run
  # in the hub's own namespace next to Postgres. See k3s/raysspacesim.
  defp default(:namespace), do: "raysspacesim"
  defp default(:public_host), do: "127.0.0.1"
  defp default(:port_range), do: {7800, 7899}
  defp default(:ttl_seconds), do: 600
  defp default(:max_lifetime_seconds), do: 14_400
  # Secrets do not cross namespaces: this is the raysspacesim copy, the one the
  # world server already reads.
  defp default(:secret_name), do: "raysspacesim-secrets"
  # PORT 80, NOT 4000 - see the same default in WorldServerLauncher. 4000 is the
  # container port; the Service publishes 80 and targets 4000, so :4000 has no
  # Service port to land on and times out rather than being refused.
  defp default(:hub_url), do: "http://phoenix-web.phoenixapp.svc.cluster.local"

  defp default(:resources),
    do: %{
      "requests" => %{"cpu" => "500m", "memory" => "1Gi"},
      "limits" => %{"cpu" => "2", "memory" => "4Gi"}
    }

  defp default(_), do: nil
end
