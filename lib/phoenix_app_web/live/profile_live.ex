defmodule PhoenixAppWeb.ProfileLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts

  on_mount {PhoenixAppWeb.Auth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      socket = 
        socket
        |> assign(
          user: user,
          page_title: "Profile",
          changeset: Accounts.User.profile_changeset(user, %{}),
          password_changeset: Accounts.User.password_changeset(user, %{}),
          two_factor_secret: nil,
          qr_code: nil,
          backup_codes: []
        )
        |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 5_000_000)
      
      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_params(%{"tab" => "security"}, _uri, socket) do
    {:noreply, assign(socket, active_tab: :security)}
  end

  def handle_params(%{"tab" => "orders"}, _uri, socket) do
    orders = PhoenixApp.Commerce.list_user_orders(socket.assigns.current_user)
    {:noreply, assign(socket, active_tab: :orders, orders: orders)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, active_tab: :profile)}
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    changeset = 
      socket.assigns.user
      |> Accounts.User.profile_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save_profile", %{"user" => user_params}, socket) do
    # Handle avatar upload
    uploaded_files = consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      # Resize image to 30x30
      case resize_image(path, 30, 30) do
        {:ok, resized_path} ->
          # Save to public/uploads directory
          filename = "avatar_#{socket.assigns.user.id}_#{System.system_time(:second)}.jpg"
          dest = Path.join(["priv", "static", "uploads", filename])
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(resized_path, dest)
          {:ok, "/uploads/#{filename}"}
        {:error, _} -> {:postpone, :error}
      end
    end)

    # Add avatar URL to user params if uploaded
    user_params = case uploaded_files do
      [avatar_url] -> Map.put(user_params, "avatar_url", avatar_url)
      _ -> user_params
    end

    case Accounts.update_user_profile(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> assign(user: user, changeset: Accounts.User.profile_changeset(user, %{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    changeset = 
      socket.assigns.user
      |> Accounts.User.password_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, password_changeset: changeset)}
  end

  def handle_event("change_password", %{"user" => user_params}, socket) do
    current_password = user_params["current_password"]
    
    if Accounts.User.valid_password?(socket.assigns.user, current_password) do
      case Accounts.update_user_password(socket.assigns.user, user_params) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password changed successfully")
           |> assign(password_changeset: Accounts.User.password_changeset(socket.assigns.user, %{}))}

        {:error, changeset} ->
          {:noreply, assign(socket, password_changeset: changeset)}
      end
    else
      changeset = 
        socket.assigns.user
        |> Accounts.User.password_changeset(user_params)
        |> Ecto.Changeset.add_error(:current_password, "is incorrect")

      {:noreply, assign(socket, password_changeset: changeset)}
    end
  end

  def handle_event("setup_2fa", _params, socket) do
    secret = Accounts.User.generate_two_factor_secret()
    user_email = socket.assigns.user.email
    
    qr_code_data = "otpauth://totp/PhoenixApp:#{user_email}?secret=#{secret}&issuer=PhoenixApp"
    {:ok, qr_code} = QRCode.create(qr_code_data)
    qr_svg = QRCode.render(qr_code)

    {:noreply, assign(socket, 
      two_factor_secret: secret,
      qr_code: qr_svg,
      backup_codes: Accounts.User.generate_backup_codes()
    )}
  end

  def handle_event("enable_2fa", %{"token" => token}, socket) do
    if :pot.valid_totp(token, socket.assigns.two_factor_secret, window: 1) do
      case Accounts.enable_two_factor(socket.assigns.user, socket.assigns.two_factor_secret, socket.assigns.backup_codes) do
        {:ok, user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Two-factor authentication enabled successfully")
           |> assign(user: user, two_factor_secret: nil, qr_code: nil)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to enable two-factor authentication")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid verification code")}
    end
  end

  def handle_event("disable_2fa", _params, socket) do
    case Accounts.disable_two_factor(socket.assigns.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Two-factor authentication disabled")
         |> assign(user: user)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to disable two-factor authentication")}
    end
  end

  defp resize_image(path, width, height) do
    try do
      # Use ImageMagick via System.cmd if available, otherwise just copy
      case System.cmd("convert", [path, "-resize", "#{width}x#{height}!", path <> "_resized"]) do
        {_, 0} -> {:ok, path <> "_resized"}
        _ -> {:ok, path}  # Fallback to original if convert fails
      end
    rescue
      _ -> {:ok, path}  # Fallback to original if any error
    end
  end

  defp error_to_string(:too_large), do: "File too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type (only JPG, PNG allowed)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <div class="starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <!-- Inner content -->
      <div class="w-full max-w-[80%] mx-auto px-4 py-8 relative z-10 mt-[50px]">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-3xl font-bold text-white mb-8">Profile Settings</h1>
          
          <!-- Tab Navigation -->
          <div class="flex space-x-4 mb-8">
            <.link 
              patch="/profile" 
              class={["px-4 py-2 rounded-lg transition-colors", 
                     if(@active_tab == :profile, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}
            >
              Profile
            </.link>
            <.link 
              patch="/profile/security" 
              class={["px-4 py-2 rounded-lg transition-colors", 
                     if(@active_tab == :security, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}
            >
              Security
            </.link>
            <.link 
              patch="/profile/orders" 
              class={["px-4 py-2 rounded-lg transition-colors", 
                     if(@active_tab == :orders, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}
            >
              Orders
            </.link>
          </div>

          <!-- Profile Tab -->
          <div :if={@active_tab == :profile} class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-semibold text-white mb-6">Profile Information</h2>
            
            <.form :let={f} for={@changeset} phx-change="validate_profile" phx-submit="save_profile" multipart>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">Name</label>
                  <.input field={f[:name]} class="bg-gray-700 text-white" maxlength="20" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">Email</label>
                  <.input field={f[:email]} disabled class="bg-gray-600 text-gray-400" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">Avatar Shape</label>
                  <.input field={f[:avatar_shape]} type="select" 
                          options={[{"Circle", "circle"}, {"Square", "square"}, {"Rounded", "rounded"}]}
                          class="bg-gray-700 text-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">Avatar Color</label>
                  <.input field={f[:avatar_color]} type="color" class="bg-gray-700" />
                </div>
              </div>
              
              <div class="mt-6">
                <label class="block text-sm font-medium text-gray-300 mb-2">Avatar Upload (30x30px)</label>
                <.live_file_input upload={@uploads.avatar} class="block w-full text-sm text-gray-300
                                                           file:mr-4 file:py-2 file:px-4
                                                           file:rounded-full file:border-0
                                                           file:text-sm file:font-semibold
                                                           file:bg-blue-50 file:text-blue-700
                                                           hover:file:bg-blue-100" />
                
                <%= for entry <- @uploads.avatar.entries do %>
                  <div class="mt-2">
                    <div class="text-sm text-gray-400">
                      <%= entry.client_name %> - <%= entry.progress %>%
                    </div>
                    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                      <div class="text-red-400 text-sm"><%= error_to_string(err) %></div>
                    <% end %>
                  </div>
                <% end %>
              </div>
              
              <div class="mt-6">
                <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
                  Save Changes
                </button>
              </div>
            </.form>
          </div>

          <!-- Security Tab -->
          <div :if={@active_tab == :security} class="space-y-6">
            <!-- Change Password -->
            <div class="bg-gray-800 rounded-lg p-6">
              <h2 class="text-xl font-semibold text-white mb-6">Change Password</h2>
              
              <.form for={@password_changeset} phx-change="validate_password" phx-submit="change_password">
                <div class="space-y-4">
                  <.input field={@password_changeset[:current_password]} type="password" label="Current Password" class="bg-gray-700 text-white" />
                  <.input field={@password_changeset[:password]} type="password" label="New Password" class="bg-gray-700 text-white" />
                  <.input field={@password_changeset[:password_confirmation]} type="password" label="Confirm New Password" class="bg-gray-700 text-white" />
                </div>
                
                <div class="mt-6">
                  <button type="submit" class="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors">
                    Change Password
                  </button>
                </div>
              </.form>
            </div>

            <!-- Two-Factor Authentication -->
            <div class="bg-gray-800 rounded-lg p-6">
              <h2 class="text-xl font-semibold text-white mb-6">Two-Factor Authentication</h2>
              
              <div :if={!@user.two_factor_enabled and !@two_factor_secret}>
                <p class="text-gray-300 mb-4">Add an extra layer of security to your account.</p>
                <button phx-click="setup_2fa" class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded-lg transition-colors">
                  Enable 2FA
                </button>
              </div>

              <div :if={@two_factor_secret}>
                <p class="text-gray-300 mb-4">Scan this QR code with your authenticator app:</p>
                <div class="bg-white p-4 rounded-lg inline-block mb-4">
                  <%= Phoenix.HTML.raw(@qr_code) %>
                </div>
                
                <div class="mb-4">
                  <h3 class="text-lg font-medium text-white mb-2">Backup Codes</h3>
                  <p class="text-gray-300 text-sm mb-2">Save these backup codes in a safe place:</p>
                  <div class="bg-gray-700 p-4 rounded-lg">
                    <%= for code <- @backup_codes do %>
                      <div class="font-mono text-sm text-gray-300"><%= code %></div>
                    <% end %>
                  </div>
                </div>

                <form phx-submit="enable_2fa">
                  <input type="text" name="token" placeholder="Enter verification code" 
                         class="bg-gray-700 text-white px-4 py-2 rounded-lg mr-4" />
                  <button type="submit" class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded-lg transition-colors">
                    Verify & Enable
                  </button>
                </form>
              </div>

              <div :if={@user.two_factor_enabled}>
                <p class="text-green-400 mb-4">✓ Two-factor authentication is enabled</p>
                <button phx-click="disable_2fa" class="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors">
                  Disable 2FA
                </button>
              </div>
            </div>
          </div>

          <!-- Orders Tab -->
          <div :if={@active_tab == :orders} class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-semibold text-white mb-6">Order History</h2>
            
            <div :if={@orders == []} class="text-gray-400 text-center py-8">
              No orders found.
            </div>

            <div :for={order <- @orders || []} class="border-b border-gray-700 pb-4 mb-4 last:border-b-0">
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="font-semibold text-white">Order #<%= String.slice(order.id, -8..-1) %></h3>
                  <p class="text-gray-400 text-sm"><%= Calendar.strftime(order.inserted_at, "%B %d, %Y") %></p>
                  <p class="text-lg font-bold text-green-400">$<%= order.total_amount %></p>
                </div>
                <span class={["px-3 py-1 rounded-full text-sm font-medium",
                             case order.status do
                               "pending" -> "bg-yellow-600 text-yellow-100"
                               "processing" -> "bg-blue-600 text-blue-100"
                               "shipped" -> "bg-purple-600 text-purple-100"
                               "delivered" -> "bg-green-600 text-green-100"
                               "cancelled" -> "bg-red-600 text-red-100"
                             end]}>
                  <%= String.capitalize(order.status) %>
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end