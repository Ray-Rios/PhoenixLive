defmodule PhoenixAppWeb.AuthLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts


  # ----------------
  # Mount
  # ----------------
  def mount(_params, session, socket) do
    current_user = maybe_fetch_user(session["user_id"])

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
         loading: false
       )}
    end
  end

  # ----------------
  # Handle URL params
  # ----------------
  def handle_params(_params, uri, socket) do
    action =
      case URI.parse(uri).path do
        "/register" -> :register
        "/login" -> :login
        _ -> :login
      end

    page_title = if action == :login, do: "Sign In", else: "Register"

    {:noreply, assign(socket, action: action, page_title: page_title)}
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
         |> put_flash(:error, "Email is required")
         |> assign(errors: ["Email is required"])}
      
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
  # Login
  # ----------------
  defp do_login(socket, %{"email" => email, "password" => password} = _params) do
    # Add timeout to prevent hanging
    task = Task.async(fn -> Accounts.authenticate_user(email, password) end)
    
    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, {:ok, user}} ->
        # Set the session directly in the socket
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "Welcome back, #{user.email}!")
         |> assign(current_user: user)
         |> redirect(external: "/auth/login_success?user_id=#{user.id}")}

      {:ok, {:error, _reason}} ->
        # Preserve entered email, clear password
        form = to_form(%{"email" => email}, as: "user")

        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Invalid email or password")
         |> assign(form: form, errors: ["Invalid email or password"])}
      
      nil ->
        # Timeout occurred
        form = to_form(%{"email" => email}, as: "user")
        
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Login timeout - please try again")
         |> assign(form: form, errors: ["Login timeout"])}
    end
  end

  # ----------------
  # Register
  # ----------------
  defp do_register(socket, user_params) do
    user_params = Map.put_new(user_params, "name", user_params["email"])

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:info, "Account created successfully! Welcome, #{user.email}!")
         |> assign(current_user: user)
         |> redirect(external: "/auth/login_success?user_id=#{user.id}")}

      {:error, changeset} ->
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
    end
  end

  # ----------------
  # Helper
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
              <label class="block text-white text-sm font-medium mb-2">Email</label>
              <input 
                type="email" 
                name="user[email]" 
                value={@form.data["email"] || ""}
                required
                class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                placeholder="Enter your email"
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
        </div>
      </div>
    """
  end
end
