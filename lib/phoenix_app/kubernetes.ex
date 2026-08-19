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

  defp request(method, path, body) do
    with {:ok, token} <- File.read(Path.join(@sa_dir, "token")) do
      url = api_url() <> path

      headers = [
        {"Authorization", "Bearer " <> String.trim(token)},
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ]

      payload = if is_nil(body), do: "", else: Jason.encode!(body)

      options = [
        recv_timeout: @timeout,
        timeout: @timeout,
        ssl: [
          verify: :verify_peer,
          cacertfile: Path.join(@sa_dir, "ca.crt"),
          # Without this hackney checks the hostname against the cert, and the
          # in-cluster address is an IP while the cert is issued for
          # kubernetes.default.svc - so verification fails on a correct setup.
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ]

      case HTTPoison.request(method, url, payload, headers, options) do
        {:ok, %{status_code: status, body: raw}} ->
          {:ok, status, decode(raw)}

        {:error, %{reason: reason}} ->
          Logger.error("Kubernetes API #{method} #{path} failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, {:no_service_account, reason}}
    end
  end

  defp api_url do
    host = System.get_env("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
    port = System.get_env("KUBERNETES_SERVICE_PORT", "443")

    # Bracketed for IPv6 clusters, where a bare host:port is not a valid URL.
    host = if String.contains?(host, ":"), do: "[#{host}]", else: host

    "https://#{host}:#{port}"
  end

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
