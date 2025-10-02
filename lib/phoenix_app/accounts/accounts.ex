defmodule PhoenixApp.Accounts do
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User
  
  require Logger

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
  # Enhanced registration with security checks
  # ---------------------
  def register_user(attrs, opts \\ []) do
    ip_address = Keyword.get(opts, :ip_address)
    email = String.trim(attrs["email"] || "")
    username = String.trim(attrs["name"] || "")
    
    # Check if user already exists with this email or username
    cond do
      get_user_by_email(email) != nil ->
        existing_user = get_user_by_email(email)
        # Check if email is verified - allow re-registration if not verified
        if existing_user.email_verified_at do
          {:error, :email_taken, "An account with this email address already exists."}
        else
          # Email not verified, resend verification email
          case PhoenixApp.Accounts.EmailVerification.send_verification_email(existing_user) do
            {:ok, message} ->
              {:ok, existing_user, message}
            {:error, _email_error} ->
              {:ok, existing_user, "Please check your email for the verification code."}
          end
        end
      
      get_user_by_username(username) != nil ->
        {:error, :username_taken, "This username is already taken. Please choose a different one."}
      
      true ->
        # No existing user, proceed with normal registration
        with :ok <- check_registration_rate_limit(ip_address),
             {:ok, user} <- create_user_with_verification(attrs, ip_address) do
          
          # Record the registration attempt for rate limiting
          if ip_address, do: PhoenixApp.Accounts.RateLimit.record_registration_attempt(ip_address)
          
          # Send verification email
          case PhoenixApp.Accounts.EmailVerification.send_verification_email(user) do
            {:ok, message} ->
              {:ok, user, message}
            {:error, _email_error} ->
              # User created but email failed - still return success
              {:ok, user, "Account created but verification email could not be sent. Please contact support."}
          end
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            # Check if this is a unique constraint error
            case changeset.errors do
              [email: {_msg, [constraint: :unique, constraint_name: _]}] ->
                {:error, :email_taken, "An account with this email address already exists."}
              [name: {_msg, [constraint: :unique, constraint_name: _]}] ->
                {:error, :username_taken, "This username is already taken. Please choose a different one."}
              _ ->
                {:error, changeset}
            end
          error ->
            error
        end
    end
  end
  defp check_registration_rate_limit(nil), do: :ok
  defp check_registration_rate_limit(ip_address) do
    PhoenixApp.Accounts.RateLimit.check_registration_limit(ip_address)
  end

  defp create_user_with_verification(attrs, ip_address) do
    attrs_with_ip = if ip_address, do: Map.put(attrs, "registration_ip", ip_address), else: attrs
    
    Repo.transaction(fn ->
      # Create the user
      case %User{}
           |> User.registration_changeset(attrs_with_ip)
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
  # Get user by username (name field)
  # ---------------------
  def get_user_by_username(username) when is_binary(username), do: Repo.get_by(User, name: username)

  # ---------------------
  # Check if username is available
  # ---------------------
  def username_available?(username) when is_binary(username) do
    username = String.trim(username)
    case get_user_by_username(username) do
      nil -> true
      _user -> false
    end
  end

  # ---------------------
  # Get user by email or username  
  # ---------------------
  def get_user_by_email_or_username(identifier) when is_binary(identifier) do
    # Check if identifier contains @ (likely email) or not (likely username/name)
    if String.contains?(identifier, "@") do
      Repo.get_by(User, email: identifier)
    else
      # Try to find by name field (which serves as username)
      Repo.get_by(User, name: identifier)
    end
  end

  # ---------------------
  # Check user password
  # ---------------------
  def check_password(%User{password_hash: hash}, password) when is_binary(password) do
    Pbkdf2.verify_pass(password, hash)
  end

  # ---------------------
  # Enhanced authentication with security checks
  # ---------------------
  def authenticate_user_secure(identifier, password, opts \\ []) when is_binary(identifier) and is_binary(password) do
    ip_address = Keyword.get(opts, :ip_address)
    
    # Check rate limiting first
    with :ok <- check_login_rate_limit(ip_address) do
      start_time = System.monotonic_time(:millisecond)
      
      result = case get_user_by_email_or_username(identifier) do
        nil ->
          # Still run password check to prevent timing attacks
          Pbkdf2.no_user_verify()
          {:error, :invalid_credentials}

        user ->
          if check_password(user, password) do
            # Additional security checks
            cond do
              user.locked_until && DateTime.utc_now() < user.locked_until ->
                {:error, :account_locked}
              
              is_nil(user.email_verified_at) ->
                {:error, :email_not_verified}
              
              true ->
                # Reset failed login attempts on successful login
                reset_failed_login_attempts(user, ip_address)
                {:ok, user}
            end
          else
            # Record failed login attempt
            record_failed_login(ip_address, user)
            {:error, :invalid_credentials}
          end
      end
      
      end_time = System.monotonic_time(:millisecond)
      Logger.info("Authentication took #{end_time - start_time}ms")
      
      result
    else
      {:error, rate_limit_error} when is_binary(rate_limit_error) ->
        {:error, rate_limit_error}
      
      {:error, _} ->
        {:error, "Too many login attempts. Please try again later."}
    end
  end

  defp check_login_rate_limit(nil), do: :ok
  defp check_login_rate_limit(ip_address) do
    PhoenixApp.Accounts.RateLimit.check_login_limit(ip_address)
  end



  defp record_failed_login(nil, _user), do: :ok
  defp record_failed_login(ip_address, _user), do: PhoenixApp.Accounts.RateLimit.record_login_attempt(ip_address)

  defp reset_failed_login_attempts(user, ip_address) do
    # Reset failed login attempts and update last login information
    user
    |> User.reset_failed_login_changeset(ip_address)
    |> Repo.update()
  end

  # Keep the original authenticate_user for backward compatibility
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

  # Email verification functions
  def verify_user_email(token) do
    PhoenixApp.Accounts.EmailVerification.verify_email(token)
  end

  def verify_user_with_code(email, code) do
    PhoenixApp.Accounts.EmailVerification.verify_email_with_code(email, code)
  end

  def verify_user_email_direct(user) do
    # Direct email verification without token (for development)
    user
    |> User.verify_email_changeset()
    |> Repo.update()
  end

  def resend_verification_email(email) do
    PhoenixApp.Accounts.EmailVerification.resend_verification_email(email)
  end

  # Account management
  def unlock_user_account(user) do
    user
    |> User.reset_failed_login_changeset()
    |> Repo.update()
  end

  def is_account_secure?(user) do
    User.email_verified?(user) and not User.account_locked?(user)
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

  def update_user_role(%User{} = user, role) when is_binary(role) do
    # Map role to admin status and role field
    {is_admin, role_value} = case role do
      "admin" -> {true, "admin"}
      "gm" -> {false, "gm"}
      "editor" -> {false, "editor"}
      "moderator" -> {false, "moderator"}
      "member" -> {false, "member"}
      "guest" -> {false, "guest"}
      "banned" -> {false, "banned"}
      _ -> {false, "member"} # default
    end

    user
    |> User.role_changeset(%{is_admin: is_admin, role: role_value})
    |> Repo.update()
  end

  def count_users do
    Repo.aggregate(User, :count, :id)
  end

  def count_admin_users do
    import Ecto.Query
    from(u in User, where: u.is_admin == true)
    |> Repo.aggregate(:count, :id)
  end

  def count_active_users do
    import Ecto.Query
    # Users who have logged in in the last 30 days
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    from(u in User, where: u.last_login_at > ^thirty_days_ago or u.is_online == true)
    |> Repo.aggregate(:count, :id)
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

  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_user_password(%User{} = user, attrs) do
    user
    |> User.password_change_changeset(attrs)
    |> Repo.update()
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

  # ---------------------
  # Password Reset Functions
  # ---------------------
  
  def send_password_reset_email(identifier, _ip_address \\ nil) when is_binary(identifier) do
    identifier = String.trim(identifier)
    
    # Check rate limiting first (use email/username for rate limiting)
    with :ok <- check_password_reset_rate_limit(identifier) do
      # Find user by email or username
      case get_user_by_email_or_username(identifier) do
        nil ->
          # Don't reveal if user exists or not - always return success message
          # But record the attempt for rate limiting
          PhoenixApp.Accounts.RateLimit.record_password_reset_attempt(identifier)
          {:ok, "If an account with that email/username exists, you should receive an email with instructions shortly."}
          
        %User{} = user ->
          # Generate reset token and send email
          with {:ok, user_with_token} <- generate_password_reset_token(user) do
            case PhoenixApp.Email.send_password_reset_email(user_with_token) do
              {:ok, _} -> 
                # Record the attempt for rate limiting (use the identifier, not IP)
                PhoenixApp.Accounts.RateLimit.record_password_reset_attempt(identifier)
                {:ok, "If an account with that email/username exists, you should receive an email with instructions shortly."}
              {:error, _reason} ->
                {:error, "Unable to send password reset email. Please try again later."}
            end
          else
            {:error, _changeset} ->
              {:error, "Unable to send password reset email. Please try again later."}
          end
      end
    else
      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  defp generate_password_reset_token(%User{} = user) do
    # Generate a secure random token
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    
    # Update user with token and timestamp
    changeset = User.password_reset_changeset(user, %{
      password_reset_token: token,
      password_reset_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    
    case Repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def reset_password_with_token(token, new_password) when is_binary(token) and is_binary(new_password) do
    with %User{} = user <- get_user_by_reset_token(token),
         :ok <- validate_reset_token_expiry(user),
         {:ok, updated_user} <- update_user_password_and_clear_token(user, new_password) do
      {:ok, updated_user}
    else
      nil -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_user_by_reset_token(token) when is_binary(token) do
    Repo.get_by(User, password_reset_token: token)
  end

  def validate_reset_token_expiry(%User{password_reset_sent_at: nil}), do: {:error, :invalid_token}
  def validate_reset_token_expiry(%User{password_reset_sent_at: sent_at}) do
    # Token expires after 1 hour
    expiry_time = DateTime.add(sent_at, 3600, :second)
    
    if DateTime.compare(DateTime.utc_now(), expiry_time) == :lt do
      :ok
    else
      {:error, :token_expired}
    end
  end

  defp update_user_password_and_clear_token(%User{} = user, new_password) do
    changeset = User.password_update_changeset(user, %{
      password: new_password,
      password_reset_token: nil,
      password_reset_sent_at: nil
    })
    
    case Repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp check_password_reset_rate_limit(nil), do: :ok
  defp check_password_reset_rate_limit(identifier) do
    case PhoenixApp.Accounts.RateLimit.check_password_reset_limit(identifier) do
      :ok -> :ok
      :rate_limited -> {:error, :rate_limited}
    end
  end
end
