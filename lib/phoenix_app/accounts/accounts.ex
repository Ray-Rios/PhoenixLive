defmodule PhoenixApp.Accounts do
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User

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
    Repo.transaction(fn ->
      # Create the user
      case %User{}
           |> User.registration_changeset(attrs)
           |> Repo.insert() do
        {:ok, user} ->
          # Create corresponding EQEmu account
          case PhoenixApp.EqemuGame.create_eqemu_account(user) do
            {:ok, _account} -> user
            {:error, reason} -> 
              Repo.rollback("Failed to create EQEmu account: #{inspect(reason)}")
          end
        
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  # ---------------------
  # Update profile (name/email)
  # ---------------------
  def update_profile(%User{} = user, attrs) do
    Repo.transaction(fn ->
      case user
           |> User.profile_changeset(attrs)
           |> Repo.update() do
        {:ok, updated_user} ->
          # Sync email changes to EQEmu account
          case PhoenixApp.EqemuGame.sync_user_to_eqemu_account(updated_user) do
            {:ok, _account} -> updated_user
            {:error, reason} ->
              Repo.rollback("Failed to sync EQEmu account: #{inspect(reason)}")
          end
        
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
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
    Pbkdf2.verify_pass(password, hash)
  end

  # ---------------------
  # Authenticate user (web & API)
  # Returns {:ok, user} or {:error, reason}
  # ---------------------
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    start_time = System.monotonic_time(:millisecond)
    
    result = case get_user_by_email(email) do
      nil ->
        # Still run password check to prevent timing attacks
        Pbkdf2.no_user_verify()
        {:error, :invalid_email}

      user ->
        if check_password(user, password) do
          {:ok, user}
        else
          {:error, :invalid_password}
        end
    end
    
    end_time = System.monotonic_time(:millisecond)
    IO.puts("Authentication took #{end_time - start_time}ms")
    
    result
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
  # Safe delete user with EQEmu cleanup
  # ---------------------
  def delete_user_with_eqemu_cleanup(%User{} = user) do
    Repo.transaction(fn ->
      # Get user's EQEmu data for logging
      eqemu_account = PhoenixApp.EqemuGame.get_account_by_user(user)
      characters = PhoenixApp.EqemuGame.list_user_characters(user)
      
      # Log what will be deleted
      IO.puts("Deleting user #{user.email} with:")
      IO.puts("- EQEmu account: #{eqemu_account && eqemu_account.name}")
      IO.puts("- Characters: #{length(characters)} characters")
      
      # Delete user (cascades to EQEmu account and characters)
      case Repo.delete(user) do
        {:ok, deleted_user} ->
          IO.puts("Successfully deleted user and all EQEmu data")
          deleted_user
        
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  # ---------------------
  # API server authentication
  # ---------------------
  def authenticate_for_api_server(email, password) do
    case authenticate_user(email, password) do
      {:ok, user} ->
        # Generate an API session token
        api_token = generate_api_session_token(user)
        {:ok, %{user: user, api_token: api_token}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------
  # EQEmu server authentication
  # ---------------------
  def authenticate_for_eqemu(email, password) do
    case PhoenixApp.EqemuGame.authenticate_eqemu_login(email, password) do
      {:ok, %{user: user, account: account}} ->
        {:ok, %{user: user, account: account}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_eqemu_account(account_name) do
    PhoenixApp.EqemuGame.verify_eqemu_account(account_name)
  end

  def generate_api_session_token(%User{} = user) do
    # Create a JWT-like token for API server authentication
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
