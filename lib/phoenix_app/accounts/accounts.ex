defmodule PhoenixApp.Accounts do
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User
  alias Bcrypt

  # ---------------------
  # List all users
  # ---------------------
  def list_users do
    Repo.all(User)
  end

  # ---------------------
  # Get User by id
  # ---------------------
  def get_user(id) when is_binary(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)

  # ---------------------
  # Register a new user
  # ---------------------
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------
  # Update profile (name/email)
  # ---------------------
  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  # ---------------------
  # Update password
  # ---------------------
  def update_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  # ---------------------
  # Get user by email
  # ---------------------
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  # ---------------------
  # Check user password
  # ---------------------
  def check_password(%User{password_hash: hash}, password) when is_binary(password) do
    Bcrypt.verify_pass(password, hash)
  end

  # ---------------------
  # Authenticate user (web & API)
  # Returns {:ok, user} or {:error, reason}
  # ---------------------
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    case get_user_by_email(email) do
      nil ->
        {:error, :invalid_email}

      user ->
        if check_password(user, password) do
          {:ok, user}
        else
          {:error, :invalid_password}
        end
    end
  end

  # ---------------------
  # Session token functions
  # ---------------------
  def generate_user_session_token(_user) do
    token = :crypto.strong_rand_bytes(32)
    # For now, just return the token - implement UserToken later if needed
    token
  end

  def get_user_by_session_token(_token) do
    # For now, return nil - implement UserToken later if needed
    nil
  end

  def delete_user_session_token(_token) do
    # For now, just return ok - implement UserToken later if needed
    :ok
  end

  # ---------------------
  # Admin functions
  # ---------------------
  def make_admin(%User{} = user) do
    user
    |> User.admin_changeset(%{is_admin: true})
    |> Repo.update()
  end

  def remove_admin(%User{} = user) do
    user
    |> User.admin_changeset(%{is_admin: false})
    |> Repo.update()
  end

  def count_users do
    Repo.aggregate(User, :count, :id)
  end

  def list_recent_users(limit \\ 5) do
    import Ecto.Query
    from(u in User, order_by: [desc: u.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  # ---------------------
  # User management functions
  # ---------------------
  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def update_user_position(%User{} = user, attrs) do
    user
    |> User.position_changeset(attrs)
    |> Repo.update()
  end

  def update_user_profile(%User{} = user, attrs) do
    update_profile(user, attrs)
  end

  def update_user_password(%User{} = user, attrs) do
    update_password(user, attrs)
  end

  def update_avatar(%User{} = user, attrs) do
    user
    |> User.avatar_changeset(attrs)
    |> Repo.update()
  end

  def enable_user(%User{} = user) do
    user
    |> User.status_changeset(%{is_active: true})
    |> Repo.update()
  end

  def disable_user(%User{} = user) do
    user
    |> User.status_changeset(%{is_active: false})
    |> Repo.update()
  end

  # ---------------------
  # Two-factor authentication
  # ---------------------
  def enable_two_factor(%User{} = user, secret, backup_codes) do
    user
    |> User.two_factor_changeset(%{
      two_factor_secret: secret,
      two_factor_enabled: true,
      two_factor_backup_codes: backup_codes
    })
    |> Repo.update()
  end

  def disable_two_factor(%User{} = user) do
    user
    |> User.two_factor_changeset(%{
      two_factor_secret: nil,
      two_factor_enabled: false,
      two_factor_backup_codes: []
    })
    |> Repo.update()
  end

  # ---------------------
  # Delete user
  # ---------------------
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  # ---------------------
  # Game server authentication
  # ---------------------
  def authenticate_for_game_server(email, password) do
    case authenticate_user(email, password) do
      {:ok, user} ->
        # Generate a game session token
        game_token = generate_game_session_token(user)
        {:ok, %{user: user, game_token: game_token}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def generate_game_session_token(%User{} = user) do
    # Create a JWT-like token for game server authentication
    payload = %{
      user_id: user.id,
      email: user.email,
      name: user.name,
      is_admin: user.is_admin,
      exp: System.system_time(:second) + (24 * 60 * 60) # 24 hours
    }
    
    # Simple base64 encoding for now - in production use proper JWT
    payload
    |> Jason.encode!()
    |> Base.encode64()
  end

  def verify_game_session_token(token) when is_binary(token) do
    try do
      payload = 
        token
        |> Base.decode64!()
        |> Jason.decode!()
      
      # Check if token is expired
      if payload["exp"] > System.system_time(:second) do
        case get_user(payload["user_id"]) do
          nil -> {:error, :user_not_found}
          user -> {:ok, user}
        end
      else
        {:error, :token_expired}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end
end
