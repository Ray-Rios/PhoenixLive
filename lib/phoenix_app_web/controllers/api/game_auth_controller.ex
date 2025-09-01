defmodule PhoenixAppWeb.Api.GameAuthController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Accounts

  # POST /api/game/auth
  def authenticate(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_for_game_server(email, password) do
      {:ok, %{user: user, game_token: token}} ->
        # Create game session on the game server
        case create_game_session(user, token) do
          {:ok, session_data} ->
            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              user: %{
                id: user.id,
                email: user.email,
                name: user.name,
                is_admin: user.is_admin
              },
              game_token: token,
              game_session: session_data
            })

          {:error, _reason} ->
            # Still return success for auth, but note game session creation failed
            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              user: %{
                id: user.id,
                email: user.email,
                name: user.name,
                is_admin: user.is_admin
              },
              game_token: token,
              game_session_error: "Could not create game session"
            })
        end

      {:error, :invalid_email} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid email"})

      {:error, :invalid_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid password"})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Authentication failed"})
    end
  end

  defp create_game_session(user, token) do
    game_server_url = System.get_env("GAME_SERVER_URL", "http://localhost:8080")
    
    payload = %{
      user_id: user.id,
      email: user.email,
      name: user.name,
      game_token: token,
      is_admin: user.is_admin
    }

    case HTTPoison.post("#{game_server_url}/auth/create_session", Jason.encode!(payload), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, session_data} -> {:ok, session_data}
          {:error, _} -> {:error, :invalid_response}
        end
      
      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :game_server_error}
      
      {:error, _} ->
        {:error, :connection_failed}
    end
  end

  # POST /api/game/verify
  def verify_token(conn, %{"token" => token}) do
    case Accounts.verify_game_session_token(token) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            is_admin: user.is_admin
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid or expired token"})
    end
  end

  # GET /api/game/users (for game server to get user list)
  def list_users(conn, _params) do
    # This should be protected by game server authentication
    users = Accounts.list_users()
    
    user_data = Enum.map(users, fn user ->
      %{
        id: user.id,
        email: user.email,
        name: user.name,
        is_admin: user.is_admin,
        status: user.status || "active"
      }
    end)

    conn
    |> put_status(:ok)
    |> json(%{success: true, users: user_data})
  end
end