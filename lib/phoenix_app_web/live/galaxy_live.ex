defmodule PhoenixAppWeb.GalaxyLive do
  use PhoenixAppWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Send periodic updates for animation
      :timer.send_interval(100, self(), :galaxy_tick)
    end
    
    {:ok, assign(socket, 
      galaxy_state: initial_galaxy_state(),
      stars: generate_stars(50),
      planets: generate_planets(8),
      nebulae: generate_nebulae(3),
      mouse_pos: %{x: 0, y: 0},
      interaction_mode: :explore
    )}
  end
  
  @impl true
  def handle_info(:galaxy_tick, socket) do
    # Update galaxy animation state
    updated_state = update_galaxy_animation(socket.assigns.galaxy_state)
    
    # Push updates to Impact.js
    push_event(socket, "galaxy_update", %{
      stars: socket.assigns.stars,
      planets: socket.assigns.planets,
      nebulae: socket.assigns.nebulae,
      animation_frame: updated_state.frame
    })
    
    {:noreply, assign(socket, galaxy_state: updated_state)}
  end
  
  @impl true
  def handle_event("mouse_move", %{"x" => x, "y" => y}, socket) do
    # Create subtle parallax effect based on mouse position
    push_event(socket, "parallax_update", %{x: x, y: y})
    {:noreply, assign(socket, mouse_pos: %{x: x, y: y})}
  end
  
  @impl true
  def handle_event("star_click", %{"star_id" => star_id}, socket) do
    # Handle star interaction - maybe show info or create ripple effect
    push_event(socket, "star_interaction", %{
      star_id: star_id,
      effect: "ripple",
      color: "#4FC3F7"
    })
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("planet_hover", %{"planet_id" => planet_id}, socket) do
    # Show planet information or create glow effect
    planet = Enum.find(socket.assigns.planets, &(&1.id == planet_id))
    
    push_event(socket, "planet_glow", %{
      planet_id: planet_id,
      info: planet.info
    })
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="galaxy-container" 
         phx-hook="GalaxyEngine"
         id="galaxy-main"
         phx-window-mousemove="mouse_move">
      
      <!-- Impact.js Canvas -->
      <canvas id="galaxy-canvas" 
              width="1200" 
              height="800"
              class="galaxy-canvas">
      </canvas>
      
      <!-- UI Overlay -->
      <div class="galaxy-ui-overlay">
        <div class="galaxy-info-panel">
          <h3 class="text-lg font-semibold text-blue-200">Galaxy Explorer</h3>
          <p class="text-sm text-blue-100">
            Mouse: <%= @mouse_pos.x %>, <%= @mouse_pos.y %>
          </p>
          <p class="text-sm text-blue-100">
            Stars: <%= length(@stars) %> | Planets: <%= length(@planets) %>
          </p>
        </div>
        
        <!-- Interactive Controls -->
        <div class="galaxy-controls">
          <button class="galaxy-btn" phx-click="toggle_mode">
            <%= if @interaction_mode == :explore, do: "🔭 Explore", else: "🎮 Play" %>
          </button>
        </div>
      </div>
    </div>
    
    <style>
      .galaxy-container {
        position: relative;
        width: 100%;
        height: 100vh;
        background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #16213e 100%);
        overflow: hidden;
      }
      
      .galaxy-canvas {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        border-radius: 8px;
        box-shadow: 0 0 50px rgba(79, 195, 247, 0.3);
      }
      
      .galaxy-ui-overlay {
        position: absolute;
        top: 20px;
        left: 20px;
        z-index: 10;
        pointer-events: none;
      }
      
      .galaxy-info-panel {
        background: rgba(0, 0, 0, 0.7);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(79, 195, 247, 0.3);
        border-radius: 8px;
        padding: 16px;
        pointer-events: auto;
      }
      
      .galaxy-controls {
        margin-top: 16px;
        pointer-events: auto;
      }
      
      .galaxy-btn {
        background: rgba(79, 195, 247, 0.2);
        border: 1px solid rgba(79, 195, 247, 0.5);
        color: #4FC3F7;
        padding: 8px 16px;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.3s ease;
      }
      
      .galaxy-btn:hover {
        background: rgba(79, 195, 247, 0.3);
        box-shadow: 0 0 20px rgba(79, 195, 247, 0.4);
      }
    </style>
    """
  end
  
  # Helper functions
  defp initial_galaxy_state do
    %{
      frame: 0,
      time: 0,
      rotation_speed: 0.01,
      zoom: 1.0
    }
  end
  
  defp generate_stars(count) do
    Enum.map(1..count, fn i ->
      %{
        id: "star_#{i}",
        x: :rand.uniform(1200),
        y: :rand.uniform(800),
        size: :rand.uniform(3) + 1,
        brightness: :rand.uniform(100) / 100,
        color: Enum.random(["#FFFFFF", "#4FC3F7", "#E1F5FE", "#B3E5FC"]),
        twinkle_speed: :rand.uniform(50) / 100
      }
    end)
  end
  
  defp generate_planets(count) do
    Enum.map(1..count, fn i ->
      %{
        id: "planet_#{i}",
        x: :rand.uniform(1000) + 100,
        y: :rand.uniform(600) + 100,
        size: :rand.uniform(30) + 20,
        color: Enum.random(["#FF7043", "#66BB6A", "#42A5F5", "#AB47BC"]),
        orbit_radius: :rand.uniform(100) + 50,
        orbit_speed: (:rand.uniform(20) + 5) / 1000,
        info: %{
          name: "Planet #{i}",
          type: Enum.random(["Rocky", "Gas Giant", "Ice World", "Desert"]),
          atmosphere: Enum.random(["Thin", "Dense", "Toxic", "None"])
        }
      }
    end)
  end
  
  defp generate_nebulae(count) do
    Enum.map(1..count, fn i ->
      %{
        id: "nebula_#{i}",
        x: :rand.uniform(1200),
        y: :rand.uniform(800),
        width: :rand.uniform(200) + 100,
        height: :rand.uniform(150) + 75,
        color: Enum.random(["#E91E63", "#9C27B0", "#3F51B5", "#00BCD4"]),
        opacity: (:rand.uniform(30) + 20) / 100,
        drift_speed: (:rand.uniform(10) + 1) / 1000
      }
    end)
  end
  
  defp update_galaxy_animation(state) do
    %{state | 
      frame: state.frame + 1,
      time: state.time + 0.016 # ~60fps
    }
  end
end