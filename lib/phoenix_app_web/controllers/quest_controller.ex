defmodule PhoenixAppWeb.QuestController do
  use PhoenixAppWeb, :controller

  def editor(conn, _params) do
    render(conn, "editor.html")
  end
end
