defmodule PhoenixAppWeb.Api.ApiAuthController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Accounts

  # POST /api/auth/register
  def register(conn, %{"email" => email, "password" => password} = params) do
    user_params = %{
      "email" => email,
      "password" => password,
      "name" => params["name"] || email
    }

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Auto-login after registration
        case Accounts.authenticate_for_api_server(email, password) do
          {:ok, %{user: user, api_token: token}} ->
            conn
            |> put_session(:user_id, user.id)
            |> put_status(:created)
            |> json(%{
              success: true,
              message: "Account created successfully",
              user: %{
                id: user.id,
                email: user.email,
                name: user.name,
                is_admin: user.is_admin
              },
              api_token: token
            })

          {:error, _} ->
            conn
            |> put_status(:created)
            |> json(%{
              success: true,
              message: "Account created successfully",
              user: %{
                id: user.id,
                email: user.email,
                name: user.name,
                is_admin: user.is_admin
              }
            })
        end

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: errors
        })
    end
  end

  # POST /api/auth/login
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> put_status(:ok)
        |> json(%{
          success: true,
          message: "Login successful",
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            is_admin: user.is_admin
          }
        })

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid email or password"})
    end
  end

  # POST /api/auth/authenticate
  def authenticate(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_for_api_server(email, password) do
      {:ok, %{user: user, api_token: token}} ->
        # Create API session on the API server
        case create_api_session(user, token) do
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
              api_token: token,
              api_session: session_data
            })

          {:error, _reason} ->
            # Still return success for auth, but note API session creation failed
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
              api_token: token,
              api_session_error: "Could not create API session"
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

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Authentication failed"})
    end
  end

  defp create_api_session(user, token) do
    api_server_url = System.get_env("API_SERVER_URL", "http://localhost:7000")
    
    payload = %{
      user_id: user.id,
      email: user.email,
      name: user.name,
      api_token: token,
      is_admin: user.is_admin
    }

    case HTTPoison.post("#{api_server_url}/auth/create_session", Jason.encode!(payload), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, session_data} -> {:ok, session_data}
          {:error, _} -> {:error, :invalid_response}
        end
      
      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :api_server_error}
      
      {:error, _} ->
        {:error, :connection_failed}
    end
  end

  # POST /api/auth/verify
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

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid or expired token"})
    end
  end

  # GET /api/auth/users (for API server to get user list)
  def list_users(conn, _params) do
    # This should be protected by API server authentication
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

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end