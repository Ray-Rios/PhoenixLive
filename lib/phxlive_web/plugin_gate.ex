defmodule PhxliveWeb.PluginGate do
  @moduledoc """
  LiveView `on_mount` hook for plugin pages. The HTTP request is already gated
  by `PhxliveWeb.Plugs.PluginActive`; this covers the websocket mount and live
  navigation, so deactivating a plugin also stops already-open pages from
  reconnecting into it.

  The argument is the plugin slug, or `{slug, redirect_path}` (admin pages go
  back to /admin/plugins rather than /games).
  """
  import Phoenix.LiveView

  def on_mount({slug, to}, _params, _session, socket) when is_binary(slug) and is_binary(to) do
    if Phxlive.Plugins.active?(slug) do
      {:cont, socket}
    else
      {:halt, socket |> put_flash(:error, "That plugin isn't active.") |> redirect(to: to)}
    end
  end

  def on_mount(slug, _params, _session, socket) when is_binary(slug) do
    if Phxlive.Plugins.active?(slug) do
      {:cont, socket}
    else
      {:halt, socket |> put_flash(:error, "That game isn't available right now.") |> redirect(to: "/games")}
    end
  end
end
