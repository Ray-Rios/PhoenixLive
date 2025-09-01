defmodule PhoenixAppWeb.GalaxySimulation do
  use GenServer
  
  @moduledoc """
  Galaxy simulation process that manages the physics and state
  of celestial objects in the galaxy visualization.
  """
  
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end
  
  @impl true
  def init(state) do
    # Start the simulation timer
    :timer.send_interval(50, self(), :simulate_step)
    
    {:ok, Map.merge(state, %{
      celestial_bodies: [],
      gravitational_fields: [],
      particle_systems: [],
      time_scale: 1.0
    })}
  end
  
  @impl true
  def handle_info(:simulate_step, state) do
    # Update celestial body positions
    updated_bodies = update_celestial_bodies(state.celestial_bodies, state.time_scale)
    
    # Update particle systems (for nebulae, star dust, etc.)
    updated_particles = update_particle_systems(state.particle_systems)
    
    # Broadcast updates to all connected LiveViews
    Phoenix.PubSub.broadcast(PhoenixApp.PubSub, "galaxy:updates", %{
      celestial_bodies: updated_bodies,
      particles: updated_particles
    })
    
    {:noreply, %{state | 
      celestial_bodies: updated_bodies,
      particle_systems: updated_particles
    }}
  end
  
  @impl true
  def handle_call({:add_celestial_body, body}, _from, state) do
    updated_bodies = [body | state.celestial_bodies]
    {:reply, :ok, %{state | celestial_bodies: updated_bodies}}
  end
  
  @impl true
  def handle_call({:set_time_scale, scale}, _from, state) do
    {:reply, :ok, %{state | time_scale: scale}}
  end
  
  # Private functions
  defp update_celestial_bodies(bodies, time_scale) do
    Enum.map(bodies, fn body ->
      case body.type do
        :planet -> update_planet_orbit(body, time_scale)
        :star -> update_star_twinkle(body, time_scale)
        :asteroid -> update_asteroid_drift(body, time_scale)
        _ -> body
      end
    end)
  end
  
  defp update_planet_orbit(planet, time_scale) do
    new_angle = planet.orbit_angle + (planet.orbit_speed * time_scale)
    
    %{planet |
      orbit_angle: new_angle,
      x: planet.center_x + :math.cos(new_angle) * planet.orbit_radius,
      y: planet.center_y + :math.sin(new_angle) * planet.orbit_radius
    }
  end
  
  defp update_star_twinkle(star, time_scale) do
    new_twinkle = star.twinkle_phase + (star.twinkle_speed * time_scale)
    brightness = 0.7 + 0.3 * :math.sin(new_twinkle)
    
    %{star |
      twinkle_phase: new_twinkle,
      current_brightness: brightness
    }
  end
  
  defp update_asteroid_drift(asteroid, time_scale) do
    %{asteroid |
      x: asteroid.x + (asteroid.velocity_x * time_scale),
      y: asteroid.y + (asteroid.velocity_y * time_scale),
      rotation: asteroid.rotation + (asteroid.rotation_speed * time_scale)
    }
  end
  
  defp update_particle_systems(systems) do
    Enum.map(systems, fn system ->
      updated_particles = Enum.map(system.particles, &update_particle/1)
      %{system | particles: updated_particles}
    end)
  end
  
  defp update_particle(particle) do
    %{particle |
      x: particle.x + particle.velocity_x,
      y: particle.y + particle.velocity_y,
      life: particle.life - 1,
      alpha: particle.alpha * 0.99
    }
  end
end