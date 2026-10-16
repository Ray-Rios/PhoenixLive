defmodule Phxlive.Plugin.Routes do
  @moduledoc """
  How a plugin declares its routes:

      defmodule WebLobbyWeb.Routes do
        use Phxlive.Plugin.Routes

        # Mounted at /api/games/<game slug>, `:games_api` pipeline
        # (player bearer token or game-server key).
        api do
          get "/zones", ZoneController, :index
        end

        # Mounted at /games/<plugin slug>, signed-in browser session.
        browser do
          live "/", PlayLive, :index
        end
      end

  Module names inside the blocks are relative to the routes module's parent
  namespace (`WebLobbyWeb` here). The blocks are stored as quoted code and
  expanded by `PhxliveWeb.PluginRouter` inside the core router at compile time,
  so they can use anything a Phoenix router scope can.
  """

  defmacro __using__(_opts) do
    namespace =
      __CALLER__.module
      |> Module.split()
      |> Enum.drop(-1)
      |> Module.concat()

    quote do
      import Phxlive.Plugin.Routes, only: [api: 1, browser: 1]
      @before_compile Phxlive.Plugin.Routes
      Module.register_attribute(__MODULE__, :phxlive_api_routes, accumulate: false)
      Module.register_attribute(__MODULE__, :phxlive_browser_routes, accumulate: false)

      @doc false
      def __namespace__, do: unquote(namespace)
    end
  end

  @doc "Declares API routes, mounted under /api/games/<game slug>."
  defmacro api(do: block) do
    quote do: @phxlive_api_routes unquote(Macro.escape(block))
  end

  @doc "Declares browser routes, mounted under /games/<plugin slug>."
  defmacro browser(do: block) do
    quote do: @phxlive_browser_routes unquote(Macro.escape(block))
  end

  defmacro __before_compile__(env) do
    api = Module.get_attribute(env.module, :phxlive_api_routes)
    browser = Module.get_attribute(env.module, :phxlive_browser_routes)

    quote do
      @doc false
      def __api_routes__, do: unquote(Macro.escape(api))
      @doc false
      def __browser_routes__, do: unquote(Macro.escape(browser))
    end
  end
end
