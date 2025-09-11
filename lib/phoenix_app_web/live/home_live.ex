defmodule PhoenixAppWeb.HomeLive do
  use PhoenixAppWeb, :live_view

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Welcome")}
  end

  def render(assigns) do
    ~H"""
    <.page_with_navbar current_user={@current_user} flash={@flash}>
      <div class="w-Full bg-black">


      <!-- Main Content -->
      <div class="relative z-10 mx-auto transition-all duration-300 ease-in-out flex items-center justify-center min-h-[80vh] max-w-[80%]">
        <div class="text-center text-white">
          <%= if @current_user do %>
            <h1 class="text-6xl font-bold mb-6">
              Welcome back, <%= @current_user.name || String.split(@current_user.email, "@") |> List.first() %>!
            </h1>
            <p class="text-xl mb-8 opacity-80">
              Ready to explore? Choose your adventure below.
            </p>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-4 max-w-4xl mx-auto">
              <.link navigate={~p"/shop"} class="bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                🛒 Shop
              </.link>
              <.link navigate={~p"/desktop"} class="bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                🖥️ Desktop
              </.link>
              <.link navigate={~p"/quest"} class="bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                🎮 Quest
              </.link>
              <.link navigate={~p"/chat"} class="bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                💬 Chat
              </.link>
              <.link navigate={~p"/profile"} class="bg-gradient-to-r from-pink-600 to-pink-700 hover:from-pink-700 hover:to-pink-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                👤 Profile
              </.link>
              <.link navigate={~p"/blog"} class="bg-gradient-to-r from-yellow-600 to-yellow-700 hover:from-yellow-700 hover:to-yellow-800 text-white px-6 py-4 rounded-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                📝 Blog
              </.link>
            </div>
          <% else %>
            <h1 class="text-6xl font-bold mb-6 animate-pulse">
              Welcome to Phoenix CMS
            </h1>
            <p class="text-xl mb-8 opacity-80">
              Professional website builder with real-time collaboration
            </p>
            <div class="space-x-4">
              <.link navigate={~p"/register"} class="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 text-white px-8 py-3 rounded-lg text-lg transition-all duration-300 ease-in-out transform hover:scale-105">
                Get Started
              </.link>
              <.link navigate={~p"/login"} class="border-2 border-white text-white hover:bg-white hover:text-black px-8 py-3 rounded-lg text-lg transition-all duration-300 ease-in-out">
                Sign In
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    </.page_with_navbar>
    """
  end
end