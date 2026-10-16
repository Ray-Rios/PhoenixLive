defmodule PhxliveWeb.Plugs.PluginActive do
  @moduledoc """
  404s every request to a plugin's routes while the plugin is inactive.

  Also assigns `:phxlive_plugin` (the slug), which the root layout uses to
  give plugin pages a plain black background instead of the user's animated
  one: games draw their own scene.
  """
  import Plug.Conn

  def init(opts), do: Keyword.fetch!(opts, :slug)

  def call(conn, slug) do
    if Phxlive.Plugins.active?(slug) do
      assign(conn, :phxlive_plugin, slug)
    else
      conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found") |> halt()
    end
  end
end
