defmodule PhoenixAppWeb.Api.GameController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Accounts
  alias PhoenixApp.EqemuGame

  # GET /api/game/profile - Get current user profile
  def get_profile(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      user: %{
        id: user.id,
        email: user.email,
        name: user.name,
        is_admin: user.is_admin,
        email_verified: !is_nil(user.email_verified_at),
        created_at: user.inserted_at
      }
    })
  end

  # GET /api/game/characters - List user's characters
  def list_characters(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    
    # This would integrate with your game's character system
    characters = [
      %{
        id: "char_1",
        name: "#{user.name}_Warrior",
        class: "Warrior",
        level: 1,
        zone: "tutorial"
      }
    ]
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      characters: characters,
      user_id: user.id
    })
  end

  # POST /api/game/characters - Create new character
  def create_character(conn, %{"name" => name, "class" => class} = _params) do
    user = Guardian.Plug.current_resource(conn)
    
    # This would integrate with your game's character creation
    character = %{
      id: "char_#{System.unique_integer([:positive])}",
      name: name,
      class: class,
      level: 1,
      zone: "tutorial",
      user_id: user.id
    }
    
    conn
    |> put_status(:created)
    |> json(%{
      success: true,
      message: "Character created successfully",
      character: character
    })
  end

  # GET /api/game/inventory/:character_id - Get character inventory
  def get_inventory(conn, %{"character_id" => character_id}) do
    user = Guardian.Plug.current_resource(conn)
    
    # This would integrate with your game's inventory system
    inventory = [
      %{
        item_id: "sword_basic",
        name: "Basic Sword",
        quantity: 1,
        equipped: true
      },
      %{
        item_id: "potion_health",
        name: "Health Potion",
        quantity: 5,
        equipped: false
      }
    ]
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      character_id: character_id,
      user_id: user.id,
      inventory: inventory
    })
  end

  # POST /api/game/login-game - Login to specific game instance
  def login_to_game(conn, %{"game_type" => game_type} = params) do
    user = Guardian.Plug.current_resource(conn)
    
    # Generate game-specific session token
    game_session = %{
      session_id: "game_#{System.unique_integer([:positive])}",
      user_id: user.id,
      game_type: game_type,
      server: params["server"] || "main",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      message: "Game login successful",
      game_session: game_session,
      user: %{
        id: user.id,
        name: user.name,
        is_admin: user.is_admin
      }
    })
  end
end