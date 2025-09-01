// Galaxy Engine Hook - Connects Phoenix LiveView with Impact.js
export const GalaxyEngine = {
  mounted() {
    console.log("Galaxy Engine Hook mounted");
    
    // Store reference to the LiveView element
    this.liveViewEl = this.el;
    
    // Initialize Impact.js game
    this.initializeGalaxyGame();
    
    // Set up event listeners
    this.setupEventListeners();
    
    // Handle LiveView events
    this.handleEvent("galaxy_update", (data) => this.updateGalaxy(data));
    this.handleEvent("parallax_update", (data) => this.updateParallax(data));
    this.handleEvent("star_interaction", (data) => this.handleStarInteraction(data));
    this.handleEvent("planet_glow", (data) => this.handlePlanetGlow(data));
  },
  
  initializeGalaxyGame() {
    // Wait for Impact.js to be loaded
    if (typeof ig === 'undefined') {
      console.log("Waiting for Impact.js to load...");
      setTimeout(() => this.initializeGalaxyGame(), 100);
      return;
    }
    
    console.log("Initializing Galaxy Game with Impact.js");
    
    // The game is already started in main.js, just get reference
    this.game = ig.game;
    
    // Store reference to this hook in window for Impact.js to access
    window.galaxyHook = this;
    
    console.log("Galaxy Game initialized successfully");
  },
  
  setupEventListeners() {
    const canvas = this.el.querySelector('#galaxy-canvas');
    if (!canvas) {
      console.error("Galaxy canvas not found");
      return;
    }
    
    // Mouse move for parallax effect
    canvas.addEventListener('mousemove', (e) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      // Update parallax in game
      if (this.game && this.game.updateParallax) {
        this.game.updateParallax(x, y);
      }
      
      // Send to LiveView (throttled)
      this.throttledMouseMove(x, y);
    });
    
    // Canvas click handling
    canvas.addEventListener('click', (e) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      console.log(`Galaxy canvas clicked at: ${x}, ${y}`);
    });
    
    // Resize handling
    window.addEventListener('resize', () => this.handleResize());
  },
  
  // Throttled mouse move to avoid overwhelming LiveView
  throttledMouseMove: (() => {
    let lastCall = 0;
    return function(x, y) {
      const now = Date.now();
      if (now - lastCall >= 50) { // 20fps max
        this.pushEvent("mouse_move", { x: x, y: y });
        lastCall = now;
      }
    };
  })(),
  
  updateGalaxy(data) {
    console.log("Updating galaxy with data:", data);
    
    if (!this.game || !this.game.updateFromLiveView) {
      console.warn("Game not ready for galaxy updates");
      return;
    }
    
    // Update the Impact.js game with new data
    this.game.updateFromLiveView(data);
  },
  
  updateParallax(data) {
    if (this.game && this.game.updateParallax) {
      this.game.updateParallax(data.x, data.y);
    }
  },
  
  handleStarInteraction(data) {
    console.log("Star interaction:", data);
    
    // Find the star entity and trigger effect
    if (this.game && this.game.entities) {
      const star = this.game.entities.find(e => 
        e.name === `star_${data.star_id}` || e.id === data.star_id
      );
      
      if (star && star.handleClick) {
        star.handleClick();
      }
    }
    
    // Create additional visual effects
    this.createStarRippleEffect(data);
  },
  
  handlePlanetGlow(data) {
    console.log("Planet glow effect:", data);
    
    // Find planet and apply glow
    if (this.game && this.game.entities) {
      const planet = this.game.entities.find(e => 
        e.name === `planet_${data.planet_id}` || e.id === data.planet_id
      );
      
      if (planet) {
        planet.isHovered = true;
        
        // Show planet info in UI
        this.showPlanetInfo(data.info);
      }
    }
  },
  
  createStarRippleEffect(data) {
    // Create CSS-based ripple effect as backup/enhancement
    const canvas = this.el.querySelector('#galaxy-canvas');
    if (!canvas) return;
    
    const ripple = document.createElement('div');
    ripple.className = 'star-ripple-effect';
    ripple.style.cssText = `
      position: absolute;
      border: 2px solid ${data.color || '#4FC3F7'};
      border-radius: 50%;
      width: 10px;
      height: 10px;
      left: 50%;
      top: 50%;
      transform: translate(-50%, -50%);
      animation: starRipple 1s ease-out forwards;
      pointer-events: none;
      z-index: 1000;
    `;
    
    canvas.parentElement.appendChild(ripple);
    
    // Remove after animation
    setTimeout(() => {
      if (ripple.parentElement) {
        ripple.parentElement.removeChild(ripple);
      }
    }, 1000);
  },
  
  showPlanetInfo(info) {
    // Update the UI with planet information
    const infoPanel = this.el.querySelector('.galaxy-info-panel');
    if (infoPanel && info) {
      const planetInfo = document.createElement('div');
      planetInfo.className = 'planet-info-popup';
      planetInfo.innerHTML = `
        <h4>${info.name}</h4>
        <p>Type: ${info.type}</p>
        <p>Atmosphere: ${info.atmosphere}</p>
      `;
      planetInfo.style.cssText = `
        position: absolute;
        background: rgba(0, 0, 0, 0.8);
        border: 1px solid #4FC3F7;
        border-radius: 6px;
        padding: 12px;
        color: #4FC3F7;
        font-size: 12px;
        z-index: 1001;
        animation: fadeIn 0.3s ease-in;
      `;
      
      infoPanel.appendChild(planetInfo);
      
      // Remove after 3 seconds
      setTimeout(() => {
        if (planetInfo.parentElement) {
          planetInfo.parentElement.removeChild(planetInfo);
        }
      }, 3000);
    }
  },
  
  handleResize() {
    // Handle canvas resize if needed
    const canvas = this.el.querySelector('#galaxy-canvas');
    if (canvas && this.game) {
      // Impact.js handles resize automatically, but we can add custom logic here
      console.log("Galaxy canvas resized");
    }
  },
  
  destroyed() {
    console.log("Galaxy Engine Hook destroyed");
    
    // Clean up
    if (window.galaxyHook === this) {
      delete window.galaxyHook;
    }
    
    // Stop Impact.js game if needed
    if (this.game && this.game.stop) {
      this.game.stop();
    }
  }
};

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
  @keyframes starRipple {
    0% {
      width: 10px;
      height: 10px;
      opacity: 1;
    }
    100% {
      width: 100px;
      height: 100px;
      opacity: 0;
    }
  }
  
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
  }
  
  .star-ripple-effect {
    animation: starRipple 1s ease-out forwards;
  }
  
  .planet-info-popup {
    animation: fadeIn 0.3s ease-in;
  }
`;
document.head.appendChild(style);