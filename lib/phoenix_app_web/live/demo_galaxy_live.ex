defmodule PhoenixAppWeb.DemoGalaxyLive do
  use PhoenixAppWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      page_title: "Galaxy Demo",
      demo_mode: true
    )}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <!-- Header -->
      <div class="relative z-10 p-6">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-4xl font-bold text-white mb-2">
            🌌 Galaxy Interactive Demo
          </h1>
          <p class="text-blue-200 text-lg mb-6">
            Experience the relaxing galaxy visualization powered by Phoenix LiveView + Impact.js
          </p>
          
          <!-- Demo Controls -->
          <div class="flex flex-wrap gap-4 mb-8">
            <.link 
              navigate="/galaxy" 
              class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors duration-200 flex items-center gap-2">
              🚀 Launch Full Galaxy
            </.link>
            
            <button class="bg-purple-600 hover:bg-purple-700 text-white px-6 py-3 rounded-lg transition-colors duration-200">
              ⚙️ Settings
            </button>
            
            <button class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg transition-colors duration-200">
              📊 Stats
            </button>
          </div>
        </div>
      </div>
      
      <!-- Galaxy Preview -->
      <div class="relative">
        <div class="max-w-6xl mx-auto px-6">
          <div class="bg-black/30 backdrop-blur-sm rounded-xl p-6 border border-blue-500/20">
            <h2 class="text-2xl font-semibold text-white mb-4">Interactive Preview</h2>
            
            <!-- Mini Galaxy Container -->
            <div class="relative bg-gradient-to-br from-slate-900 to-purple-900 rounded-lg overflow-hidden" 
                 style="height: 400px;">
              
              <!-- Animated Stars CSS-only Demo -->
              <div class="absolute inset-0">
                <%= for i <- 1..20 do %>
                  <div class="absolute animate-pulse"
                       style={"left: #{:rand.uniform(90)}%; top: #{:rand.uniform(90)}%; animation-delay: #{:rand.uniform(3000)}ms;"}>
                    <div class="w-1 h-1 bg-white rounded-full opacity-80"></div>
                  </div>
                <% end %>
              </div>
              
              <!-- Floating Planets -->
              <div class="absolute inset-0">
                <%= for {color, size, x, y} <- [
                  {"bg-blue-400", "w-8 h-8", "20%", "30%"},
                  {"bg-red-400", "w-6 h-6", "70%", "20%"},
                  {"bg-green-400", "w-10 h-10", "60%", "70%"},
                  {"bg-purple-400", "w-4 h-4", "30%", "80%"}
                ] do %>
                  <div class={"absolute #{color} #{size} rounded-full opacity-70 animate-bounce"}
                       style={"left: #{x}; top: #{y}; animation-delay: #{:rand.uniform(2000)}ms; animation-duration: 4s;"}>
                  </div>
                <% end %>
              </div>
              
              <!-- Nebula Effect -->
              <div class="absolute inset-0">
                <div class="absolute w-32 h-24 bg-gradient-to-r from-pink-500/20 to-transparent rounded-full blur-xl animate-pulse"
                     style="left: 40%; top: 40%;"></div>
                <div class="absolute w-24 h-32 bg-gradient-to-r from-blue-500/20 to-transparent rounded-full blur-xl animate-pulse"
                     style="left: 20%; top: 60%;"></div>
              </div>
              
              <!-- Interactive Overlay -->
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="text-center text-white/80">
                  <div class="text-6xl mb-4">🌌</div>
                  <p class="text-lg">Click "Launch Full Galaxy" to experience</p>
                  <p class="text-sm text-blue-200">the complete interactive universe</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Features Section -->
      <div class="max-w-4xl mx-auto px-6 py-12">
        <div class="grid md:grid-cols-3 gap-8">
          <div class="text-center">
            <div class="text-4xl mb-4">⭐</div>
            <h3 class="text-xl font-semibold text-white mb-2">Interactive Stars</h3>
            <p class="text-blue-200">Click stars to create ripple effects and discover their properties</p>
          </div>
          
          <div class="text-center">
            <div class="text-4xl mb-4">🪐</div>
            <h3 class="text-xl font-semibold text-white mb-2">Living Planets</h3>
            <p class="text-blue-200">Hover over planets to see detailed information and atmospheric effects</p>
          </div>
          
          <div class="text-center">
            <div class="text-4xl mb-4">🌠</div>
            <h3 class="text-xl font-semibold text-white mb-2">Dynamic Nebulae</h3>
            <p class="text-blue-200">Watch colorful nebulae drift and evolve in real-time</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end