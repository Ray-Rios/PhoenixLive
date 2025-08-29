defmodule PhoenixAppWeb.GamePlayerController do
  use PhoenixAppWeb, :controller
  
  alias PhoenixApp.{Accounts, GameData}

  def profile(conn, _params) do
    user = conn.assigns.current_user
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      profile: %{
        id: user.id,
        email: user.email,
        game_username: user.name || user.email,  # Use 'name' field
        avatar_shape: user.avatar_shape,
        avatar_color: user.avatar_color,
        is_game_active: user.is_game_active || false,
        last_game_activity: user.last_game_activity
      }
    })
  end

  def update_profile(conn, params) do
    user = conn.assigns.current_user
    
    update_params = %{}
    |> maybe_put("name", params["game_username"])  # Use 'name' field
    |> maybe_put("avatar_shape", params["avatar_shape"])
    |> maybe_put("avatar_color", params["avatar_color"])
    |> Map.put("last_game_activity", DateTime.utc_now())
    |> Map.put("is_game_active", true)
    
    case Accounts.update_user(user, update_params) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          profile: %{
            id: updated_user.id,
            email: updated_user.email,
            game_username: updated_user.name,  # Use 'name' field
            avatar_shape: updated_user.avatar_shape,
            avatar_color: updated_user.avatar_color
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

  def avatar(conn, _params) do
    user = conn.assigns.current_user
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      avatar: %{
        shape: user.avatar_shape,
        color: user.avatar_color
      }
    })
  end

  def update_avatar(conn, %{"shape" => shape, "color" => color}) do
    user = conn.assigns.current_user
    
    case Accounts.update_user(user, %{avatar_shape: shape, avatar_color: color}) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          avatar: %{
            shape: updated_user.avatar_shape,
            color: updated_user.avatar_color
          }
        })
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, errors: format_changeset_errors(changeset)})
    end
  end

  def stats(conn, _params) do
    user = conn.assigns.current_user
    
    # This will use the GameData context we'll create in Phase 2
    stats = GameData.get_player_stats(user.id) || %{
      games_played: 0,
      wins: 0,
      losses: 0,
      experience_points: 0,
      level: 1
    }
    
    conn
    |> put_status(:ok)
    |> json(%{success: true, stats: stats})
  end

  def update_stats(conn, stats_params) do
    user = conn.assigns.current_user
    
    case GameData.update_player_stats(user.id, stats_params) do
      {:ok, stats} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true, stats: stats})
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, errors: format_changeset_errors(changeset)})
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end