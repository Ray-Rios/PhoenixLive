defmodule PhoenixApp.CodeMap do
  @moduledoc """
  The RaysSpaceSim code map: where the snapshot comes from, how old it is, and
  whether it still describes the build that is running.

  ## The pod cannot generate this

  `/admin/raysspacesim/codebase` renders a parse of the game's C++ headers. The
  game is a separate repository, gitignored by PhxLive, and absent from the web
  image - so nothing in the cluster has a header to parse. The map travels as
  data: `priv/codemap/extract.py` runs on a machine that has the game repo
  (`./deploy-game.sh` does it after every cook) and writes
  `priv/codemap/codemap.json`, which the next `./deploy-prod.sh` bakes into the
  image.

  That is the whole pipeline, and it has one honest consequence: **a button on
  an admin page cannot regenerate the map.** There is no repo to read and no
  Python to read it with. What the page can do is the two things this module
  exists for - say precisely how stale the snapshot is, and accept a newer one.

  ## Two places a snapshot can live

    * **baked** - `priv/codemap/codemap.json` inside the release. Arrives with a
      deploy, cannot be written to meaningfully (a release directory is rebuilt
      from scratch every time), always present.

    * **override** - a file uploaded through the admin page. Takes precedence
      when it exists, so a map can be refreshed between deploys. `discard/0`
      puts the baked copy back.

  ## An override lives in one pod and dies with it, on purpose

  The obvious home for it was the uploads PVC, which is already mounted and
  already persistent. It is the wrong home: `PhoenixAppWeb.Endpoint` serves the
  whole of `/app/uploads` through `Plug.Static` at `/uploads` with no `:only`
  filter, so a code map written anywhere under it - including a subdirectory,
  including a `subPath` mount of the same volume - is published at a guessable
  URL, unauthenticated. Every class name, every function signature and every
  source path in a private codebase, downloadable by anyone who guesses
  `/uploads/codemap/codemap.json`.

  Giving it a PVC of its own would have meant a new PersistentVolume bound to a
  host directory, which is real operational weight for a convenience. So the
  override goes to a container-local directory and is deliberately not durable:
  it holds until the pod restarts, then the baked snapshot takes over again.

  That is the honest shape of the feature. The durable way to refresh the map is
  and remains `./deploy-game.sh --codemap` followed by `./deploy-prod.sh`; an
  upload is how you skip the wait in between. The admin page says exactly this
  rather than implying an upload is permanent.

  `CODEMAP_DIR` overrides the directory, for the day one of these does get a
  volume of its own. Point it anywhere `Plug.Static` does not serve.
  """

  require Logger

  alias PhoenixApp.Games.WorldServerLauncher

  @filename "codemap.json"

  # Keys the page reads. A file missing these parses fine and renders an empty
  # screen, which is the failure mode most likely to be mistaken for "the code
  # map is broken" rather than "that was the wrong file".
  @required_keys ~w(modules deps replication_index generated_from)

  # 8 MB. The real file is about 1 MB and grows with the codebase; this is a
  # bound on what an admin upload may spend memory on, not a size the map is
  # expected to approach.
  @max_bytes 8 * 1024 * 1024

  # ---------------------------------------------------------------------------
  # Paths
  # ---------------------------------------------------------------------------

  @doc "The snapshot that shipped with the release."
  def baked_path, do: Application.app_dir(:phoenix_app, "priv/codemap/#{@filename}")

  @doc """
  Directory for an uploaded override.

  Container-local by default and therefore not durable - see the moduledoc for
  why that is the deliberate choice and not an oversight. `CODEMAP_DIR` moves
  it, but never to anywhere `Plug.Static` serves.
  """
  def override_dir do
    case System.get_env("CODEMAP_DIR") do
      nil -> Path.join(System.tmp_dir!(), "phoenix_app_codemap")
      "" -> Path.join(System.tmp_dir!(), "phoenix_app_codemap")
      dir -> dir
    end
  end

  def override_path, do: Path.join(override_dir(), @filename)

  # ---------------------------------------------------------------------------
  # Reading
  # ---------------------------------------------------------------------------

  @doc """
  The map itself, override first.

  Returns `{:ok, map, source}` where source is `:override` or `:baked`.
  """
  def read do
    with {:error, _} <- read_from(override_path(), :override) do
      read_from(baked_path(), :baked)
    end
  end

  defp read_from(path, source) do
    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do
      {:ok, json, source}
    else
      {:error, %Jason.DecodeError{} = e} ->
        {:error, "#{path} is not valid JSON: #{Exception.message(e)}"}

      {:error, :enoent} ->
        {:error, :enoent}

      {:error, reason} ->
        {:error, "Could not read #{path}: #{:file.format_error(reason)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Status
  #
  # Called on the admin page's 5-second tick, so it must not parse a megabyte of
  # JSON every time. It stats both files - microseconds - and reuses the last
  # parse unless mtime or size moved. The cache key is the file's identity, so a
  # regenerated map is picked up on the next tick with no invalidation call and
  # no way for the two to disagree.
  # ---------------------------------------------------------------------------

  @doc """
  Everything the admin card renders, cheap enough to call on a timer.
  """
  def status do
    override = describe(override_path(), :override)
    baked = describe(baked_path(), :baked)

    # THE SAME CHOICE read/0 MAKES, or the card describes a file the page is not
    # using. read/0 falls through a corrupt override to the baked copy; if this
    # picked the override regardless, the card would report a commit and a
    # class count that nothing on screen came from.
    active = if override && override.readable?, do: override, else: baked

    live = live_image()
    live_tag = image_tag(live)
    snapshot_commit = active && active.game_commit

    %{
      active: active,
      override: override,
      baked: baked,
      override_dir: override_dir(),
      live_image: live,
      live_tag: live_tag,
      # nil means "cannot tell", which is a different answer from "they differ"
      # and has to stay distinguishable: no live image configured, or a snapshot
      # from before extract.py recorded a commit.
      matches_live?: compare(snapshot_commit, live_tag)
    }
  end

  defp compare(nil, _), do: nil
  defp compare(_, nil), do: nil
  defp compare(commit, tag), do: String.starts_with?(tag, commit)

  defp describe(path, source) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{type: :regular, size: size, mtime: mtime}} ->
        provenance(path, size, mtime)
        |> Map.merge(%{source: source, path: path, size: size, mtime: mtime})

      _ ->
        nil
    end
  end

  defp provenance(path, size, mtime) do
    # ONE KEY PER PATH, NOT ONE PER VERSION.
    #
    # Putting size and mtime in the key would mean a new persistent_term entry
    # for every deploy and every upload, none of which is ever removed - and
    # each :persistent_term.put/2 scans every process heap. Two fixed keys that
    # get overwritten cost the same scan but do not accumulate.
    key = {__MODULE__, :provenance, path}

    case :persistent_term.get(key, nil) do
      {^size, ^mtime, cached} ->
        cached

      _ ->
        computed = parse_provenance(path)
        :persistent_term.put(key, {size, mtime, computed})
        computed
    end
  end

  defp parse_provenance(path) do
    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do
      modules = Map.get(json, "modules", [])
      classes = Enum.flat_map(modules, &Map.get(&1, "classes", []))

      %{
        readable?: true,
        error: nil,
        generated_from: Map.get(json, "generated_from"),
        generated_at: Map.get(json, "generated_at"),
        game_commit: Map.get(json, "game_commit") || commit_from(Map.get(json, "generated_from")),
        game_dirty: Map.get(json, "game_dirty"),
        modules: length(modules),
        classes: length(classes),
        functions: Enum.sum(Enum.map(classes, &length(Map.get(&1, "functions", [])))),
        properties: Enum.sum(Enum.map(classes, &length(Map.get(&1, "properties", [])))),
        replicated:
          json
          |> Map.get("replication_index", %{})
          |> Enum.map(fn {_cls, props} -> map_size(props) end)
          |> Enum.sum()
      }
    else
      {:error, reason} ->
        %{
          readable?: false,
          error: describe_error(reason),
          generated_from: nil,
          generated_at: nil,
          game_commit: nil,
          game_dirty: nil,
          modules: 0,
          classes: 0,
          functions: 0,
          properties: 0,
          replicated: 0
        }
    end
  end

  # Snapshots written before extract.py recorded game_commit have the sha only
  # inside the human-readable string. Recovering it there keeps the staleness
  # check working across the upgrade instead of reading "unknown" until the next
  # regeneration.
  defp commit_from(nil), do: nil

  defp commit_from(text) when is_binary(text) do
    case Regex.run(~r/@\s*([0-9a-f]{7,40})/, text) do
      [_, sha] -> sha
      _ -> nil
    end
  end

  defp commit_from(_), do: nil

  defp describe_error(%Jason.DecodeError{} = e), do: "not valid JSON: " <> Exception.message(e)
  defp describe_error(reason) when is_atom(reason), do: :file.format_error(reason) |> to_string()
  defp describe_error(other), do: inspect(other)

  defp live_image do
    :phoenix_app
    |> Application.get_env(WorldServerLauncher, [])
    |> Keyword.get(:image)
  end

  # "raysspacesim-server:6154931" -> "6154931". A dirty build's tag carries a
  # timestamp too ("6154931-dirty-202608220414"), which still starts with the
  # sha, so the prefix comparison in compare/2 holds for both.
  defp image_tag(nil), do: nil

  defp image_tag(image) when is_binary(image) do
    case String.split(image, ":") do
      [_repo, tag] -> tag
      [_registry, _repo, tag] -> tag
      _ -> nil
    end
  end

  defp image_tag(_), do: nil

  # ---------------------------------------------------------------------------
  # Accepting a newer snapshot
  # ---------------------------------------------------------------------------

  @doc """
  Validate a candidate snapshot and install it as the override.

  Everything is checked before anything is written, so a rejected upload leaves
  the previous map exactly where it was. The alternative - copy first, discover
  it is a PNG on the next mount - takes the page down until someone finds this
  module.
  """
  def install(tmp_path) do
    with {:ok, %File.Stat{size: size}} when size <= @max_bytes <- File.stat(tmp_path),
         {:ok, body} <- File.read(tmp_path),
         {:ok, json} <- Jason.decode(body),
         :ok <- validate(json),
         :ok <- File.mkdir_p(override_dir()),
         :ok <- File.write(override_path(), body) do
      Logger.info("codemap: installed override from #{Map.get(json, "generated_from")}")
      {:ok, Map.get(json, "generated_from")}
    else
      {:ok, %File.Stat{size: size}} ->
        {:error, "That file is #{div(size, 1024)} KB; the limit is #{div(@max_bytes, 1024)} KB."}

      {:error, %Jason.DecodeError{}} ->
        {:error, "That is not JSON. Upload the codemap.json that extract.py wrote."}

      {:error, {:missing, keys}} ->
        {:error,
         "JSON, but not a code map - it has no #{Enum.join(keys, ", ")}. " <>
           "Regenerate with ./deploy-game.sh --codemap."}

      {:error, reason} ->
        {:error, describe_error(reason)}
    end
  end

  defp validate(json) when is_map(json) do
    case Enum.reject(@required_keys, &Map.has_key?(json, &1)) do
      [] -> :ok
      missing -> {:error, {:missing, missing}}
    end
  end

  defp validate(_), do: {:error, {:missing, @required_keys}}

  @doc """
  Delete the override so the baked snapshot is authoritative again.
  """
  def discard do
    case File.rm(override_path()) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, describe_error(reason)}
    end
  end
end
