# Galaxy Integration Guide 🌌

This guide explains how to integrate the relaxing galaxy visualization system with Phoenix LiveView and Impact.js.

## Architecture Overview

The galaxy system consists of three main components:

1. **Phoenix LiveView** (`GalaxyLive`) - Manages state and real-time updates
2. **Impact.js Game Engine** - Handles rendering and animations
3. **JavaScript Hook** (`GalaxyEngine`) - Bridges LiveView and Impact.js

## Components Created

### Phoenix LiveView Components

- `lib/phoenix_app_web/live/galaxy_live.ex` - Main galaxy LiveView
- `lib/phoenix_app_web/galaxy_simulation.ex` - Galaxy physics simulation GenServer
- `lib/phoenix_app_web/live/demo_galaxy_live.ex` - Demo/preview page

### Impact.js Game Entities

- `priv/static/impact/lib/game/entities/star.js` - Interactive stars with twinkle effects
- `priv/static/impact/lib/game/entities/planet.js` - Planets with orbits and hover effects
- `priv/static/impact/lib/game/entities/nebula.js` - Animated nebulae with particle systems
- `priv/static/impact/lib/game/main.js` - Updated main game loop

### JavaScript Integration

- `assets/js/galaxy_hook.js` - LiveView hook for Impact.js integration
- Updated `assets/js/app.js` - Added galaxy hook to LiveView

## Features

### Interactive Elements

- **Stars**: Click to create ripple effects, twinkle animations
- **Planets**: Hover for information panels, orbital mechanics
- **Nebulae**: Drifting particle systems, color variations
- **Parallax**: Mouse movement creates subtle depth effects

### Real-time Updates

- Galaxy state managed by Phoenix LiveView
- Physics simulation runs in separate GenServer
- Smooth 60fps animations via Impact.js
- WebSocket updates for multiplayer potential

### Relaxing Design

- Soft color palette (blues, purples, gentle whites)
- Smooth animations and transitions
- Ambient particle effects
- Constellation line connections between nearby stars

## Usage

### Basic Setup

1. Visit `/galaxy-demo` for a preview
2. Visit `/galaxy` for the full interactive experience
3. Move mouse for parallax effects
4. Click stars and hover planets for interactions

### Customization

#### Adding New Celestial Bodies

```elixir
# In GalaxyLive
defp generate_custom_objects do
  # Add asteroids, comets, space stations, etc.
end
```

#### Creating New Effects

```javascript
// In Impact.js entities
EntityCustomEffect = ig.Entity.extend({
  // Custom visual effects
});
```

#### Extending Interactions

```elixir
# In GalaxyLive
def handle_event("custom_interaction", params, socket) do
  # Handle new interaction types
end
```

## Integration with Existing Components

### Adding Galaxy Background to Any Page

```heex
<div class="page-with-galaxy">
  <!-- Your existing content -->
  
  <!-- Galaxy background -->
  <div class="galaxy-background" phx-hook="GalaxyEngine" id="bg-galaxy">
    <canvas id="galaxy-canvas" width="1200" height="800"></canvas>
  </div>
</div>
```

### Component-Based Usage

The galaxy system can be used as:

1. **Full-page experience** - Immersive galaxy exploration
2. **Background element** - Subtle animated background
3. **Interactive widget** - Small galaxy component in larger UI
4. **Game element** - Part of a larger game system

## Performance Considerations

- Impact.js runs at 60fps with efficient entity management
- LiveView updates are throttled to prevent overwhelming
- Particle systems are optimized for smooth performance
- Canvas rendering uses hardware acceleration when available

## Future Enhancements

### Planned Features

- **Multiplayer cursors** - See other users exploring the galaxy
- **Constellation creation** - Users can create and share constellations
- **Planet colonization** - Interactive planet development
- **Space travel** - Navigate between different galaxy regions
- **Audio integration** - Ambient space sounds and music

### Technical Improvements

- **WebGL rendering** - Enhanced visual effects
- **Procedural generation** - Infinite galaxy exploration
- **Physics simulation** - Realistic orbital mechanics
- **Save/load states** - Persistent galaxy configurations

## Development Notes

### File Structure
```
lib/phoenix_app_web/
├── live/
│   ├── galaxy_live.ex
│   └── demo_galaxy_live.ex
├── galaxy_simulation.ex
└── router.ex (updated)

priv/static/impact/lib/game/
├── entities/
│   ├── star.js
│   ├── planet.js
│   └── nebula.js
└── main.js (updated)

assets/js/
├── galaxy_hook.js
└── app.js (updated)
```

### Key Integration Points

1. **LiveView Events** - Mouse movements, clicks, hovers
2. **Impact.js Callbacks** - Entity interactions, animations
3. **GenServer Updates** - Physics simulation, state management
4. **WebSocket Messages** - Real-time multiplayer updates

## Testing

### Manual Testing

1. Open `/galaxy-demo` - Should show animated preview
2. Open `/galaxy` - Should load full Impact.js galaxy
3. Test mouse interactions - Parallax and click effects
4. Check browser console - No JavaScript errors

### Automated Testing

```elixir
# Test LiveView functionality
test "galaxy live view mounts successfully" do
  {:ok, view, html} = live(conn, "/galaxy")
  assert html =~ "Galaxy Explorer"
end

# Test galaxy simulation
test "galaxy simulation updates celestial bodies" do
  {:ok, pid} = GalaxySimulation.start_link(%{})
  # Test simulation logic
end
```

## Troubleshooting

### Common Issues

1. **Impact.js not loading** - Check script tags in layout
2. **Canvas not rendering** - Verify canvas element exists
3. **LiveView events not firing** - Check hook mounting
4. **Performance issues** - Reduce particle counts

### Debug Mode

Enable debug logging:

```javascript
// In galaxy_hook.js
console.log("Galaxy debug mode enabled");
```

```elixir
# In galaxy_live.ex
require Logger
Logger.debug("Galaxy state: #{inspect(galaxy_state)}")
```

This integration provides a solid foundation for creating relaxing, interactive web experiences that combine the real-time capabilities of Phoenix LiveView with the smooth animations of Impact.js game engine.