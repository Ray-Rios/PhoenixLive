defmodule PhoenixAppWeb.Components.Navigation do
  use PhoenixAppWeb, :html

  def navbar(assigns) do
    ~H"""
    <!-- Navigation Toggle Button -->
    <button id="nav-toggle" 
            class="fixed top-0 right-0 z-[60] bg-gray-800 hover:bg-gray-700 text-white p-2 pr-4 shadow-lg transition-all duration-300"
            onclick="toggleNavbar()">
      <svg id="nav-toggle-icon" class="w-3 h-3 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
      </svg>
    </button>

    <nav id="main-navbar" class="bg-black bg-opacity-50 backdrop-blur-sm border-b border-gray-700 fixed top-0 left-0 z-50 w-full h-[47px] transition-transform duration-300 ease-in-out">
      <div class="px-4">
        <div class="flex top-8 justify-between items-center">
          <!-- Left side - Logo and main navigation -->
          <div class="flex items-center space-x-4 flex-1 min-w-0">
            <.link navigate={~p"/dashboard"} class="text-xl font-bold text-white hover:text-blue-400 transition-colors duration-300 flex-shrink-0">
              HTBX
            </.link>
            <div class="hidden lg:flex space-x-4 flex-1 justify-center">
              <.link navigate={~p"/shop"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                Shop
              </.link>
              <.link navigate={~p"/cart"} class="text-white hover:text-blue-400 transition-colors duration-300 relative text-sm">
                🛒 Cart
                <%= if @current_user do %>
                  <span class="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                    <%= get_cart_item_count(@current_user) %>
                  </span>
                <% end %>
              </.link>
              <.link navigate={~p"/chat"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                💬 Chat
              </.link>
              <.link navigate={~p"/quest"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                🎮 Quest
              </.link>
              <.link navigate={~p"/desktop"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                🖥️ Desktop
              </.link>
              <.link navigate={~p"/terminal"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                💻 Terminal
              </.link>
              <.link navigate={~p"/blog"} class="text-white hover:text-blue-400 transition-colors duration-300 text-sm">
                📝 Blog
              </.link>
            </div>
          </div>
          
          <!-- Right side - User menu -->
          <div class="flex items-center space-x-2 flex-shrink-0" style="margin-right: 25px;">
            <%= if @current_user do %>
              <!-- User Avatar and Dropdown -->
              <div class="relative" x-data="{ open: false }" x-init="open = false" @click.away="open = false">
                <button @click="open = !open" class="flex items-center space-x-1 text-white hover:text-blue-400 transition-colors duration-300 min-w-0">
                  <%= if get_user_avatar_url(@current_user) do %>
                    <img src={get_user_avatar_url(@current_user)} alt="Avatar" class="w-6 h-6 rounded-full object-cover flex-shrink-0" />
                  <% else %>
                    <div class="w-6 h-6 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0" 
                         style={"background-color: #{get_user_avatar_color(@current_user)}"}>
                      <%= get_user_initial(@current_user) %>
                    </div>
                  <% end %>
                  <span class="hidden sm:block text-xs truncate max-w-[80px]"><%= get_user_display_name(@current_user) %></span>
                  <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                  </svg>
                </button>
                
                <!-- Dropdown Menu -->
                <div x-show="open" 
                     x-cloak
                     class="absolute dropdown-menu w-48 bg-gray-800 rounded-md shadow-lg py-1 z-50"
                     x-transition:enter="transition ease-out duration-200"
                     x-transition:enter-start="transform translate-x-full opacity-0"
                     x-transition:enter-end="transform translate-x-0 opacity-100"
                     x-transition:leave="transition ease-in duration-150"
                     x-transition:leave-start="transform translate-x-0 opacity-100"
                     x-transition:leave-end="transform translate-x-full opacity-0">
                  <.link navigate={~p"/profile"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white">
                    👤 Profile Settings
                  </.link>
                  <.link navigate={~p"/files"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white">
                    📁 Files
                  </.link>
                  <%= if @current_user.is_admin do %>
                    <.link navigate={~p"/admin/user-management"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white">
                      👥 User Management
                    </.link>
                  <% end %>
                  <hr class="border-gray-600 my-1">
                  <.link navigate={~p"/auth/logout"} class="block px-4 py-2 text-sm text-red-300 hover:bg-gray-700 hover:text-red-200">
                    🚪 Logout
                  </.link>
                </div>
              </div>
            <% else %>
              <!-- Login/Register buttons -->
              <.link navigate={~p"/login"} class="text-white hover:text-blue-400 transition-colors duration-300">
                Login
              </.link>
              <.link navigate={~p"/register"} class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors duration-300">
                Register
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </nav>

    <script>
      function toggleNavbar() {
        const navbar = document.getElementById('main-navbar');
        const icon = document.getElementById('nav-toggle-icon');
        const body = document.body;
        
        if (navbar.style.transform === 'translateY(-80%)') {
          // Show navbar
          navbar.style.transform = 'translateY(0)';
          icon.style.transform = 'rotate(0deg)';
          body.style.paddingTop = '50px';
        } else {
          // Hide navbar
          navbar.style.transform = 'translateY(-100%)';
          icon.style.transform = 'rotate(180deg)';
          body.style.paddingTop = '0px';
        }
      }
      
      // Initialize navbar state
      document.addEventListener('DOMContentLoaded', function() {
        document.body.style.paddingTop = '50px';
      });
    </script>
    """
  end

  defp get_cart_item_count(user) do
    cond do
      is_nil(user) -> 0
      is_binary(user) -> 
        # Handle case where user is passed as string ID (shouldn't happen but let's be safe)
        case PhoenixApp.Accounts.get_user(user) do
          nil -> 0
          user_struct -> get_cart_item_count(user_struct)
        end
      is_map(user) ->
        # TODO: Implement cart functionality
        # For now, return 0 until cart system is implemented
        0
      true -> 0
    end
  end

  defp get_user_avatar_color(user) do
    cond do
      is_map(user) && Map.has_key?(user, :avatar_color) && user.avatar_color -> user.avatar_color
      is_map(user) && Map.has_key?(user, "avatar_color") && user["avatar_color"] -> user["avatar_color"]
      true -> "#4ECDC4"
    end
  end

  defp get_user_initial(user) do
    cond do
      is_map(user) && Map.has_key?(user, :name) && user.name -> String.first(user.name)
      is_map(user) && Map.has_key?(user, "name") && user["name"] -> String.first(user["name"])
      is_map(user) && Map.has_key?(user, :email) && user.email -> String.first(user.email)
      is_map(user) && Map.has_key?(user, "email") && user["email"] -> String.first(user["email"])
      true -> "U"
    end
  end

  defp get_user_display_name(user) do
    cond do
      is_map(user) && Map.has_key?(user, :name) && user.name -> user.name
      is_map(user) && Map.has_key?(user, "name") && user["name"] -> user["name"]
      is_map(user) && Map.has_key?(user, :email) && user.email -> 
        user.email |> String.split("@") |> List.first()
      is_map(user) && Map.has_key?(user, "email") && user["email"] -> 
        user["email"] |> String.split("@") |> List.first()
      true -> "User"
    end
  end

  defp get_user_avatar_url(user) do
    cond do
      is_map(user) && Map.has_key?(user, :avatar_url) && user.avatar_url -> user.avatar_url
      is_map(user) && Map.has_key?(user, "avatar_url") && user["avatar_url"] -> user["avatar_url"]
      true -> nil
    end
  end
end