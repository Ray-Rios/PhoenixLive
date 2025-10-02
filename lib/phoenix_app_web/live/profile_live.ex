defmodule PhoenixAppWeb.ProfileLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts


  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    changeset = Accounts.change_user_profile(current_user, %{})
    password_changeset = Accounts.User.password_change_changeset(current_user, %{})

    {:ok,
     assign(socket,
       page_title: "Profile Settings",
       user: current_user,
       form: to_form(changeset),
       password_form: to_form(password_changeset),
       show_success: false,
       active_tab: "profile"
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("validate_password", %{"user" => password_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.User.password_change_changeset(password_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, password_form: to_form(changeset))}
  end

  @impl true
  def handle_event("change_password", %{"user" => password_params}, socket) do
    case Accounts.update_user_password(socket.assigns.user, password_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(Accounts.User.password_changeset(socket.assigns.user, %{})))
         |> put_flash(:info, "Password updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:form, to_form(Accounts.change_user_profile(user, %{})))
         |> assign(:show_success, true)
         |> put_flash(:info, "Profile updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("resend_verification", _params, socket) do
    case PhoenixApp.Accounts.EmailVerification.send_verification_email(socket.assigns.user) do
      {:ok, _message} ->
        {:noreply,
         socket
         |> put_flash(:info, "Verification email sent! Please check your inbox.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send verification email: #{reason}")}
    end
  end

  @impl true
  def handle_event("close_success", _params, socket) do
    {:noreply, assign(socket, show_success: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <.navbar current_user={@current_user} />
      
      <div class="w-full max-w-[85%] mx-auto px-4 py-8 relative z-10">
        <div class="max-w-4xl mx-auto">
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-white mb-2">Profile Settings</h1>
            <p class="text-gray-400">Manage your account settings and preferences</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Profile Preview -->
            <div class="lg:col-span-1">
              <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
                <h2 class="text-lg font-semibold text-white mb-4">Profile Preview</h2>
                <div class="text-center">
                  <div class="inline-block mb-4">
                    <%= if @user.avatar_url do %>
                      <img src={@user.avatar_url} alt="Avatar" class="w-24 h-24 rounded-full object-cover mx-auto border-4" style={"border-color: #{@user.avatar_color || "#3B82F6"}"} />
                    <% else %>
                      <div class="w-24 h-24 rounded-full flex items-center justify-center text-white text-2xl font-bold mx-auto border-4" 
                           style={"background-color: #{@user.avatar_color || "#3B82F6"}; border-color: #{@user.avatar_color || "#3B82F6"}"}>
                        <%= String.first(@user.name || @user.email) |> String.upcase() %>
                      </div>
                    <% end %>
                  </div>
                  <h3 class="text-xl font-semibold text-white mb-1"><%= @user.name || "No name set" %></h3>
                  <p class="text-gray-400 mb-2"><%= @user.email %></p>
                  <div class="flex items-center justify-center space-x-2 text-sm">
                    <%= if @user.is_admin do %>
                      <span class="bg-purple-600 text-white px-2 py-1 rounded-full text-xs">Admin</span>
                    <% end %>
                    <%= if @user.email_verified_at do %>
                      <span class="bg-green-600 text-white px-2 py-1 rounded-full text-xs">Verified</span>
                    <% else %>
                      <span class="bg-yellow-600 text-white px-2 py-1 rounded-full text-xs">Unverified</span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Profile Settings Form -->
            <div class="lg:col-span-2">
              <!-- Tabs -->
              <div class="bg-gray-800 rounded-t-lg border border-gray-700 border-b-0">
                <div class="flex">
                  <button phx-click="switch_tab" phx-value-tab="profile" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "profile", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Profile Settings
                  </button>
                  <button phx-click="switch_tab" phx-value-tab="security" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "security", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Security
                  </button>
                  <button phx-click="switch_tab" phx-value-tab="email" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "email", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Email Settings
                  </button>
                </div>
              </div>

              <!-- Tab Content -->
              <%= if @active_tab == "profile" do %>
                <!-- Profile Settings -->
                <div class="bg-gray-800 rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
                  <h2 class="text-lg font-semibold text-white mb-6">Profile Settings</h2>

                  <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div>
                        <.input field={@form[:name]} label="Display Name" placeholder="Enter your name..." />
                      </div>
                      
                      <div>
                        <.input field={@form[:email]} label="Email Address" placeholder="your@email.com" />
                      </div>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-3">Avatar Color</label>
                      <div class="grid grid-cols-8 gap-2 mb-4">
                        <%= for color <- ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16", "#F97316", "#6366F1", "#14B8A6", "#F43F5E"] do %>
                          <button type="button" 
                                  phx-click={Phoenix.LiveView.JS.exec("document.getElementById('user_avatar_color').value = '#{color}'; document.getElementById('user_avatar_color').dispatchEvent(new Event('input', { bubbles: true }))")}
                                  class={"w-10 h-10 rounded-full border-2 hover:scale-110 transition-transform #{if Phoenix.HTML.Form.input_value(@form, :avatar_color) == color, do: "border-white", else: "border-gray-600"}"}
                                  style={"background-color: #{color}"}>
                          </button>
                        <% end %>
                      </div>
                      <.input field={@form[:avatar_color]} type="color" label="Custom Color" />
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-2">Avatar Shape</label>
                      <select name="user[avatar_shape]" class="w-full bg-gray-700 text-white px-4 py-2 rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none">
                        <option value="circle" selected={Phoenix.HTML.Form.input_value(@form, :avatar_shape) == "circle"}>Circle</option>
                        <option value="square" selected={Phoenix.HTML.Form.input_value(@form, :avatar_shape) == "square"}>Square</option>
                        <option value="rounded" selected={Phoenix.HTML.Form.input_value(@form, :avatar_shape) == "rounded"}>Rounded Square</option>
                      </select>
                    </div>

                    <div class="pt-4">
                      <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors font-medium">
                        Save Changes
                      </button>
                    </div>
                  </.form>
                </div>
              <% end %>

              <%= if @active_tab == "security" do %>
                <!-- Security Settings -->
                <div class="bg-gray-800 rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
                  <h2 class="text-lg font-semibold text-white mb-6">Security Settings</h2>

                  <.form for={@password_form} phx-submit="change_password" phx-change="validate_password" class="space-y-6">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div>
                        <.input field={@password_form[:current_password]} type="password" label="Current Password" placeholder="Enter current password..." />
                      </div>
                      <div>
                        <.input field={@password_form[:password]} type="password" label="New Password" placeholder="Enter new password..." />
                      </div>
                    </div>

                    <div>
                      <.input field={@password_form[:password_confirmation]} type="password" label="Confirm New Password" placeholder="Confirm new password..." />
                    </div>

                    <div class="pt-4">
                      <button type="submit" class="bg-red-600 hover:bg-red-700 text-white px-6 py-3 rounded-lg transition-colors font-medium">
                        Change Password
                      </button>
                    </div>
                  </.form>

                  <hr class="border-gray-600 my-6">

                  <div>
                    <h3 class="text-lg font-medium text-white mb-4">Two-Factor Authentication</h3>
                    <%= if @user.two_factor_enabled do %>
                      <div class="flex items-center space-x-2 text-green-400 mb-4">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                        </svg>
                        <span>Two-factor authentication is enabled</span>
                      </div>
                      <button class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg transition-colors text-sm">
                        Disable 2FA
                      </button>
                    <% else %>
                      <div class="flex items-center space-x-2 text-yellow-400 mb-4">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                        </svg>
                        <span>Two-factor authentication is disabled</span>
                      </div>
                      <p class="text-gray-400 text-sm mb-4">Add an extra layer of security to your account by enabling two-factor authentication.</p>
                      <button class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors text-sm">
                        Enable 2FA
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%= if @active_tab == "email" do %>
                <!-- Email Settings -->
                <div class="bg-gray-800 rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
                  <h2 class="text-lg font-semibold text-white mb-6">Email Settings</h2>

                  <div class="space-y-6">
                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Primary Email Address</h3>
                      <div class="bg-gray-700 rounded-lg p-4">
                        <div class="flex items-center justify-between">
                          <div>
                            <p class="text-white font-medium"><%= @user.email %></p>
                            <%= if @user.email_verified_at do %>
                              <div class="flex items-center space-x-2 text-green-400 mt-1">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                </svg>
                                <span class="text-sm">Verified</span>
                              </div>
                            <% else %>
                              <div class="flex items-center space-x-2 text-yellow-400 mt-1">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L5.082 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
                                </svg>
                                <span class="text-sm">Not Verified</span>
                              </div>
                            <% end %>
                          </div>
                          <%= unless @user.email_verified_at do %>
                            <button phx-click="resend_verification" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors text-sm">
                              Send Verification
                            </button>
                          <% end %>
                        </div>
                      </div>
                    </div>

                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Email Notifications</h3>
                      <div class="space-y-3">
                        <label class="flex items-center">
                          <input type="checkbox" class="rounded bg-gray-700 border-gray-600 text-blue-600 focus:ring-blue-500 focus:ring-2" checked>
                          <span class="ml-2 text-gray-300">Account security alerts</span>
                        </label>
                        <label class="flex items-center">
                          <input type="checkbox" class="rounded bg-gray-700 border-gray-600 text-blue-600 focus:ring-blue-500 focus:ring-2" checked>
                          <span class="ml-2 text-gray-300">Important updates</span>
                        </label>
                        <label class="flex items-center">
                          <input type="checkbox" class="rounded bg-gray-700 border-gray-600 text-blue-600 focus:ring-blue-500 focus:ring-2">
                          <span class="ml-2 text-gray-300">Marketing emails</span>
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Account Information -->
              <div class="bg-gray-800 rounded-lg p-6 border border-gray-700 mt-6">
                <h3 class="text-lg font-semibold text-white mb-4">Account Information</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-gray-400">Member since:</span>
                    <span class="text-white ml-2"><%= Calendar.strftime(@user.inserted_at, "%B %d, %Y") %></span>
                  </div>
                  <div>
                    <span class="text-gray-400">Last login:</span>
                    <span class="text-white ml-2">
                      <%= if @user.last_login_at do %>
                        <%= Calendar.strftime(@user.last_login_at, "%m/%d/%Y %I:%M %p") %>
                      <% else %>
                        Never
                      <% end %>
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-400">Account status:</span>
                    <span class="text-white ml-2"><%= String.capitalize(@user.status || "active") %></span>
                  </div>
                  <div>
                    <span class="text-gray-400">Two-factor auth:</span>
                    <span class="text-white ml-2">
                      <%= if @user.two_factor_enabled, do: "Enabled", else: "Disabled" %>
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end