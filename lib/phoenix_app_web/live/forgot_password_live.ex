defmodule PhoenixAppWeb.ForgotPasswordLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts
  
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
      form_data = %{}
      form = to_form(form_data, as: "forgot_password")
      
      {:ok,
       assign(socket,
         current_user: current_user,
         form: form,
         form_data: form_data,
         errors: [],
         loading: false,
         ip_address: ip_address,
         captcha_token: nil,
         show_captcha: captcha_required?(),
         success_message: nil,
         page_title: "Forgot Password"
       )}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"forgot_password" => params}, socket) do
    form_data = Map.merge(socket.assigns.form_data, params)
    form = to_form(form_data, as: "forgot_password")
    
    # Don't clear errors on validate, and preserve captcha token
    {:noreply, assign(socket, form: form, form_data: form_data)}
  end

  def handle_event("submit", %{"forgot_password" => params}, socket) do
    email_or_username = String.trim(params["email_or_username"] || "")
    captcha_token = socket.assigns.captcha_token
    ip_address = socket.assigns.ip_address

    # Validate captcha if required
    if socket.assigns.show_captcha and is_nil(captcha_token) do
      {:noreply, put_flash(socket, :error, "Please complete the captcha")}
    else
      # Verify captcha if present
      captcha_valid = if socket.assigns.show_captcha do
        PhoenixApp.Captcha.verify_hcaptcha(captcha_token, ip_address)
      else
        true
      end

      if captcha_valid do
        # Set loading state
        socket = assign(socket, loading: true)
        
        # Process forgot password request
        case Accounts.send_password_reset_email(email_or_username, ip_address) do
          {:ok, _message} ->
            {:noreply,
             socket
             |> assign(loading: false, success_message: "If an account with that email/username exists, you should receive an email with instructions shortly.")
             |> assign(captcha_token: nil)  # Reset captcha but keep form data
            }
          {:error, :rate_limited} ->
            {:noreply,
             socket
             |> assign(loading: false)
             |> put_flash(:error, "Too many password reset attempts. Please wait before trying again.")
            }
          {:error, message} ->
            {:noreply,
             socket
             |> assign(loading: false)
             |> put_flash(:error, message)
            }
        end
      else
        {:noreply,
         socket
         |> assign(loading: false)
         |> put_flash(:error, "Invalid captcha. Please try again.")
        }
      end
    end
  end

  # Handle hCaptcha token from JavaScript  
  def handle_event("captcha_verified", %{"token" => token}, socket) do
    # Only update the captcha token, preserve everything else
    {:noreply, assign(socket, :captcha_token, token)}
  end

  def handle_event("captcha_error", _params, socket) do
    {:noreply, assign(socket, :captcha_token, nil)}
  end

  def handle_event("captcha_expired", _params, socket) do
    {:noreply, assign(socket, :captcha_token, nil)}
  end

  # Keep the old event names for backwards compatibility
  def handle_event("hcaptcha-token", %{"token" => token}, socket) do
    {:noreply, assign(socket, :captcha_token, token)}
  end

  def handle_event("hcaptcha-expired", _params, socket) do
    {:noreply, assign(socket, :captcha_token, nil)}
  end

  def handle_event("hcaptcha-error", _params, socket) do
    {:noreply, assign(socket, :captcha_token, nil)}
  end

  defp maybe_fetch_user(nil), do: nil
  defp maybe_fetch_user(user_id) when is_binary(user_id) do
    case PhoenixApp.Accounts.get_user(user_id) do
      nil -> nil
      user -> user
    end
  end

  defp captcha_required? do
    # Always require captcha for forgot password to prevent abuse
    true
  end

  defp get_hcaptcha_site_key do
    System.get_env("HCAPTCHA_SITE_KEY") || "10000000-ffff-ffff-ffff-000000000001"
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-blue-900 flex items-center justify-center px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div class="text-center">
          <h2 class="mt-6 text-3xl font-extrabold text-white">
            Forgot your password?
          </h2>
          <p class="mt-2 text-sm text-gray-300">
            Enter your email address or username and we'll send you a link to reset your password.
          </p>
        </div>

        <%= if @success_message do %>
          <div class="bg-green-800 border border-green-600 text-green-200 px-4 py-3 rounded-lg mb-6">
            <%= @success_message %>
          </div>
          <div class="text-center">
            <p class="text-gray-400">
              Remember your password? 
              <.link navigate={~p"/login"} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                Sign in
              </.link>
            </p>
          </div>
        <% else %>
          <div class="bg-gray-800 bg-opacity-50 backdrop-blur-lg rounded-xl shadow-2xl p-8 border border-gray-700">
          <.form 
            for={@form} 
            phx-submit="submit" 
            phx-change="validate"
            class="space-y-6"
          >
            <div>
              <label for="forgot_password_email_or_username" class="block text-sm font-medium text-gray-300 mb-2">
                Email Address or Username
              </label>
              <input 
                type="text" 
                name="forgot_password[email_or_username]" 
                id="forgot_password_email_or_username"
                value={@form_data["email_or_username"] || ""}
                required
                class="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                placeholder="Enter your email or username"
              />
            </div>
            
            <!-- CAPTCHA Widget -->
            <%= if @show_captcha do %>
              <div class="captcha-container" phx-update="ignore" id="captcha-container">
                <div 
                  id="hcaptcha-widget" 
                  phx-hook="HCaptcha" 
                  data-sitekey={get_hcaptcha_site_key()}
                  class="flex justify-center"
                ></div>
              </div>
            <% end %>
            
            <button 
              type="submit"
              disabled={@loading or (@show_captcha and is_nil(@captcha_token))}
              class={"w-full bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium py-3 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105 #{if @loading or (@show_captcha and is_nil(@captcha_token)), do: "opacity-50 cursor-not-allowed", else: ""}"}
            >
              <%= if @loading do %>
                <div class="flex items-center justify-center">
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Sending Reset Link...
                </div>
              <% else %>
                Send Reset Link
              <% end %>
            </button>
          </.form>
          
          <div class="mt-6 text-center">
            <p class="text-gray-400">
              Remember your password? 
              <.link navigate={~p"/login"} class="text-blue-400 hover:text-blue-300 transition-colors duration-300">
                Sign in
              </.link>
            </p>
          </div>
        </div>
        <% end %>
      </div>
    </div>
    """
  end
end