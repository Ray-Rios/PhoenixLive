defmodule PhoenixAppWeb.GameAuthController do
  use PhoenixAppWeb, :controller
  
  alias PhoenixApp.Accounts
  alias PhoenixApp.Accounts.User
  alias PhoenixAppWeb.GameAuth

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token} = GameAuth.generate_jwt(user)
        
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user.id,
            email: user.email,
            game_username: user.name || user.email,  # Use 'name' field
            avatar_shape: user.avatar_shape,
            avatar_color: user.avatar_color
          }
        })
        
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid email or password"})
    end
  end

  def register(conn, %{"email" => email, "password" => password} = params) do
    game_username = Map.get(params, "game_username", email)
    
    user_params = %{
      email: email,
      password: password,
      name: game_username,  # Use 'name' field instead of 'game_username'
      avatar_shape: Map.get(params, "avatar_shape", "circle"),
      avatar_color: Map.get(params, "avatar_color", "#3B82F6")
    }
    
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:ok, token} = GameAuth.generate_jwt(user)
        
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user.id,
            email: user.email,
            game_username: user.name,  # Use 'name' field
            avatar_shape: user.avatar_shape,
            avatar_color: user.avatar_color
          }
        })
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def refresh_token(conn, %{"token" => token}) do
    case GameAuth.verify_jwt(token) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> json(%{success: false, error: "User not found"})
            
          user ->
            {:ok, new_token} = GameAuth.generate_jwt(user)
            
            conn
            |> put_status(:ok)
            |> json(%{success: true, token: new_token})
        end
        
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid token"})
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        # Handle different value types properly
        string_value = cond do
          is_binary(value) -> value
          is_list(value) -> Enum.join(value, ", ")
          true -> inspect(value)
        end
        String.replace(acc, "%{#{key}}", string_value)
      end)
    end)
  end
end