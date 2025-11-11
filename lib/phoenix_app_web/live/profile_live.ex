defmodule PhoenixAppWeb.ProfileLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Accounts


  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    
    # Redirect to login if not authenticated
    if current_user == nil do
      {:ok, push_navigate(socket, to: "/login")}
    else
      changeset = Accounts.change_user_profile(current_user, %{})
      password_changeset = Accounts.User.password_changeset(current_user, %{})
      custom_data = current_user.background_custom_data || %{}

      socket = 
        assign(socket,
          page_title: "Profile Settings",
          user: current_user,
          form: to_form(changeset),
          password_form: to_form(password_changeset),
          show_success: false,
          active_tab: "profile",
          selected_background: current_user.background_preference || "galaxy",
          custom_data: custom_data
        )
        |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png .gif .webp), max_entries: 1, max_file_size: 5_000_000)

      {:ok, socket}
    end
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
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
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
  def handle_event("upload_avatar", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        dest = Path.join([:code.priv_dir(:phoenix_app), "static", "uploads", "avatars", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/avatars/#{entry.uuid}.#{ext(entry)}"}
      end)

    case uploaded_files do
      [avatar_url] ->
        case Accounts.update_user_profile(socket.assigns.user, %{avatar_url: avatar_url}) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(user: updated_user)
             |> assign(form: to_form(Accounts.change_user_profile(updated_user, %{})))
             |> put_flash(:info, "Avatar updated successfully!")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update avatar")}
        end

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_avatar", _params, socket) do
    case Accounts.update_user_profile(socket.assigns.user, %{avatar_url: nil}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(user: updated_user)
         |> assign(form: to_form(Accounts.change_user_profile(updated_user, %{})))
         |> put_flash(:info, "Avatar removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove avatar")}
    end
  end

  @impl true
  def handle_event("select_avatar_color", %{"color" => color}, socket) do
    changeset = 
      socket.assigns.user
      |> Accounts.change_user_profile(%{avatar_color: color})
      |> Map.put(:action, :validate)
    
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("select_background", %{"background" => background}, socket) do
    # Save the background preference immediately
    case Accounts.update_user(socket.assigns.user, %{
      background_preference: background,
      background_custom_data: socket.assigns.custom_data
    }) do
      {:ok, updated_user} ->
        socket = assign(socket, user: updated_user, selected_background: background)
        
        # Push real-time background update via client hook
        {:noreply, push_event(socket, "background_update", %{
          background: background,
          custom_data: socket.assigns.custom_data,
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update background")}
    end
  end

  @impl true
  def handle_event("update_custom_setting", params, socket) do
    # Handle both _target format and direct field updates
    {field, value} = case params do
      %{"_target" => [field]} -> {field, params[field]}
      %{"gradient_start" => value} -> {"gradient_start", value}
      %{"gradient_end" => value} -> {"gradient_end", value}
      %{"solid_color" => value} -> {"solid_color", value}
      _ -> {nil, nil}
    end
    
    if field && value do
      custom_data = socket.assigns.custom_data || %{}
      updated_data = Map.put(custom_data, field, value)
      
      # Save immediately to user preferences
      case Accounts.update_user(socket.assigns.user, %{
        background_custom_data: updated_data
      }) do
        {:ok, updated_user} ->
          socket = assign(socket, user: updated_user, custom_data: updated_data)
          
          # Push real-time background update for custom settings via client hook
          {:noreply, push_event(socket, "background_update", %{
            background: socket.assigns.selected_background,
            custom_data: updated_data,
            global: true
          })}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update background")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_glass_setting", params, socket) do
    # Handle both _target format and direct field updates
    {field, value} = case params do
      %{"_target" => [field]} -> {field, params[field]}
      %{"glass_opacity" => value} -> {"glass_opacity", value}
      %{"glass_blur" => value} -> {"glass_blur", value}
      _ -> {nil, nil}
    end
    
    if field && value do
      custom_data = socket.assigns.custom_data || %{}
      updated_data = Map.put(custom_data, field, value)
      
      # Save immediately to user preferences
      case Accounts.update_user(socket.assigns.user, %{
        background_custom_data: updated_data
      }) do
        {:ok, updated_user} ->
          socket = assign(socket, user: updated_user, custom_data: updated_data)
          
          # Push real-time update to glass theme system via client hook
          {:noreply, push_event(socket, "glass_theme_update", %{
            theme: Map.get(updated_data, "glass_theme", "dark"),
            opacity: Map.get(updated_data, "glass_opacity", "0.3"),
            blur: Map.get(updated_data, "glass_blur", "15"),
            custom_color: Map.get(updated_data, "glass_custom_color"),
            global: true
          })}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save glass setting")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_glass_theme", %{"theme" => theme}, socket) do
    custom_data = socket.assigns.custom_data || %{}
    updated_data = Map.put(custom_data, "glass_theme", theme)
    
    # Save immediately to user preferences
    case Accounts.update_user(socket.assigns.user, %{
      background_custom_data: updated_data
    }) do
      {:ok, updated_user} ->
        socket = 
          socket
          |> assign(user: updated_user, custom_data: updated_data)
          |> put_flash(:info, "Glass theme updated!")
        
        # Push theme update to global glass theme system via client hook
        {:noreply, push_event(socket, "glass_theme_update", %{
          theme: theme,
          opacity: Map.get(updated_data, "glass_opacity", "0.3"),
          blur: Map.get(updated_data, "glass_blur", "15"),
          custom_color: Map.get(updated_data, "glass_custom_color"),
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save glass theme")}
    end
  end

  @impl true
  def handle_event("update_glass_custom_color", %{"color" => color}, socket) do
    custom_data = socket.assigns.custom_data || %{}
    updated_data = Map.put(custom_data, "glass_custom_color", color)
    
    # Save immediately to user preferences
    case Accounts.update_user(socket.assigns.user, %{
      background_custom_data: updated_data
    }) do
      {:ok, updated_user} ->
        socket = assign(socket, user: updated_user, custom_data: updated_data)
        
        # Push real-time update to glass theme system via client hook
        {:noreply, push_event(socket, "glass_theme_update", %{
          theme: Map.get(updated_data, "glass_theme", "dark"),
          opacity: Map.get(updated_data, "glass_opacity", "0.3"),
          blur: Map.get(updated_data, "glass_blur", "15"),
          custom_color: color,
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save custom color")}
    end
  end

  @impl true
  def handle_event("update_gradient_start", %{"color" => color}, socket) do
    custom_data = socket.assigns.custom_data || %{}
    updated_data = Map.put(custom_data, "gradient_start", color)
    
    # Save immediately to user preferences
    case Accounts.update_user(socket.assigns.user, %{
      background_custom_data: updated_data
    }) do
      {:ok, updated_user} ->
        socket = assign(socket, user: updated_user, custom_data: updated_data)
        
        # Push real-time background update
        {:noreply, push_event(socket, "background_update", %{
          background: socket.assigns.selected_background,
          custom_data: updated_data,
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update gradient start color")}
    end
  end

  @impl true
  def handle_event("update_gradient_end", %{"color" => color}, socket) do
    custom_data = socket.assigns.custom_data || %{}
    updated_data = Map.put(custom_data, "gradient_end", color)
    
    # Save immediately to user preferences
    case Accounts.update_user(socket.assigns.user, %{
      background_custom_data: updated_data
    }) do
      {:ok, updated_user} ->
        socket = assign(socket, user: updated_user, custom_data: updated_data)
        
        # Push real-time background update
        {:noreply, push_event(socket, "background_update", %{
          background: socket.assigns.selected_background,
          custom_data: updated_data,
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update gradient end color")}
    end
  end

  @impl true
  def handle_event("update_solid_color", %{"color" => color}, socket) do
    custom_data = socket.assigns.custom_data || %{}
    updated_data = Map.put(custom_data, "solid_color", color)
    
    # Save immediately to user preferences
    case Accounts.update_user(socket.assigns.user, %{
      background_custom_data: updated_data
    }) do
      {:ok, updated_user} ->
        socket = assign(socket, user: updated_user, custom_data: updated_data)
        
        # Push real-time background update
        {:noreply, push_event(socket, "background_update", %{
          background: socket.assigns.selected_background,
          custom_data: updated_data,
          global: true
        })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update solid color")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pointer-events-none" phx-hook="ProfileSettings" id="profile-container">
      <div class="w-full max-w-[85%] mx-auto px-4 py-8 relative z-10 pointer-events-auto">
        <div class="auth-glass-panel p-8 rounded-xl">
        <div class="max-w-4xl mx-auto">
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-white mb-2">Profile Settings</h1>
            <p class="text-gray-400">Manage your account settings and preferences</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Profile Preview -->
            <div class="lg:col-span-1">
              <div class="glass-dark rounded-lg p-6">
                <h2 class="text-lg font-semibold text-white mb-4">Profile Preview</h2>
                <div class="text-center">
                  <div class="inline-block mb-4">
                    <%= if @user.avatar_url do %>
                      <img src={@user.avatar_url} alt="Avatar" class={"w-24 h-24 object-cover mx-auto border-4 #{avatar_shape_classes(@user.avatar_shape)}"} style={"border-color: #{@user.avatar_color || "#3B82F6"}"} />
                    <% else %>
                      <div class={"w-24 h-24 flex items-center justify-center text-white text-2xl font-bold mx-auto border-4 #{avatar_shape_classes(@user.avatar_shape)}"} 
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
              <div class="glass-dark rounded-t-lg border-b-0">
                <div class="flex">
                  <button phx-click="switch_tab" phx-value-tab="profile" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "profile", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Profile Settings
                  </button>
                  <button phx-click="switch_tab" phx-value-tab="appearance" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "appearance", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Background
                  </button>
                  <button phx-click="switch_tab" phx-value-tab="glass_theme" 
                          class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "glass_theme", do: "text-blue-400 border-blue-400 bg-gray-750", else: "text-gray-400 border-transparent hover:text-white"}"}>
                    Glass Theme
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
                <div class="glass-dark rounded-b-lg rounded-tr-lg p-6">
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
                      <label class="block text-sm font-medium text-gray-300 mb-3">Avatar Image</label>
                      <div class="glass-dark rounded-lg p-4 border border-gray-600">
                        <!-- Upload Area -->
                        <div class="flex flex-col items-center justify-center">
                          <%= if @user.avatar_url do %>
                            <div class="mb-4">
                              <img src={@user.avatar_url} alt="Current Avatar" class={"w-32 h-32 object-cover border-4 #{avatar_shape_classes(@user.avatar_shape)}"} style={"border-color: #{@user.avatar_color}"} />
                            </div>
                            <button type="button" phx-click="remove_avatar" class="mb-4 text-red-400 hover:text-red-300 text-sm">
                              Remove Current Avatar
                            </button>
                          <% end %>
                          
                          <div class="w-full">
                            <div class="border-2 border-dashed border-gray-600 rounded-lg p-6 text-center hover:border-gray-500 transition-colors"
                                 phx-drop-target={@uploads.avatar.ref}>
                              <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                                <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                              </svg>
                              <div class="text-sm text-gray-300">
                                <label for={@uploads.avatar.ref} class="cursor-pointer">
                                  <span class="text-blue-400 hover:text-blue-300">Upload a file</span>
                                  <span> or drag and drop</span>
                                </label>
                                <.live_file_input upload={@uploads.avatar} class="sr-only" />
                              </div>
                              <p class="text-xs text-gray-500 mt-2">PNG, JPG, GIF, WEBP up to 5MB</p>
                              <button type="button" phx-click="upload_avatar" class="mt-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm">
                                Upload Avatar
                              </button>
                            </div>
                            
                            <!-- Upload Progress -->
                            <%= for entry <- @uploads.avatar.entries do %>
                              <div class="mt-4 bg-gray-700 rounded-lg p-3">
                                <div class="flex items-center justify-between mb-2">
                                  <span class="text-sm text-gray-300"><%= entry.client_name %></span>
                                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-400 hover:text-red-300">
                                    ✕
                                  </button>
                                </div>
                                <div class="w-full bg-gray-600 rounded-full h-2">
                                  <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                                </div>
                                <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                                  <p class="text-red-400 text-sm mt-1"><%= error_to_string(err) %></p>
                                <% end %>
                                <%= if entry.progress == 100 do %>
                                  <button type="button" phx-click="upload_avatar" class="mt-2 w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded transition-colors">
                                    Save Avatar
                                  </button>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-3">Avatar Color</label>
                      <div class="grid grid-cols-8 gap-2 mb-4">
                        <%= for color <- ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16", "#F97316", "#6366F1", "#14B8A6", "#F43F5E"] do %>
                          <button type="button" 
                                  phx-click="select_avatar_color"
                                  phx-value-color={color}
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

              <%= if @active_tab == "appearance" do %>
                <!-- Appearance Settings -->
                <div class="glass-dark rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
                  <div class="space-y-6">
                    <div>
                      <h2 class="text-2xl font-bold text-white mb-2">Background Theme</h2>
                      <p class="text-gray-400">Choose how your site looks</p>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <!-- Galaxy -->
                      <button
                        phx-click="select_background"
                        phx-value-background="galaxy"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "galaxy", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-gradient-to-br from-indigo-900 via-purple-900 to-black relative">
                          <%= if @selected_background == "galaxy" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Galaxy</h4>
                          <p class="text-sm text-gray-400">Swirling cosmic particles with stars</p>
                        </div>
                      </button>

                      <!-- Nebula -->
                      <button
                        phx-click="select_background"
                        phx-value-background="nebula"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "nebula", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-gradient-to-br from-pink-900 via-purple-900 to-blue-900 relative">
                          <%= if @selected_background == "nebula" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Nebula</h4>
                          <p class="text-sm text-gray-400">Colorful gas clouds with gentle motion</p>
                        </div>
                      </button>

                      <!-- Starfield -->
                      <button
                        phx-click="select_background"
                        phx-value-background="starfield"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "starfield", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-gradient-to-b from-gray-900 to-black relative">
                          <%= for i <- 1..20 do %>
                            <div
                              class="absolute w-1 h-1 bg-white rounded-full opacity-70"
                              style={"left: #{rem(i * 17, 100)}%; top: #{rem(i * 23, 100)}%;"}
                            >
                            </div>
                          <% end %>
                          <%= if @selected_background == "starfield" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold z-10">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Starfield</h4>
                          <p class="text-sm text-gray-400">Classic hyperspace scrolling stars</p>
                        </div>
                      </button>

                      <!-- Void -->
                      <button
                        phx-click="select_background"
                        phx-value-background="void"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "void", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-black relative">
                          <%= for i <- 1..18 do %>
                            <div
                              class="absolute w-1 h-1 bg-white rounded-full opacity-60"
                              style={"left: #{rem(i * 19, 100)}%; top: #{rem(i * 29, 100)}%;"}
                            >
                            </div>
                          <% end %>
                          <%= if @selected_background == "void" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold z-10">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Void</h4>
                          <p class="text-sm text-gray-400">Minimal dark space with subtle stars</p>
                        </div>
                      </button>

                      <!-- Gradient -->
                      <button
                        phx-click="select_background"
                        phx-value-background="gradient"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "gradient", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-gradient-to-br from-blue-600 to-purple-600 relative">
                          <%= if @selected_background == "gradient" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Gradient</h4>
                          <p class="text-sm text-gray-400">Smooth color transitions (customizable)</p>
                        </div>
                      </button>

                      <!-- Solid -->
                      <button
                        phx-click="select_background"
                        phx-value-background="solid"
                        class={"relative overflow-hidden rounded-lg border-2 transition-all duration-300 hover:scale-105 #{if @selected_background == "solid", do: "border-blue-500 ring-2 ring-blue-500 ring-opacity-50", else: "border-gray-700 hover:border-gray-500"}"}
                      >
                        <div class="h-32 bg-gray-900 relative">
                          <%= if @selected_background == "solid" do %>
                            <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded-full text-xs font-bold">
                              ✓ Active
                            </div>
                          <% end %>
                        </div>
                        <div class="bg-gray-900 p-4 text-left">
                          <h4 class="font-bold text-white mb-1">Solid Color</h4>
                          <p class="text-sm text-gray-400">Single color background (customizable)</p>
                        </div>
                      </button>
                    </div>

                    <!-- Custom Settings -->
                    <%= if @selected_background in ["gradient", "solid"] do %>
                      <div class="bg-gray-900 rounded-lg p-6 border border-gray-700">
                        <h4 class="text-lg font-bold text-white mb-4">Customize Colors</h4>
                        
                        <%= if @selected_background == "gradient" do %>
                          <div class="space-y-4">
                            <div>
                              <label class="block text-sm text-gray-400 mb-2">Start Color</label>
                              <input
                                type="color"
                                id={"gradient-start-color-#{get_in(@custom_data, ["gradient_start"]) || "default"}"}
                                value={get_in(@custom_data, ["gradient_start"]) || "#3B82F6"}
                                phx-hook="ColorPicker"
                                data-event="update_gradient_start"
                                class="w-full h-12 rounded cursor-pointer"
                              />
                            </div>
                            <div>
                              <label class="block text-sm text-gray-400 mb-2">End Color</label>
                              <input
                                type="color"
                                id={"gradient-end-color-#{get_in(@custom_data, ["gradient_end"]) || "default"}"}
                                value={get_in(@custom_data, ["gradient_end"]) || "#9333EA"}
                                phx-hook="ColorPicker"
                                data-event="update_gradient_end"
                                class="w-full h-12 rounded cursor-pointer"
                              />
                            </div>
                          </div>
                        <% else %>
                          <div>
                            <label class="block text-sm text-gray-400 mb-2">Background Color</label>
                            <input
                              type="color"
                              id={"solid-color-#{get_in(@custom_data, ["solid_color"]) || "default"}"}
                              value={get_in(@custom_data, ["solid_color"]) || "#1F2937"}
                              phx-hook="ColorPicker"
                              data-event="update_solid_color"
                              class="w-full h-12 rounded cursor-pointer"
                            />
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%= if @active_tab == "glass_theme" do %>
                <!-- Glass Theme Settings -->
                <div class="glass-dark rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
                  <div class="space-y-6">
                    <div>
                      <h2 class="text-2xl font-bold text-white mb-2">Frosted Glass Effects</h2>
                      <p class="text-gray-400">Customize the appearance of panels, navbar, and taskbar. Changes apply instantly.</p>
                    </div>

                    <!-- Glass Color Theme Selection -->
                    <div>
                      <label class="block text-sm text-gray-400 mb-4">Glass Color Theme</label>
                      <div class="grid grid-cols-4 gap-3">
                        <%= for {theme, _color} <- [
                          {"dark", "#111827"}, 
                          {"blue", "#3B82F6"}, 
                          {"purple", "#9333EA"}, 
                          {"green", "#22C55E"},
                          {"red", "#EF4444"}, 
                          {"amber", "#F59E0B"}, 
                          {"teal", "#14B8A6"}, 
                          {"light", "#F9FAFB"}
                        ] do %>
                          <button
                            type="button"
                            phx-click="update_glass_theme"
                            phx-value-theme={theme}
                            class={"w-full h-16 rounded-lg border-2 transition-all #{if get_in(@custom_data, ["glass_theme"]) == theme, do: "border-white ring-2 ring-blue-500", else: "border-gray-600 hover:border-gray-400"} glass-#{theme} flex items-center justify-center"}
                          >
                            <span class="text-white text-sm font-medium"><%= String.capitalize(theme) %></span>
                          </button>
                        <% end %>
                      </div>
                    </div>

                    <!-- Glass Settings Form - Real-time updates -->
                    <form phx-change="update_glass_setting" class="space-y-6">
                <div>
                  <label class="block text-sm text-gray-400 mb-3">Glass Opacity</label>
                  <input
                    type="range"
                    min="0.05"
                    max="0.9"
                    step="0.05"
                    name="glass_opacity"
                    id={"glass-opacity-#{get_in(@custom_data, ["glass_opacity"]) || "0.4"}"}
                    value={get_in(@custom_data, ["glass_opacity"]) || "0.4"}
                    phx-debounce="300"
                    class="w-full h-3 bg-gray-700 rounded-lg appearance-none cursor-pointer slider-blue"
                  />
                  <div class="flex justify-between text-xs text-gray-500 mt-2">
                    <span>More Transparent</span>
                    <span class="text-center">Current: <%= get_in(@custom_data, ["glass_opacity"]) || "0.4" %></span>
                    <span>More Opaque</span>
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm text-gray-400 mb-3">Blur Intensity</label>
                  <input
                    type="range"
                    min="5"
                    max="25"
                    step="5"
                    name="glass_blur"
                    id={"glass-blur-#{get_in(@custom_data, ["glass_blur"]) || "15"}"}
                    value={get_in(@custom_data, ["glass_blur"]) || "15"}
                    phx-debounce="300"
                    class="w-full h-3 bg-gray-700 rounded-lg appearance-none cursor-pointer slider-blue"
                  />
                  <div class="flex justify-between text-xs text-gray-500 mt-2">
                    <span>Less Blur</span>
                    <span class="text-center">Current: <%= get_in(@custom_data, ["glass_blur"]) || "15" %>px</span>
                    <span>More Blur</span>
                  </div>
                </div>                      <!-- Custom Color Picker for Glass -->
                      <div>
                        <label class="block text-sm text-gray-400 mb-3">Custom Glass Color</label>
                        <div class="flex items-center space-x-4">
                          <input
                            type="color"
                            id={"glass-custom-color-picker-#{get_in(@custom_data, ["glass_custom_color"]) || "default"}"}
                            value={get_in(@custom_data, ["glass_custom_color"]) || "#000000"}
                            phx-hook="ColorPicker"
                            data-event="update_glass_custom_color"
                            class="w-20 h-16 rounded-lg cursor-pointer border border-gray-600"
                          />
                          <div class="flex-1">
                            <p class="text-sm text-gray-300">Choose a custom color for your glass panels</p>
                            <p class="text-xs text-gray-500 mt-1">This will override the selected theme color above</p>
                          </div>
                        </div>
                      </div>
                    </form>
                  </div>
                </div>
              <% end %>

              <%= if @active_tab == "security" do %>
                <!-- Security Settings -->
                <div class="glass-dark rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
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
                <div class="glass-dark rounded-b-lg rounded-tr-lg p-6 border border-gray-700">
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
              <div class="glass-dark rounded-lg p-6 border border-gray-700 mt-6">
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
    </div>
    """
  end

  defp avatar_shape_classes(shape) do
    case shape do
      "square" -> "rounded-none"
      "rounded" -> "rounded-lg"
      _ -> "rounded-full"  # default to circle
    end
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(error), do: inspect(error)

  defp ext(entry) do
    entry.client_name
    |> Path.extname()
    |> String.trim_leading(".")
  end
end