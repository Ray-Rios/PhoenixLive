defmodule PhxliveWeb.Api.ProjectController do
  use PhxliveWeb, :controller
  alias Phxlive.Scheduler
  plug PhxliveWeb.Plugs.ApiKeyOrAuth when action in [:calendar]

  def calendar(conn, _params) do
    projects = Scheduler.list_projects_for_calendar()
    json(conn, %{projects: projects})
  end
end
