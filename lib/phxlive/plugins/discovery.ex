defmodule Phxlive.Plugins.Discovery do
  @moduledoc """
  Finds installed plugins by scanning `plugins/*/` in the source tree. Used at
  COMPILE time only (by `Phxlive.Plugins` and the router): a release does not
  ship the source tree, so nothing may call this at runtime in production.

  Each folder whose name is a valid slug is a plugin, and its main module is
  `<Camelized slug>.Plugin` (`plugins/web_lobby` -> `WebLobby.Plugin`).
  Folders that don't match (e.g. `_template`, `README.md`) are ignored.
  """

  # lib/phxlive/plugins/discovery.ex -> project root
  @root Path.expand("../../..", __DIR__)

  def root, do: @root
  def plugins_dir, do: Path.join(@root, "plugins")

  @doc "[%{slug, dir, module}] for every plugin folder, sorted by slug."
  def discover do
    plugins_dir()
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(fn dir -> {Path.basename(dir), dir} end)
    |> Enum.filter(fn {slug, _} -> Regex.match?(Phxlive.Plugin.slug_format(), slug) end)
    |> Enum.sort()
    |> Enum.map(fn {slug, dir} ->
      %{slug: slug, dir: dir, module: Module.concat([Macro.camelize(slug), "Plugin"])}
    end)
  end

  def slugs, do: Enum.map(discover(), & &1.slug)
end
