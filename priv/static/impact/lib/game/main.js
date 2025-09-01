ig.module(
  'game.main'
)
.requires(
  'impact.game',
  'impact.entity',
  'game.entities.star',
  'game.entities.planet',
  'game.entities.nebula'
)
.defines(function(){

GalaxyGame = ig.Game.extend({
  
  clearColor: '#0a0a0a',
  gravity: 0,
  
  // Galaxy entities
  stars: [],
  planets: [],
  nebulae: [],
  
  // Animation properties
  parallaxOffset: {x: 0, y: 0},
  mousePos: {x: 0, y: 0},
  
  init: function() {
    // Initialize input
    ig.input.bind(ig.KEY.MOUSE1, 'click');
    
    // Generate initial galaxy
    this.generateGalaxy();
  },
  
  generateGalaxy: function() {
    // This will be called from LiveView with actual data
    // For now, create some default entities for testing
    this.createDefaultGalaxy();
  },
  
  createDefaultGalaxy: function() {
    // Create some default stars
    for (var i = 0; i < 30; i++) {
      this.spawnEntity(EntityStar, 
        Math.random() * ig.system.width,
        Math.random() * ig.system.height,
        {
          size: Math.random() * 3 + 1,
          brightness: Math.random(),
          color: ['#FFFFFF', '#4FC3F7', '#E1F5FE'][Math.floor(Math.random() * 3)]
        }
      );
    }
    
    // Create some planets
    for (var i = 0; i < 5; i++) {
      this.spawnEntity(EntityPlanet,
        Math.random() * (ig.system.width - 100) + 50,
        Math.random() * (ig.system.height - 100) + 50,
        {
          size: Math.random() * 20 + 15,
          color: ['#FF7043', '#66BB6A', '#42A5F5', '#AB47BC'][Math.floor(Math.random() * 4)]
        }
      );
    }
    
    // Create nebulae
    for (var i = 0; i < 2; i++) {
      this.spawnEntity(EntityNebula,
        Math.random() * ig.system.width,
        Math.random() * ig.system.height,
        {
          width: Math.random() * 150 + 100,
          height: Math.random() * 100 + 75,
          color: ['#E91E63', '#9C27B0', '#3F51B5'][Math.floor(Math.random() * 3)]
        }
      );
    }
  },
  
  updateFromLiveView: function(data) {
    // Update galaxy state from Phoenix LiveView
    if (data.stars) {
      this.updateStars(data.stars);
    }
    if (data.planets) {
      this.updatePlanets(data.planets);
    }
    if (data.nebulae) {
      this.updateNebulae(data.nebulae);
    }
  },
  
  updateStars: function(starData) {
    // Update or create stars based on LiveView data
    starData.forEach(function(star) {
      var existingStar = this.getEntityByName('star_' + star.id);
      if (!existingStar) {
        this.spawnEntity(EntityStar, star.x, star.y, {
          name: 'star_' + star.id,
          size: star.size,
          brightness: star.brightness,
          color: star.color,
          twinkle_speed: star.twinkle_speed
        });
      }
    }.bind(this));
  },
  
  updatePlanets: function(planetData) {
    planetData.forEach(function(planet) {
      var existingPlanet = this.getEntityByName('planet_' + planet.id);
      if (!existingPlanet) {
        this.spawnEntity(EntityPlanet, planet.x, planet.y, {
          name: 'planet_' + planet.id,
          size: planet.size,
          color: planet.color,
          orbit_radius: planet.orbit_radius,
          orbit_speed: planet.orbit_speed,
          info: planet.info
        });
      }
    }.bind(this));
  },
  
  updateNebulae: function(nebulaData) {
    nebulaData.forEach(function(nebula) {
      var existingNebula = this.getEntityByName('nebula_' + nebula.id);
      if (!existingNebula) {
        this.spawnEntity(EntityNebula, nebula.x, nebula.y, {
          name: 'nebula_' + nebula.id,
          width: nebula.width,
          height: nebula.height,
          color: nebula.color,
          opacity: nebula.opacity,
          drift_speed: nebula.drift_speed
        });
      }
    }.bind(this));
  },
  
  updateParallax: function(mouseX, mouseY) {
    // Create subtle parallax effect based on mouse position
    var centerX = ig.system.width / 2;
    var centerY = ig.system.height / 2;
    
    this.parallaxOffset.x = (mouseX - centerX) * 0.02;
    this.parallaxOffset.y = (mouseY - centerY) * 0.02;
    
    this.mousePos.x = mouseX;
    this.mousePos.y = mouseY;
  },
  
  update: function() {
    this.parent();
    
    // Handle mouse clicks on entities
    if (ig.input.pressed('click')) {
      this.handleClick(ig.input.mouse.x, ig.input.mouse.y);
    }
  },
  
  handleClick: function(x, y) {
    // Check if click hit any interactive entities
    var worldX = x + this.screen.x;
    var worldY = y + this.screen.y;
    
    // Check stars
    this.entities.forEach(function(entity) {
      if (entity instanceof EntityStar) {
        var distance = Math.sqrt(
          Math.pow(worldX - (entity.pos.x + entity.size.x/2), 2) +
          Math.pow(worldY - (entity.pos.y + entity.size.y/2), 2)
        );
        if (distance <= entity.size.x + 5) {
          entity.handleClick();
        }
      }
    });
  },
  
  draw: function() {
    // Apply parallax offset to screen
    this.screen.x += this.parallaxOffset.x;
    this.screen.y += this.parallaxOffset.y;
    
    this.parent();
    
    // Reset screen position
    this.screen.x -= this.parallaxOffset.x;
    this.screen.y -= this.parallaxOffset.y;
    
    // Draw UI elements
    this.drawUI();
  },
  
  drawUI: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    
    // Draw subtle grid or constellation lines
    this.drawConstellationLines(ctx);
  },
  
  drawConstellationLines: function(ctx) {
    ctx.save();
    ctx.strokeStyle = 'rgba(79, 195, 247, 0.1)';
    ctx.lineWidth = 1;
    
    // Draw connecting lines between nearby stars
    var stars = this.entities.filter(function(e) { return e instanceof EntityStar; });
    
    for (var i = 0; i < stars.length; i++) {
      for (var j = i + 1; j < stars.length; j++) {
        var star1 = stars[i];
        var star2 = stars[j];
        
        var distance = Math.sqrt(
          Math.pow(star1.pos.x - star2.pos.x, 2) +
          Math.pow(star1.pos.y - star2.pos.y, 2)
        );
        
        // Only connect nearby stars
        if (distance < 150) {
          var alpha = 1 - (distance / 150);
          ctx.globalAlpha = alpha * 0.3;
          
          ctx.beginPath();
          ctx.moveTo(
            star1.pos.x + star1.size.x/2 - this.screen.x,
            star1.pos.y + star1.size.y/2 - this.screen.y
          );
          ctx.lineTo(
            star2.pos.x + star2.size.x/2 - this.screen.x,
            star2.pos.y + star2.size.y/2 - this.screen.y
          );
          ctx.stroke();
        }
      }
    }
    
    ctx.restore();
  }
});

// Start the game
ig.main('#galaxy-canvas', GalaxyGame, 60, 1200, 800, 1);

});
  