defmodule PhoenixAppWeb.AuthLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  import Phoenix.LiveView.Helpers

  # ----------------
  # Mount
  # ----------------
  def mount(_params, session, socket) do
    current_user = maybe_fetch_user(session["user_id"])

    {:ok,
     assign(socket,
       current_user: current_user,
       form: to_form(%{}, as: "user"),
       errors: [],
       action: :login
     )}
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
    case socket.assigns.action do
      :login -> do_login(socket, user_params)
      :register -> do_register(socket, user_params)
    end
  end

  # ----------------
  # Login
  # ----------------
  defp do_login(socket, %{"email" => email, "password" => password} = _params) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back, #{user.email}!")
         |> redirect(external: "/auth/login_success?user_id=#{user.id}")}

      {:error, _reason} ->
        # Preserve entered email, clear password
        form = to_form(%{"email" => email}, as: "user")

        {:noreply,
         socket
         |> put_flash(:error, "Invalid email or password")
         |> assign(form: form, errors: ["Invalid email or password"])}
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
         |> put_flash(:info, "Account created successfully! Welcome, #{user.email}!")
         |> redirect(external: "/auth/login_success?user_id=#{user.id}")}

      {:error, changeset} ->
        errors =
          Enum.map(changeset.errors, fn {field, {msg, opts}} ->
            msg = if opts[:count], do: String.replace(msg, "%{count}", to_string(opts[:count])), else: msg
            "#{String.capitalize(to_string(field))} #{msg}"
          end)

        {:noreply,
         socket
         |> put_flash(:error, "Please fix the errors below")
         |> assign(errors: errors)}
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
    <.navbar current_user={@current_user} />
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
            
            <div>
              <label class="block text-white text-sm font-medium mb-2">Password</label>
              <input 
                type="password" 
                name="user[password]" 
                required
                class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                placeholder="Enter your password"
              />
            </div>
            
            <button 
              type="submit"
              class="w-full bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium py-3 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105"
            >
              <%= if @action == :login, do: "Sign In", else: "Create Account" %>
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
