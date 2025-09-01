ig.module(
  'game.entities.planet'
)
.requires(
  'impact.entity'
)
.defines(function(){

EntityPlanet = ig.Entity.extend({
  
  size: {x: 40, y: 40},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  // Planet properties
  radius: 20,
  color: '#42A5F5',
  atmosphereColor: '#E3F2FD',
  hasAtmosphere: true,
  rotationSpeed: 0.01,
  rotation: 0,
  orbitRadius: 0,
  orbitSpeed: 0,
  orbitAngle: 0,
  centerX: 0,
  centerY: 0,
  isHovered: false,
  glowIntensity: 0,
  
  // Planet info
  planetInfo: {
    name: 'Unknown Planet',
    type: 'Rocky',
    atmosphere: 'Thin'
  },
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Set planet properties from settings
    this.radius = settings.size || 20;
    this.size.x = this.size.y = this.radius * 2;
    this.color = settings.color || '#42A5F5';
    this.hasAtmosphere = settings.hasAtmosphere !== false;
    this.rotationSpeed = settings.rotationSpeed || (Math.random() * 0.02 + 0.005);
    
    // Orbit properties
    this.orbitRadius = settings.orbit_radius || 0;
    this.orbitSpeed = settings.orbit_speed || 0;
    this.orbitAngle = settings.orbit_angle || 0;
    this.centerX = settings.center_x || x;
    this.centerY = settings.center_y || y;
    
    // Planet info
    this.planetInfo = settings.info || this.planetInfo;
    
    // Generate surface features
    this.generateSurfaceFeatures();
  },
  
  update: function() {
    this.parent();
    
    // Update rotation
    this.rotation += this.rotationSpeed;
    
    // Update orbit if applicable
    if (this.orbitRadius > 0) {
      this.orbitAngle += this.orbitSpeed;
      this.pos.x = this.centerX + Math.cos(this.orbitAngle) * this.orbitRadius - this.radius;
      this.pos.y = this.centerY + Math.sin(this.orbitAngle) * this.orbitRadius - this.radius;
    }
    
    // Update glow effect
    if (this.isHovered) {
      this.glowIntensity = Math.min(1, this.glowIntensity + 0.05);
    } else {
      this.glowIntensity = Math.max(0, this.glowIntensity - 0.03);
    }
    
    // Check for mouse hover
    this.checkMouseHover();
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x + this.radius;
    var y = this.pos.y - ig.game.screen.y + this.radius;
    
    ctx.save();
    
    // Draw glow effect if hovered
    if (this.glowIntensity > 0) {
      var glowGradient = ctx.createRadialGradient(
        x, y, this.radius,
        x, y, this.radius * 2
      );
      glowGradient.addColorStop(0, this.color + '00');
      glowGradient.addColorStop(1, this.color + Math.floor(this.glowIntensity * 100).toString(16).padStart(2, '0'));
      
      ctx.fillStyle = glowGradient;
      ctx.fillRect(x - this.radius * 2, y - this.radius * 2, this.radius * 4, this.radius * 4);
    }
    
    // Draw atmosphere if present
    if (this.hasAtmosphere) {
      var atmGradient = ctx.createRadialGradient(
        x, y, this.radius * 0.8,
        x, y, this.radius * 1.2
      );
      atmGradient.addColorStop(0, this.atmosphereColor + '00');
      atmGradient.addColorStop(1, this.atmosphereColor + '40');
      
      ctx.fillStyle = atmGradient;
      ctx.beginPath();
      ctx.arc(x, y, this.radius * 1.2, 0, Math.PI * 2);
      ctx.fill();
    }
    
    // Draw planet body
    var planetGradient = ctx.createRadialGradient(
      x - this.radius * 0.3, y - this.radius * 0.3, 0,
      x, y, this.radius
    );
    planetGradient.addColorStop(0, this.lightenColor(this.color, 0.3));
    planetGradient.addColorStop(1, this.darkenColor(this.color, 0.2));
    
    ctx.fillStyle = planetGradient;
    ctx.beginPath();
    ctx.arc(x, y, this.radius, 0, Math.PI * 2);
    ctx.fill();
    
    // Draw surface features
    this.drawSurfaceFeatures(ctx, x, y);
    
    ctx.restore();
  },
  
  generateSurfaceFeatures: function() {
    this.surfaceFeatures = [];
    var featureCount = Math.floor(Math.random() * 5) + 3;
    
    for (var i = 0; i < featureCount; i++) {
      this.surfaceFeatures.push({
        angle: Math.random() * Math.PI * 2,
        distance: Math.random() * this.radius * 0.7,
        size: Math.random() * 3 + 1,
        color: this.darkenColor(this.color, Math.random() * 0.3 + 0.1)
      });
    }
  },
  
  drawSurfaceFeatures: function(ctx, centerX, centerY) {
    ctx.save();
    
    for (var i = 0; i < this.surfaceFeatures.length; i++) {
      var feature = this.surfaceFeatures[i];
      var rotatedAngle = feature.angle + this.rotation;
      
      var x = centerX + Math.cos(rotatedAngle) * feature.distance;
      var y = centerY + Math.sin(rotatedAngle) * feature.distance;
      
      // Only draw features on the visible hemisphere
      if (Math.cos(rotatedAngle) > 0) {
        ctx.fillStyle = feature.color;
        ctx.beginPath();
        ctx.arc(x, y, feature.size, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    
    ctx.restore();
  },
  
  checkMouseHover: function() {
    if (!ig.input.mouse) return;
    
    var mouseX = ig.input.mouse.x + ig.game.screen.x;
    var mouseY = ig.input.mouse.y + ig.game.screen.y;
    
    var centerX = this.pos.x + this.radius;
    var centerY = this.pos.y + this.radius;
    
    var distance = Math.sqrt(
      Math.pow(mouseX - centerX, 2) + Math.pow(mouseY - centerY, 2)
    );
    
    var wasHovered = this.isHovered;
    this.isHovered = distance <= this.radius;
    
    // Send hover event to LiveView
    if (this.isHovered && !wasHovered && window.liveSocket) {
      window.liveSocket.execJS(document.body, 
        `this.pushEvent("planet_hover", {planet_id: "${this.id}"})`
      );
    }
  },
  
  // Utility functions for color manipulation
  lightenColor: function(color, amount) {
    return this.adjustColor(color, amount);
  },
  
  darkenColor: function(color, amount) {
    return this.adjustColor(color, -amount);
  },
  
  adjustColor: function(color, amount) {
    var num = parseInt(color.replace("#", ""), 16);
    var amt = Math.round(2.55 * amount * 100);
    var R = (num >> 16) + amt;
    var G = (num >> 8 & 0x00FF) + amt;
    var B = (num & 0x0000FF) + amt;
    
    return "#" + (0x1000000 + (R < 255 ? R < 1 ? 0 : R : 255) * 0x10000 +
      (G < 255 ? G < 1 ? 0 : G : 255) * 0x100 +
      (B < 255 ? B < 1 ? 0 : B : 255)).toString(16).slice(1);
  }
});

});