defmodule PhoenixApp.Kubernetes do
  @moduledoc """
  A deliberately small Kubernetes API client, using the pod's own service account.

  ## Why not a Kubernetes library

  This needs to create a Job, ask whether it started, and delete it. Three verbs
  against one resource. A full client brings CRD handling, informers, watches and
  a dependency to keep current with the cluster - all to save the ~80 lines below.

  ## How it authenticates

  Every pod gets its service account projected into the filesystem: a token, the
  cluster CA, and the namespace it is running in. There is nothing to configure
  and no secret to rotate, and it works identically in k3s and in a managed
  cluster. Outside a pod those files are absent, which is what `in_cluster?/0`
  reports - and the launcher treats that as "orchestration unavailable" rather
  than falling back to something surprising.

  The CA is verified. It would be a line shorter to skip it, but this client
  holds a token that can create workloads in the namespace, and handing that to
  an unverified endpoint is how it stops being your cluster.
  """

  require Logger

  @sa_dir "/var/run/secrets/kubernetes.io/serviceaccount"
  @timeout 10_000

  @doc "True when running inside a pod with a usable service account."
  def in_cluster? do
    File.exists?(Path.join(@sa_dir, "token")) and
      not is_nil(System.get_env("KUBERNETES_SERVICE_HOST"))
  end

  @doc "The namespace this pod is running in, or nil outside a cluster."
  def namespace do
    case File.read(Path.join(@sa_dir, "namespace")) do
      {:ok, ns} -> String.trim(ns)
      _ -> nil
    end
  end

  @doc """
  Create a Job from a manifest map.

  Returns `{:ok, name}`. A 409 is reported as `{:error, :already_exists}` rather
  than as a failure, because the launcher names Jobs deterministically from the
  sim id - so a duplicate create means "this sim is already starting", which is
  a normal race between two players opening the same door, not an error.
  """
  def create_job(namespace, manifest) do
    case request(:post, "/apis/batch/v1/namespaces/#{namespace}/jobs", manifest) do
      {:ok, 201, body} ->
        {:ok, get_in(body, ["metadata", "name"])}

      {:ok, 409, _} ->
        {:error, :already_exists}

      {:ok, status, body} ->
        {:error, {:http, status, message_from(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Fetch a Job. `{:error, :not_found}` when it is gone."
  def get_job(namespace, name) do
    case request(:get, "/apis/batch/v1/namespaces/#{namespace}/jobs/#{name}", nil) do
      {:ok, 200, body} -> {:ok, body}
      {:ok, 404, _} -> {:error, :not_found}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a Job and the pods it owns.

  `propagationPolicy=Background` matters: without it the Job is removed and its
  pods are left running, which for a game server means an orphan process still
  holding its port and still heartbeating as if it were live.
  """
  def delete_job(namespace, name) do
    path = "/apis/batch/v1/namespaces/#{namespace}/jobs/#{name}?propagationPolicy=Background"

    case request(:delete, path, nil) do
      {:ok, status, _} when status in [200, 202] -> :ok
      {:ok, 404, _} -> :ok
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Jobs matching a label selector, e.g. `\"app=holosim\"`."
  def list_jobs(namespace, label_selector) do
    path =
      "/apis/batch/v1/namespaces/#{namespace}/jobs?labelSelector=" <>
        URI.encode_www_form(label_selector)

    case request(:get, path, nil) do
      {:ok, 200, body} -> {:ok, Map.get(body, "items", [])}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  # -------------------------------------------------------------------------
  # Deployments
  #
  # A SECOND WORKLOAD KIND, AND THE REASON IT IS NOT A JOB.
  #
  # Holo-sim instances are Jobs because they are ephemeral: they retire when
  # empty, must not restart by themselves, and want a TTL that cleans them up.
  # The world server is the opposite of every one of those. It is meant to stay
  # up for days, a crash is something you want recovered rather than
  # remembered, and "start" and "stop" are operations an admin performs rather
  # than a lifecycle it manages itself.
  #
  # That is exactly a Deployment: replicas 1 is running, replicas 0 is stopped,
  # and the object survives being stopped - so the admin screen can show a
  # world server that is deliberately down, rather than one that is merely
  # absent, which is a distinction a Job cannot express.
  # -------------------------------------------------------------------------

  @doc "Fetch a Deployment. `{:error, :not_found}` when it does not exist."
  def get_deployment(namespace, name) do
    case request(:get, "/apis/apps/v1/namespaces/#{namespace}/deployments/#{name}", nil) do
      {:ok, 200, body} -> {:ok, body}
      {:ok, 404, _} -> {:error, :not_found}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Create a Deployment. 409 is reported as `{:error, :already_exists}`."
  def create_deployment(namespace, manifest) do
    case request(:post, "/apis/apps/v1/namespaces/#{namespace}/deployments", manifest) do
      {:ok, 201, body} -> {:ok, get_in(body, ["metadata", "name"])}
      {:ok, 409, _} -> {:error, :already_exists}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Update an existing Deployment with a strategic merge patch.

  A PATCH rather than a PUT, and the difference matters: a replace has to carry
  a matching `resourceVersion` or the API rejects it, which turns every update
  into a read-modify-write with a retry loop. A strategic merge patch says only
  what changed and lets the API server merge it, so changing the image or the
  replica count is one call that cannot lose a concurrent edit to some other
  field.
  """
  def patch_deployment(namespace, name, patch) do
    path = "/apis/apps/v1/namespaces/#{namespace}/deployments/#{name}"

    case request(:patch, path, patch, content_type: "application/strategic-merge-patch+json") do
      {:ok, 200, body} -> {:ok, body}
      {:ok, 404, _} -> {:error, :not_found}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Delete a Deployment and the pods it owns. Missing counts as success."
  def delete_deployment(namespace, name) do
    path =
      "/apis/apps/v1/namespaces/#{namespace}/deployments/#{name}?propagationPolicy=Background"

    case request(:delete, path, nil) do
      {:ok, status, _} when status in [200, 202] -> :ok
      {:ok, 404, _} -> :ok
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Pods matching a label selector."
  def list_pods(namespace, label_selector) do
    path =
      "/api/v1/namespaces/#{namespace}/pods?labelSelector=" <>
        URI.encode_www_form(label_selector)

    case request(:get, path, nil) do
      {:ok, 200, body} -> {:ok, Map.get(body, "items", [])}
      {:ok, status, body} -> {:error, {:http, status, message_from(body)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Tail a pod's logs.

  Options: `:tail_lines`, `:container`, `:previous`, `:timestamps`.

  `:previous` reads the logs of the last TERMINATED container rather than the
  running one, which is the only way to see why something crash-looped - by the
  time an admin looks, the container that failed has already been replaced.

  Returns raw text. This endpoint does not answer JSON, and decoding it as
  though it did would either mangle the output or, on the day a log line
  happens to be a valid JSON object, silently turn it into a map.
  """
  def pod_logs(namespace, pod_name, opts \\ []) do
    query =
      [
        {"tailLines", Keyword.get(opts, :tail_lines, 200)},
        {"timestamps", Keyword.get(opts, :timestamps, true)},
        {"container", Keyword.get(opts, :container)},
        {"previous", Keyword.get(opts, :previous)}
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)

    path = "/api/v1/namespaces/#{namespace}/pods/#{pod_name}/log?" <> query

    case request(:get, path, nil, raw: true) do
      {:ok, 200, text} -> {:ok, text}
      {:ok, 404, _} -> {:error, :not_found}
      # A pod that has not started yet has no log to give, and the API says so
      # in a message worth passing through ("container is in waiting state").
      {:ok, status, text} -> {:error, {:http, status, text}}
      {:error, reason} -> {:error, reason}
    end
  end

  # -------------------------------------------------------------------------

  defp request(method, path, body, opts \\ []) do
    with {:ok, token} <- File.read(Path.join(@sa_dir, "token")) do
      url = api_url() <> path

      headers = [
        {"Authorization", "Bearer " <> String.trim(token)},
        {"Accept", "application/json"},
        # PATCH is the exception: Kubernetes decides which KIND of patch it has
        # been sent from the content type alone, so a strategic merge patch
        # posted as plain application/json is rejected as unsupported.
        {"Content-Type", Keyword.get(opts, :content_type, "application/json")}
      ]

      payload = if is_nil(body), do: "", else: Jason.encode!(body)

      options = [
        recv_timeout: @timeout,
        timeout: @timeout,
        ssl: [
          verify: :verify_peer,
          cacertfile: Path.join(@sa_dir, "ca.crt"),
          # SNI, and the reason the connection is made by DNS name at all - see
          # api_host/0. Without this hackney has no host to put in the
          # ClientHello, which some API server fronts (anything TLS-terminated
          # by a name-based proxy) need to pick the right certificate.
          server_name_indication: String.to_charlist(api_host()),
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ]

      case HTTPoison.request(method, url, payload, headers, options) do
        {:ok, %{status_code: status, body: raw}} ->
          # Log output is text/plain; everything else is JSON. See pod_logs/3.
          if Keyword.get(opts, :raw, false) do
            {:ok, status, raw}
          else
            {:ok, status, decode(raw)}
          end

        {:error, %{reason: reason}} ->
          Logger.error("Kubernetes API #{method} #{path} failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, {:no_service_account, reason}}
    end
  end

  # Deliberately NOT `System.get_env("KUBERNETES_SERVICE_HOST")`.
  #
  # That env var is the API server's ClusterIP - every pod gets it - and
  # connecting by IP is exactly what produced `bad_cert,unable_to_match_altnames`.
  # The serving certificate's SANs are DNS names (`kubernetes`,
  # `kubernetes.default`, `kubernetes.default.svc`, ...); whether an IP SAN is
  # also present depends on how the cluster's CA was built, and Erlang's
  # hostname verification does not treat "the reference ID looked like an IP"
  # as license to also try the cert's DNS SANs. Connect by the DNS name
  # instead: it is the SAN every Kubernetes API server certificate carries,
  # in-cluster CoreDNS resolves it to that same ClusterIP, and hostname
  # verification then has something to actually match against.
  defp api_host, do: "kubernetes.default.svc"

  defp api_port, do: System.get_env("KUBERNETES_SERVICE_PORT", "443")

  defp api_url, do: "https://#{api_host()}:#{api_port()}"

  defp decode(""), do: %{}

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, map} -> map
      _ -> %{"raw" => raw}
    end
  end

  # The API returns its own error shape; surfacing "message" gives an admin
  # something actionable ("jobs.batch is forbidden: ...") instead of a bare 403.
  defp message_from(%{"message" => message}), do: message
  defp message_from(other), do: inspect(other)
end
