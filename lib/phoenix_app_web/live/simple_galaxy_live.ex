defmodule PhoenixAppWeb.SimpleGalaxyLive do
  use PhoenixAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Galaxy")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-4xl font-bold text-white mb-8 text-center">
          🌌 Galaxy Explorer
        </h1>
        
        <div class="bg-black/30 backdrop-blur-sm rounded-xl p-8 border border-blue-500/20">
          <div class="text-center text-white">
            <p class="text-xl mb-4">Welcome to the Galaxy!</p>
            <p class="text-blue-200">Impact.js integration coming soon...</p>
            
            <!-- Simple animated stars -->
            <div class="relative mt-8 h-64 bg-gradient-to-b from-purple-900 to-black rounded-lg overflow-hidden">
              <%= for i <- 1..20 do %>
                <div class="absolute animate-pulse"
                     style={"left: #{:rand.uniform(90)}%; top: #{:rand.uniform(90)}%; animation-delay: #{:rand.uniform(3000)}ms;"}>
                  <div class="w-1 h-1 bg-white rounded-full opacity-80"></div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end