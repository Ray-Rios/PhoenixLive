defmodule PhxliveWeb.PageController do
  use PhxliveWeb, :controller

  ## Index (normal Phoenix homepage)
  def index(conn, _params) do
    render(conn, :index)
  end
end
