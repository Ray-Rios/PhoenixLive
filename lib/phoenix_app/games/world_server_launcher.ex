defmodule PhoenixApp.Games.WorldServerLauncher do
  @moduledoc """
  Start, stop, inspect and tail the RaysSpaceSim WORLD server as a workload in
  the cluster - the thing `Scripts\\run_world_server.bat` does on a desktop.

  ## A Deployment, not a Job, and that is the whole design

  `InstanceLauncher` runs Holo-sims as Jobs, and every reason it does is a
  reason NOT to here:

  | Holo-sim instance | World server |
  |---|---|
  | Ephemeral - retires itself when empty | Meant to stay up for days |
  | Must never restart itself (it would reclaim the port with a fresh empty world) | A crash is something you want recovered |
  | `ttlSecondsAfterFinished` cleans it up | Nothing should clean it up |
  | Started by a player opening a door | Started by an admin pressing a button |

  A Deployment says all of that natively: replicas 1 is running, replicas 0 is
  stopped, and the object SURVIVES being stopped. That last part is what lets
  this screen distinguish "deliberately shut down" from "was never created",
  which a Job cannot express - a stopped Job is an absent Job.

  So `stop/0` scales to zero rather than deleting. `remove/0` exists for when
  you genuinely want it gone (changing the image, starting clean), and is the
  only operation here that throws away state.

  ## One image, two roles

  This uses the SAME container image as a Holo-sim instance. The difference is
  entirely in the arguments: an instance gets `-HoloSimId=`, and a world server
  does not. `Dockerfile.server` already notes this from the other direction -
  its ENTRYPOINT warning is that a server launched with no identity arguments
  "would come up as a world server and advertise itself as one", which is
  precisely what is wanted here.

  ## Its own namespace

  Configured to `raysspacesim` rather than sharing `phoenixapp`. Game servers
  parse untrusted network input for a living and are the workload most likely
  to be exploited; putting them in their own namespace means the blast radius
  of that is a namespace containing only game servers.

  The cost is RBAC: the hub's service account lives in `phoenixapp`, so it needs
  a Role and RoleBinding in `raysspacesim` (see `k3s/base/raysspacesim.yaml`),
  and the pod needs its own copy of the API-key Secret, because a Secret cannot
  be read across namespaces. Without either, every call here fails with a 403
  whose message names exactly what is missing - which is why `message_from/1`
  in the Kubernetes client passes the API's own wording through.
  """

  require Logger

  alias PhoenixApp.Kubernetes

  @label "rss-world"

  @doc """
  Can the world server actually be controlled from here?

  `{:error, reason}` rather than a bare false, because "not in a cluster" and
  "no image configured" need different things done about them and an admin
  screen showing a greyed-out button with no explanation helps nobody.
  """
  def available? do
    case unavailable_reason() do
      nil -> true
      _ -> false
    end
  end

  def unavailable_reason do
    cond do
      not Kubernetes.in_cluster?() -> :not_in_cluster
      is_nil(config(:image)) -> :no_image_configured
      true -> nil
    end
  end

  @doc """
  Bring the world server up.

  Creates the Deployment if it is absent, and otherwise patches the existing one
  back to one replica - so this doubles as "restart it with the current
  configuration" rather than needing a separate verb. `exec_cmds` are joined
  into a single `-ExecCmds=` exactly as `run_world_server.bat` does, which is
  the only way to give a dedicated server a console command: it has no
  interactive console, so commands can only be passed at launch.
  """
  def start(opts \\ []) do
    with :ok <- ensure_available() do
      ns = namespace()
      manifest = manifest(opts)

      # Before the Deployment, and deliberately not fatal - see ensure_service/1.
      # A world server with no Service is unreachable; a world server whose
      # Service failed to create is ALSO worth starting, because the pod logs
      # are then the fastest way to find out why.
      ensure_service(ns)

      case Kubernetes.create_deployment(ns, manifest) do
        {:ok, name} ->
          Logger.info("Created world server deployment #{name} in #{ns}")
          {:ok, :created}

        {:error, :already_exists} ->
          # Already there, possibly scaled to zero, possibly running an older
          # spec. Patch the whole thing rather than only the replica count so
          # pressing Start after changing the image does what it looks like it
          # does.
          case Kubernetes.patch_deployment(ns, deployment_name(), manifest) do
            {:ok, _} ->
              Logger.info("Started existing world server deployment in #{ns}")
              {:ok, :started}

            error ->
              log_error("start", error)
          end

        error ->
          log_error("start", error)
      end
    end
  end

  @doc """
  Scale to zero. The Deployment stays, so the screen can show it as stopped
  rather than gone, and Start brings it back without re-specifying anything.
  """
  def stop do
    with :ok <- ensure_available() do
      case Kubernetes.patch_deployment(namespace(), deployment_name(), %{
             "spec" => %{"replicas" => 0}
           }) do
        {:ok, _} -> {:ok, :stopped}
        {:error, :not_found} -> {:ok, :not_running}
        error -> log_error("stop", error)
      end
    end
  end

  @doc "Delete the Deployment outright. The one destructive operation here."
  def remove do
    with :ok <- ensure_available() do
      # The Service goes with it. Leaving one behind would hold the host port
      # bound with no pod behind it, so the next Start would look successful
      # and connect to nothing.
      _ = Kubernetes.delete_service(namespace(), service_name())

      case Kubernetes.delete_deployment(namespace(), deployment_name()) do
        :ok -> {:ok, :removed}
        error -> log_error("remove", error)
      end
    end
  end

  @doc """
  Everything the admin screen needs in one call.

  Always returns a map, never raises and never returns an error tuple: this is
  rendered on a page that refreshes every few seconds, and a screen whose job is
  to explain what is wrong must not be the thing that breaks when something is.
  Problems come back in `:error` as a readable string.
  """
  def status do
    base = %{
      available?: false,
      reason: unavailable_reason(),
      namespace: config(:namespace),
      deployment_name: deployment_name(),
      # Present from the start because read_status/1 uses map-update syntax,
      # which raises on a key the map does not already have.
      deployment: nil,
      state: :unknown,
      desired: 0,
      ready: 0,
      pods: [],
      error: nil,
      # What THIS pod would deploy if you pressed Start/Apply right now, versus
      # what the world Deployment is actually running. These can diverge for a
      # while after a build: HOLOSIM_IMAGE is only read from the environment
      # once, at boot (config/runtime.exs), so a pod that hasn't itself been
      # restarted since the ConfigMap changed will patch the Deployment with
      # the SAME image it already has - a genuine no-op that still returns
      # {:ok, :started}. Surfacing both values here is what makes that
      # otherwise-silent state visible instead of looking like a stuck button.
      configured_image: nil,
      running_image: nil,
      image_stale?: false
    }

    case unavailable_reason() do
      nil ->
        read_status(%{base | available?: true, namespace: namespace(), configured_image: config(:image)})

      _ ->
        base
    end
  end

  @doc """
  Tail the newest pod's logs.

  Newest rather than "the one" because during a restart there are briefly two,
  and the interesting one is always the one that just started. `previous: true`
  reads the container that died instead, which is the only way to see a crash
  loop's actual cause.
  """
  def logs(opts \\ []) do
    with :ok <- ensure_available() do
      case newest_pod() do
        nil ->
          {:error, :no_pod}

        pod ->
          name = get_in(pod, ["metadata", "name"])

          Kubernetes.pod_logs(namespace(), name,
            tail_lines: Keyword.get(opts, :tail_lines, 200),
            previous: if(Keyword.get(opts, :previous, false), do: true, else: nil),
            container: "world"
          )
      end
    end
  end

  # -------------------------------------------------------------------------

  defp ensure_available do
    case unavailable_reason() do
      nil -> :ok
      reason -> {:error, reason}
    end
  end

  defp log_error(what, {:error, reason} = error) do
    Logger.error("World server #{what} failed: #{inspect(reason)}")
    error
  end

  defp log_error(what, other) do
    Logger.error("World server #{what} failed: #{inspect(other)}")
    {:error, other}
  end

  defp read_status(base) do
    ns = base.namespace

    case Kubernetes.get_deployment(ns, deployment_name()) do
      {:ok, dep} ->
        desired = get_in(dep, ["spec", "replicas"]) || 0
        ready = get_in(dep, ["status", "readyReplicas"]) || 0
        running_image = container_image(dep)

        %{
          base
          | deployment: dep,
            desired: desired,
            ready: ready,
            state: state_of(desired, ready),
            pods: pod_summaries(ns),
            running_image: running_image,
            image_stale?: not is_nil(running_image) and running_image != base.configured_image
        }

      {:error, :not_found} ->
        %{base | state: :absent}

      {:error, reason} ->
        %{base | state: :error, error: describe(reason)}
    end
  end

  # DESIRED AND READY DISAGREEING IS THE INTERESTING STATE, not an edge case:
  # it is every image pull failure, every crash loop and every "the node has no
  # room" - all of which look identical from a bare replica count.
  defp state_of(0, _ready), do: :stopped
  defp state_of(desired, ready) when ready >= desired and desired > 0, do: :running
  defp state_of(_desired, _ready), do: :starting

  defp pod_summaries(ns) do
    case Kubernetes.list_pods(ns, "app=#{@label}") do
      {:ok, pods} -> Enum.map(pods, &pod_summary/1)
      _ -> []
    end
  end

  defp pod_summary(pod) do
    statuses = get_in(pod, ["status", "containerStatuses"]) || []
    first = List.first(statuses) || %{}

    %{
      name: get_in(pod, ["metadata", "name"]),
      phase: get_in(pod, ["status", "phase"]),
      started_at: get_in(pod, ["status", "startTime"]),
      restarts: Map.get(first, "restartCount", 0),
      ready?: Map.get(first, "ready", false),
      # WHY it is not running, when it is not. Kubernetes puts the useful
      # sentence ("ImagePullBackOff", "CrashLoopBackOff", the OOM kill) in the
      # container state rather than in the phase, so a screen that shows only
      # the phase says "Pending" forever and explains nothing.
      message: container_message(first)
    }
  end

  defp container_message(%{"state" => state}) when is_map(state) do
    Enum.find_value(state, fn {_kind, detail} ->
      case detail do
        %{"reason" => reason, "message" => message} -> "#{reason}: #{message}"
        %{"reason" => reason} -> reason
        _ -> nil
      end
    end)
  end

  defp container_message(_), do: nil

  # The Deployment's DESIRED image, i.e. what a rollout will converge pods
  # toward - not any one pod's current image, which can lag behind mid-rollout.
  defp container_image(dep) do
    dep
    |> get_in(["spec", "template", "spec", "containers"])
    |> List.wrap()
    |> Enum.find(&(&1["name"] == "world"))
    |> case do
      %{"image" => image} -> image
      _ -> nil
    end
  end

  defp newest_pod do
    case Kubernetes.list_pods(namespace(), "app=#{@label}") do
      {:ok, []} ->
        nil

      {:ok, pods} ->
        Enum.max_by(pods, &(get_in(&1, ["status", "startTime"]) || ""), fn -> nil end)

      _ ->
        nil
    end
  end

  defp describe({:http, status, message}), do: "HTTP #{status}: #{message}"
  defp describe(other), do: inspect(other)

  # -------------------------------------------------------------------------
  # The Service, and why the pod's hostPort is not enough
  #
  # `hostPort: 7777/UDP` binds on the NODE. On a cluster whose node is the
  # machine players reach, that is the whole story. Under Docker Desktop the
  # node is a Linux VM and the pod's hostPort is NOT published to the Windows
  # host: `netstat -an | findstr 7777` on the host shows nothing at all, so a
  # router forward to 7777 points at a port nobody is listening on. The client
  # then sends UDP for ten seconds and reports "no packets received yet", which
  # names neither the VM nor the missing binding.
  #
  # Docker Desktop DOES publish type: LoadBalancer Services on the host, which
  # is why this exists. NodePort would not do: its default range is
  # 30000-32767, so it cannot offer 7777 without reconfiguring the apiserver.
  #
  # The hostPort stays on the pod as well. It costs nothing on a single-node
  # cluster (its only real cost is pinning the pod to one node) and it is the
  # path that works on a normal cluster where the LoadBalancer type has no
  # controller behind it.
  # -------------------------------------------------------------------------

  defp ensure_service(ns) do
    manifest = service_manifest()

    result =
      case Kubernetes.create_service(ns, manifest) do
        {:ok, name} ->
          Logger.info("Created world server service #{name} in #{ns}")
          :ok

        # PATCH RATHER THAN LEAVE ALONE: an existing Service may be from an
        # older spec with a different port, and a stale port here is invisible -
        # the Service exists, the pod runs, and packets go nowhere.
        {:error, :already_exists} ->
          case Kubernetes.patch_service(ns, service_name(), manifest) do
            {:ok, _} -> :ok
            error -> error
          end

        error ->
          error
      end

    # NOT FATAL, ON PURPOSE. If the Service cannot be created - most likely the
    # RBAC in k3s/raysspacesim has not been re-applied since `services` was
    # added to the Role - starting the Deployment anyway means the admin screen
    # shows a running pod and this line in the log, which is a far better
    # position to debug from than a Start button that refuses with one error.
    case result do
      :ok -> :ok
      other -> log_error("service", other)
    end
  end

  defp service_manifest do
    port = config(:port)

    %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => %{
        "name" => service_name(),
        "namespace" => namespace(),
        "labels" => %{"app" => @label}
      },
      "spec" => %{
        "type" => "LoadBalancer",
        "selector" => %{"app" => @label},
        "ports" => [
          %{
            "name" => "game",
            "protocol" => "UDP",
            "port" => port,
            "targetPort" => port
          }
        ]
      }
    }
  end

  defp service_name, do: deployment_name()

  defp manifest(opts) do
    port = config(:port)

    %{
      "apiVersion" => "apps/v1",
      "kind" => "Deployment",
      "metadata" => %{
        "name" => deployment_name(),
        "namespace" => namespace(),
        "labels" => %{"app" => @label}
      },
      "spec" => %{
        "replicas" => 1,
        "selector" => %{"matchLabels" => %{"app" => @label}},

        # RECREATE, NOT ROLLING. The default rolling strategy starts the new pod
        # before stopping the old one, and both would bind the same hostPort -
        # so the replacement sits Pending forever while the outgoing one refuses
        # to leave. Recreate is also what you actually want for a world: one
        # server, not two briefly serving different copies of it.
        "strategy" => %{"type" => "Recreate"},
        "template" => %{
          "metadata" => %{"labels" => %{"app" => @label}},
          "spec" => %{
            "restartPolicy" => "Always",
            "containers" => [
              prune(%{
                "name" => "world",
                "image" => config(:image),
                "imagePullPolicy" => config(:image_pull_policy),
                "command" => config(:command),
                "args" => args(port, opts),
                "ports" => [
                  %{
                    # hostPort for the same reason instances use one: a game
                    # client speaks UDP straight to the node and cannot be
                    # routed through the HTTP ingress. It pins the world server
                    # to one node, which is correct for single-node k3s and is
                    # the first thing to revisit when it stops being that.
                    "containerPort" => port,
                    "hostPort" => port,
                    "protocol" => "UDP"
                  }
                ],
                "env" => [
                  # No env var for the hub URL, deliberately - see args/2.
                  # UPhxAccountSettings never calls FPlatformMisc::GetEnvironmentVariable
                  # for it, only for ServerApiKeyEnvVar below.
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

  # Mirrors run_world_server.bat, minus the two things the container handles
  # itself: the editor binary (the image's ENTRYPOINT is RSSServer.sh, already
  # a server target) and -PhxServerApiKey, which arrives as an env var from a
  # Secret rather than on a command line where it would show up in `kubectl
  # describe` and in every pod listing.
  defp args(port, opts) do
    exec = Keyword.get(opts, :exec_cmds, []) |> Enum.reject(&(&1 in [nil, ""]))

    base = [
      config(:map),
      "-stdout",
      "-UTF8Output",
      "-Port=#{port}",
      "-PhxHost=#{config(:public_host)}",
      "-PhxPort=#{config(:public_port) || port}",
      # UPhxAccountSettings::GetNormalizedBaseUrl only ever reads -PhxBaseUrl=
      # off the command line (falling back to whatever BaseUrl was baked into
      # DefaultGame.ini at cook time) - there is no environment-variable path
      # for the hub URL, only for the API key (ServerApiKeyEnvVar). Without
      # this the world server talks to whatever hub happened to be configured
      # in the image it was cooked from, which silently breaks the moment that
      # image runs anywhere else - exactly the "Could not resolve host: api"
      # failure this line exists to prevent.
      #
      # UNQUOTED, deliberately, unlike the batch-file version of this flag. The
      # `"..."` in run_world_server.bat protects the URL from THAT shell; this
      # array is handed straight to the container's ENTRYPOINT as argv with no
      # shell in between; adding quote characters here would make them literal
      # bytes in the value UE parses instead of syntax that gets stripped.
      "-PhxBaseUrl=#{config(:hub_url)}"
    ]

    # Joined with commas into ONE -ExecCmds=, which is the form UE parses.
    case exec do
      [] -> base
      cmds -> base ++ ["-ExecCmds=#{Enum.join(cmds, ",")}"]
    end
  end

  defp deployment_name, do: config(:deployment_name)

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
  defp default(:namespace), do: "raysspacesim"
  defp default(:deployment_name), do: "rss-world-server"
  defp default(:map), do: "Cosmos"
  defp default(:port), do: 7777
  defp default(:public_host), do: "127.0.0.1"
  defp default(:public_port), do: nil
  defp default(:secret_name), do: "raysspacesim-secrets"
  # PORT 80, NOT 4000. 4000 is what the CONTAINER listens on; the Service in
  # front of it publishes `port: 80, targetPort: 4000` (k3s/base/phoenix-deployment.yaml,
  # and overlays/prod/service-patch.yaml keeps it that way). A Service has no
  # port 4000 at all, so :4000 here does not get refused - kube-proxy has no
  # endpoint to send it to, the packets go nowhere, and the server sits there
  # until UE gives up: "HTTP request timed out after 15.00 seconds". A timeout
  # rather than a refusal is the tell that the name resolved and the port did
  # not exist.
  defp default(:hub_url), do: "http://phoenix-web.phoenixapp.svc.cluster.local"

  defp default(:resources),
    do: %{
      "requests" => %{"cpu" => "500m", "memory" => "1Gi"},
      "limits" => %{"cpu" => "2", "memory" => "4Gi"}
    }

  defp default(_), do: nil
end
