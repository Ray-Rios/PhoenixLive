defmodule PhoenixAppWeb.Plugs.GameAuthPlug do
  @moduledoc """
  Plug for authenticating game API requests via JWT
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  alias PhoenixApp.Accounts
  alias PhoenixAppWeb.GameAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token(conn, token)
      [] ->
        unauthorized(conn)
      _ ->
        unauthorized(conn)
    end
  end

  defp verify_token(conn, token) do
    case GameAuth.verify_jwt(token) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          nil ->
            unauthorized(conn)
          user ->
            assign(conn, :current_user, user)
        end
      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{success: false, error: "Unauthorized"})
    |> halt()
  end
end