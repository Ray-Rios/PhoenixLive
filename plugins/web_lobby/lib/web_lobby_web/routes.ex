defmodule WebLobbyWeb.Routes do
  @moduledoc "Web Lobby's routes. Pages mount at /games/web_lobby (PHXLIVE.md §9)."
  use Phxlive.Plugin.Routes

  browser do
    live "/", PlayLive, :index
  end
end
