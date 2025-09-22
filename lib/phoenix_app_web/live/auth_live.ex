defmodule PhoenixAppWeb.AuthLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  alias PhoenixApp.Auth.Guardian


  # ----------------
  # Mount
  # ----------------
  def mount(_params, session, socket) do
    current_user = maybe_fetch_user(session["user_id"])
    
    # Store IP address during mount since connect_info is only available here
    ip_address = case get_connect_info(socket, :peer_data) do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      _ -> "unknown"
    end

    # If user is already logged in, redirect to dashboard
    if current_user do
      {:ok, redirect(socket, to: ~p"/dashboard")}
    else
      {:ok,
       assign(socket,
         current_user: current_user,
         form: to_form(%{}, as: "user"),
         errors: [],
         action: :login,
         loading: false,
         ip_address: ip_address
       )}
    end
  end

  # ----------------
  # Handle URL params with email verification routes
  # ----------------
  def handle_params(params, uri, socket) do
    action =
      case URI.parse(uri).path do
        "/register" -> :register
        "/login" -> :login
        "/auth/verify" -> :verify_code
        "/auth/verify-email" -> :verify_email
        "/auth/resend-verification" -> :resend_verification
        _ -> :login
      end

    socket = case action do
      :verify_email ->
        handle_email_verification(socket, params)
      :verify_code ->
        # Handle verification code page setup
        handle_verify_code_setup(socket, params)
      _ ->
        socket
    end

    page_title = case action do
      :login -> "Sign In"
      :register -> "Register"
      :verify_code -> "Verify Email"
      :verify_email -> "Email Verification"
      :resend_verification -> "Resend Verification"
    end

    {:noreply, assign(socket, action: action, page_title: page_title)}
  end

  defp handle_email_verification(socket, %{"token" => token}) do
    case Accounts.verify_user_email(token) do
      {:ok, user} ->
        socket
        |> put_flash(:info, "Email verified successfully! You can now log in.")
        |> assign(verified_user: user)
      {:error, message} ->
        socket
        |> put_flash(:error, message)
    end
  end

  defp handle_email_verification(socket, _params) do
    socket
    |> put_flash(:error, "Invalid verification link")
  end

  defp handle_verify_code_setup(socket, params) do
    # Get email from URL params (passed from registration)
    email = params["email"]
    verification_code = params["code"] # For dev environment
    
    socket
    |> assign(
      verification_email: email,
      verification_code_for_dev: verification_code,
      verification_form: to_form(%{}, as: "verification")
    )
  end

  # ----------------
  # Handle submit
  # ----------------
  def handle_event("submit", %{"user" => user_params}, socket) do
    # Basic validation
    email = String.trim(user_params["email"] || "")
    password = user_params["password"] || ""
    
    cond do
      email == "" ->
        {:noreply, 
         socket
         |> put_flash(:error, "Email or username is required")
         |> assign(errors: ["Email or username is required"])}
      
      password == "" ->
        {:noreply, 
         socket
         |> put_flash(:error, "Password is required")
         |> assign(errors: ["Password is required"])}
      
      true ->
        # Set loading state
        socket = assign(socket, loading: true)
        
        case socket.assigns.action do
          :login -> do_login(socket, user_params)
          :register -> do_register(socket, user_params)
        end
    end
  end

  # ----------------
  # Enhanced login with security features - Accept email or username
  # ----------------
  defp do_login(socket, %{"email" => identifier, "password" => password} = _params) do
    ip_address = socket.assigns.ip_address
    
    # Add timeout to prevent hanging
    task = Task.async(fn -> Accounts.authenticate_user_secure(identifier, password, ip_address: ip_address) end)
    
    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, {:ok, user}} ->
        # Generate JWT token for unified API access
        {:ok, jwt_token, _claims} = Guardian.encode_and_sign(user)
        
        # Set the session with both user_id and jwt_token
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "Welcome back, #{user.email}!")
         |> assign(current_user: user)
         |> redirect(external: "/auth/login_success?user_id=#{user.id}&token=#{jwt_token}")}

      {:ok, {:error, :invalid_credentials}} ->
        # Preserve entered identifier, clear password
        form = to_form(%{"email" => identifier}, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Invalid email/username or password")
         |> assign(form: form, errors: ["Invalid email/username or password"])}
      
      {:ok, {:error, :account_locked}} ->
        form = to_form(%{"email" => identifier}, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Account temporarily locked due to multiple failed attempts. Please try again later.")
         |> assign(form: form, errors: ["Account locked"])}

      {:ok, {:error, :email_not_verified}} ->
        # Find the user to get verification token for dev mode
        user = Accounts.get_user_by_email_or_username(identifier)
        
        verification_code = if get_env() == "dev" do
          # Extract 6-digit code from the verification token for dev display
          case user.email_verification_token do
            nil -> "123456" # fallback for dev
            token -> 
              # Take first 6 characters of base64 token and convert to digits
              token
              |> String.slice(0, 6)
              |> String.to_charlist()
              |> Enum.map(&rem(&1, 10))
              |> Enum.map(&to_string/1)
              |> Enum.join()
              |> String.pad_leading(6, "0")
          end
        else
          nil
        end
        
        redirect_params = %{email: user.email}
        redirect_params = if verification_code, do: Map.put(redirect_params, :code, verification_code), else: redirect_params

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "Please verify your email address before logging in. We've sent a verification code to your email.")
         |> redirect(to: ~p"/auth/verify?#{redirect_params}")}

      {:ok, {:error, rate_limit_message}} when is_binary(rate_limit_message) ->
        form = to_form(%{"email" => identifier}, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, rate_limit_message)
         |> assign(form: form, errors: [rate_limit_message])}
      
      {:ok, {:error, _reason}} ->
        # Generic error fallback
        form = to_form(%{"email" => identifier}, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Login failed. Please try again.")
         |> assign(form: form, errors: ["Login failed"])}
      
      nil ->
        # Timeout occurred
        form = to_form(%{"email" => identifier}, as: "user")
        
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Login timeout - please try again")
         |> assign(form: form, errors: ["Login timeout"])}
    end
  end

  # ----------------
  # Enhanced registration with security features
  # ----------------
  defp do_register(socket, user_params) do
    user_params = Map.put_new(user_params, "name", user_params["email"])
    ip_address = socket.assigns.ip_address

    case Accounts.register_user(user_params, ip_address: ip_address) do
      {:ok, user, message} ->
        # For dev environment, show the verification code in the URL
        # In production, this would just be sent via email
        verification_code = if get_env() == "dev" do
          # Extract 6-digit code from the verification token for dev display
          case user.email_verification_token do
            nil -> "123456" # fallback for dev
            token -> 
              # Take first 6 characters of base64 token and convert to digits
              token
              |> String.slice(0, 6)
              |> String.to_charlist()
              |> Enum.map(&rem(&1, 10))
              |> Enum.map(&to_string/1)
              |> Enum.join()
              |> String.pad_leading(6, "0")
          end
        else
          nil
        end
        
        redirect_params = %{email: user.email}
        redirect_params = if verification_code, do: Map.put(redirect_params, :code, verification_code), else: redirect_params

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "Account created successfully! #{message}")
         |> redirect(to: ~p"/auth/verify?#{redirect_params}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Enum.map(changeset.errors, fn {field, {msg, opts}} ->
            msg = if opts[:count], do: String.replace(msg, "%{count}", to_string(opts[:count])), else: msg
            "#{String.capitalize(to_string(field))} #{msg}"
          end)

        # Preserve form data on error
        form = to_form(user_params, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Please fix the errors below")
         |> assign(form: form, errors: errors)}
         
      {:error, :email_already_exists_verified} ->
        # Email exists and is verified - show standard error
        form = to_form(user_params, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "An account with this email already exists. Please try logging in instead.")
         |> assign(form: form, errors: ["An account with this email already exists"])}

      {:ok, existing_user, message} when not is_nil(existing_user.email_verification_token) ->
        # This handles the case where a user tries to register with an existing unverified email
        # The accounts module returns {:ok, user, message} for unverified users
        verification_code = if get_env() == "dev" do
          # Extract 6-digit code from the verification token for dev display
          case existing_user.email_verification_token do
            nil -> "123456" # fallback for dev
            token -> 
              # Take first 6 characters of base64 token and convert to digits
              token
              |> String.slice(0, 6)
              |> String.to_charlist()
              |> Enum.map(&rem(&1, 10))
              |> Enum.map(&to_string/1)
              |> Enum.join()
              |> String.pad_leading(6, "0")
          end
        else
          nil
        end
        
        redirect_params = %{email: existing_user.email}
        redirect_params = if verification_code, do: Map.put(redirect_params, :code, verification_code), else: redirect_params

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "#{message}")
         |> redirect(to: ~p"/auth/verify?#{redirect_params}")}
    end
  end

  # ----------------
    # Helper functions
  defp handle_rate_limit_error(message) when is_binary(message) do
    message
  end

  defp handle_rate_limit_error(_), do: "Too many attempts. Please try again later."

  # Email verification actions
  def handle_event("verify_code", %{"verification" => verification_params}, socket) do
    code = verification_params["code"]
    # Use email from form if not already in socket assigns (for direct navigation to verify page)
    email = socket.assigns.verification_email || verification_params["email"]
    
    if !email do
      {:noreply,
       socket
       |> put_flash(:error, "Please provide your email address")
       |> assign(verification_form: to_form(%{}, as: "verification"))}
    else
      case Accounts.verify_user_with_code(email, code) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Email verified successfully! You can now log in.")
           |> redirect(to: ~p"/login")}
        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:error, message)
           |> assign(verification_form: to_form(%{}, as: "verification"))}
      end
    end
  end

  def handle_event("resend_verification", %{"email" => email}, socket) do
    case Accounts.resend_verification_email(email) do
      {:ok, message} ->
        {:noreply, put_flash(socket, :info, message)}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  def handle_event("resend_verification", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please enter your email address")}
  end
  # ----------------
  defp maybe_fetch_user(nil), do: nil
  defp maybe_fetch_user(user_id), do: Accounts.get_user(user_id)

  # ----------------
  # Render
  # ----------------
  def render(assigns) do
    ~H"""
      <.flash_group flash={@flash} />
      
      <!-- Starry Background -->
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <!-- Auth Form -->
      <div class="relative z-10 flex items-center justify-center min-h-[80vh]">
        <div class="bg-gray-900 bg-opacity-90 backdrop-blur-sm p-8 rounded-xl shadow-2xl w-full max-w-md">
          
          <%= if @action == :verify_code do %>
            <!-- Email Verification Form -->
            <h2 class="text-3xl font-bold text-white text-center mb-6">Verify Your Email</h2>
            
            <%= if @verification_email do %>
              <p class="text-gray-300 text-center mb-6">
                We've sent a 6-digit verification code to <span class="text-blue-400"><%= @verification_email %></span>
              </p>
            <% else %>
              <p class="text-gray-300 text-center mb-6">
                Please enter your email address and verification code below.
              </p>
            <% end %>
            
            <%= if @verification_code_for_dev do %>
              <div class="bg-yellow-500 bg-opacity-20 border border-yellow-500 text-yellow-200 px-4 py-3 rounded mb-4">
                <p class="text-sm"><strong>Dev Mode:</strong> Your verification code is <strong><%= @verification_code_for_dev %></strong></p>
              </div>
            <% end %>
            
            <%= if @errors != [] do %>
              <div class="bg-red-500 bg-opacity-20 border border-red-500 text-red-200 px-4 py-3 rounded mb-4">
                <%= for error <- @errors do %>
                  <p><%= error %></p>
                <% end %>
              </div>
            <% end %>
            
            <.form for={@verification_form} phx-submit="verify_code" class="space-y-4">
              <%= if !@verification_email do %>
                <div>
                  <label class="block text-white text-sm font-medium mb-2">Email Address</label>
                  <input 
                    type="email" 
                    name="verification[email]" 
                    required
                    class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                    placeholder="Enter your email address"
                  />
                </div>
              <% end %>
              
              <div>
                <label class="block text-white text-sm font-medium mb-2">Verification Code</label>
                <input 
                  type="text" 
                  name="verification[code]" 
                  maxlength="6"
                  pattern="[0-9]{6}"
                  required
                  class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300 text-center text-2xl tracking-widest"
                  placeholder="000000"
                />
              </div>
              
              <button 
                type="submit"
                class="w-full bg-gradient-to-r from-green-600 to-blue-600 hover:from-green-700 hover:to-blue-700 text-white font-medium py-3 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105"
              >
                Verify Email
              </button>
            </.form>
            
            <div class="mt-6 text-center">
              <%= if @verification_email do %>
                <p class="text-gray-400">
                  Didn't receive the code? 
                  <button phx-click="resend_verification" phx-value-email={@verification_email} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                    Resend
                  </button>
                </p>
              <% else %>
                <p class="text-gray-400">
                  Need to send a new verification code? Enter your email above and we'll resend it.
                </p>
              <% end %>
              
              <p class="text-gray-400 mt-2">
                <.link navigate={~p"/register"} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                  ← Back to Registration
                </.link>
              </p>
            </div>
            
          <% else %>
            <!-- Login/Register Form -->
            <h2 class="text-3xl font-bold text-white text-center mb-6">
              <%= if @action == :login, do: "Sign In", else: "Create Account" %>
            </h2>
            
            <%= if @errors != [] do %>
              <div class="bg-red-500 bg-opacity-20 border border-red-500 text-red-200 px-4 py-3 rounded mb-4">
                <%= for error <- @errors do %>
                  <p><%= error %></p>
                <% end %>
              </div>
            <% end %>
            
            <.form for={@form} phx-submit="submit" class="space-y-4">
              <div>
                <label class="block text-white text-sm font-medium mb-2">
                  <%= if @action == :login, do: "Email or Username", else: "Email" %>
                </label>
                <input 
                  type={if @action == :login, do: "text", else: "email"} 
                  name="user[email]" 
                  value={@form.data["email"] || ""}
                  required
                  class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                  placeholder={if @action == :login, do: "Enter your email or username", else: "Enter your email"}
                />
              </div>
              
              <div :if={@action == :register}>
                <label class="block text-white text-sm font-medium mb-2">Name</label>
                <input 
                  type="text" 
                  name="user[name]" 
                  value={@form.data["name"] || ""}
                  class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                  placeholder="Enter your name"
                />
              </div>
              
              <div>
                <label class="block text-white text-sm font-medium mb-2">Password</label>
                <input 
                  type="password" 
                  name="user[password]" 
                  value={if @action == :register, do: @form.data["password"] || "", else: ""}
                  required
                  class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                  placeholder="Enter your password"
                />
              </div>
              
              <button 
                type="submit"
                disabled={@loading}
                class={"w-full bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium py-3 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105 #{if @loading, do: "opacity-50 cursor-not-allowed", else: ""}"}
              >
                <%= if @loading do %>
                  <div class="flex items-center justify-center">
                    <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    <%= if @action == :login, do: "Signing In...", else: "Creating Account..." %>
                  </div>
                <% else %>
                  <%= if @action == :login, do: "Sign In", else: "Create Account" %>
                <% end %>
              </button>
            </.form>
            
            <div class="mt-6 text-center">
              <%= if @action == :login do %>
                <p class="text-gray-400">
                  Don't have an account? 
                  <.link navigate={~p"/register"} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                    Sign up
                  </.link>
                </p>
              <% else %>
                <p class="text-gray-400">
                  Already have an account? 
                  <.link navigate={~p"/login"} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                    Sign in
                  </.link>
                </p>
              <% end %>
            </div>
          <% end %>
          </div>
      </div>
    """
  end

  defp get_env do
    System.get_env("MIX_ENV") || "dev"
  end
end
