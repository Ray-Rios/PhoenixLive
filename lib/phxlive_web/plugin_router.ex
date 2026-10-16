defmodule PhxliveWeb.PluginRouter do
  @moduledoc """
  Expands every installed plugin's routes inside `PhxliveWeb.Router` at compile
  time (PHXLIVE.md §9). Used as:

      import PhxliveWeb.PluginRouter
      plugin_pipelines()        # with the other pipelines
      plugin_api_routes()       # BEFORE the core "/api/games/:game_slug" scopes
      plugin_browser_routes()   # after the main live_session
      plugin_admin_routes()     # likewise

  Routes of *installed* plugins are always compiled in; the gate pipeline
  (`PhxliveWeb.Plugs.PluginActive`) and the LiveView `on_mount` hook
  (`PhxliveWeb.PluginGate`) refuse requests while a plugin is inactive, so an
  admin can toggle plugins without a recompile.
  """

  alias Phxlive.Plugins.Discovery

  @doc false
  def plugins_with_routes do
    for %{slug: slug, module: mod} <- Discovery.discover(),
        ensure_plugin!(slug, mod),
        routes = mod.routes(),
        routes != nil,
        ensure_routes!(slug, routes) do
      game_slug =
        case mod.game() do
          %{slug: s} when is_binary(s) -> s
          _ -> slug
        end

      %{slug: slug, game_slug: game_slug, routes: routes}
    end
  end

  defp ensure_plugin!(slug, mod) do
    case Code.ensure_compiled(mod) do
      {:module, ^mod} ->
        true

      _ ->
        raise ArgumentError,
              "plugins/#{slug} is installed but #{inspect(mod)} is not defined. Every plugin folder " <>
                "needs lib/#{slug}/plugin.ex with `defmodule #{inspect(mod)} do use Phxlive.Plugin, ...`."
    end
  end

  defp ensure_routes!(slug, routes) do
    case Code.ensure_compiled(routes) do
      {:module, ^routes} ->
        function_exported?(routes, :__api_routes__, 0) ||
          raise ArgumentError, "plugin #{slug}: #{inspect(routes)} must `use Phxlive.Plugin.Routes`"

      _ ->
        raise ArgumentError, "plugin #{slug}: routes/0 returns #{inspect(routes)}, which is not defined"
    end
  end

  @doc "Gate pipelines for each installed plugin (pages, API, admin), plus a recompile guard."
  defmacro plugin_pipelines do
    plugins = plugins_with_routes()
    slugs = Discovery.slugs()

    pipelines =
      for %{slug: slug, game_slug: game_slug} <- plugins do
        quote do
          pipeline unquote(:"plugin_gate_#{slug}") do
            plug PhxliveWeb.Plugs.PluginActive, slug: unquote(slug), page: true
          end

          pipeline unquote(:"plugin_api_gate_#{slug}") do
            plug PhxliveWeb.Plugs.PluginActive, slug: unquote(slug), game_slug: unquote(game_slug)
          end

          pipeline unquote(:"plugin_admin_gate_#{slug}") do
            plug PhxliveWeb.Plugs.PluginActive, slug: unquote(slug)
          end
        end
      end

    quote do
      # Adding or removing a plugin folder recompiles the router.
      @doc false
      def __mix_recompile__?, do: Phxlive.Plugins.Discovery.slugs() != unquote(slugs)

      unquote_splicing(pipelines)
    end
  end

  @doc "API routes at /api/games/<game slug>/..., `:games_api` pipeline + gate."
  defmacro plugin_api_routes do
    scopes =
      for %{slug: slug, game_slug: game_slug, routes: routes} <- plugins_with_routes(),
        block = routes.__api_routes__(),
        block != nil do
      quote do
        scope unquote("/api/games/#{game_slug}"), unquote(routes.__namespace__()), as: unquote(:"#{slug}_api") do
          pipe_through [:games_api, unquote(:"plugin_api_gate_#{slug}")]
          unquote(block)
        end
      end
    end

    {:__block__, [], scopes}
  end

  @doc "Browser routes at /games/<plugin slug>/..., in a live_session per plugin."
  defmacro plugin_browser_routes do
    scopes =
      for %{slug: slug, routes: routes} <- plugins_with_routes(),
        block = routes.__browser_routes__(),
        block != nil do
      quote do
        scope unquote("/games/#{slug}"), unquote(routes.__namespace__()), as: unquote(:"#{slug}") do
          pipe_through [:browser, unquote(:"plugin_gate_#{slug}")]

          live_session unquote(:"plugin_#{slug}"),
            on_mount: [{PhxliveWeb.UserAuth, :default}, {PhxliveWeb.PluginGate, unquote(slug)}],
            layout: {PhxliveWeb.Layouts, :app} do
            unquote(block)
          end
        end
      end
    end

    {:__block__, [], scopes}
  end

  @doc "Admin pages at /admin/<plugin slug>/..., admins only, in a live_session per plugin."
  defmacro plugin_admin_routes do
    scopes =
      for %{slug: slug, routes: routes} <- plugins_with_routes(),
        function_exported?(routes, :__admin_routes__, 0),
        block = routes.__admin_routes__(),
        block != nil do
      quote do
        scope unquote("/admin/#{slug}"), unquote(routes.__namespace__()), as: unquote(:"#{slug}_admin") do
          pipe_through [:browser, unquote(:"plugin_admin_gate_#{slug}")]

          live_session unquote(:"plugin_admin_#{slug}"),
            on_mount: [{PhxliveWeb.UserAuth, :require_admin_user}, {PhxliveWeb.PluginGate, {unquote(slug), "/admin/plugins"}}],
            layout: {PhxliveWeb.Layouts, :app} do
            unquote(block)
          end
        end
      end
    end

    {:__block__, [], scopes}
  end
end
