defmodule PhoenixAppWeb.PageController do
  use PhoenixAppWeb, :controller

  ## Index (normal Phoenix homepage)
  def index(conn, _params) do
    render(conn, :index)
  end
end
