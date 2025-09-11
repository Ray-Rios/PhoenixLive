defmodule PhoenixAppWeb.Api.ApiController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Game

  @doc """
  GET /api/status
  Returns service status information matching the Rust API format.
  """
  def status(conn, _params) do
    response = %{
      success: true,
      data: %{
        service: "eqemu_service",
        version: "0.1.0",
        status: "running",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      message: "Service status retrieved"
    }

    conn
    |> put_status(:ok)
    |> put_resp_header("content-type", "application/json")
    |> json(response)
  end

  @doc """
  POST /api/sessions
  Creates a new game session matching the Rust API format.
  """
  def create_session(conn, params) do
    user_id = params["user_id"] || "placeholder"
    
    case Game.create_session(%{user_id: user_id}) do
      {:ok, session} ->
        response = %{
          success: true,
          data: %{
            id: session.id,
            user_id: session.user_id,
            status: session.status,
            created_at: DateTime.to_iso8601(session.inserted_at)
          },
          message: "Game session created"
        }

        conn
        |> put_status(:created)
        |> put_resp_header("content-type", "application/json")
        |> json(response)

      {:error, changeset} ->
        response = %{
          success: false,
          data: nil,
          message: "Failed to create session"
        }

        conn
        |> put_status(:internal_server_error)
        |> put_resp_header("content-type", "application/json")
        |> json(response)
    end
  end
end