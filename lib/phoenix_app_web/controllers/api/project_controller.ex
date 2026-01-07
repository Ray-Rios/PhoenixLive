defmodule PhoenixAppWeb.Api.ProjectController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Scheduler
  plug PhoenixAppWeb.Plugs.ApiKeyOrAuth when action in [:calendar]

  def calendar(conn, _params) do
    projects = Scheduler.list_projects_for_calendar()
    json(conn, %{projects: projects})
  end
end
