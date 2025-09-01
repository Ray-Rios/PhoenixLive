ig.module(
  'game.entities.nebula'
)
.requires(
  'impact.entity'
)
.defines(function(){

EntityNebula = ig.Entity.extend({
  
  size: {x: 200, y: 150},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  // Nebula properties
  width: 200,
  height: 150,
  color: '#E91E63',
  opacity: 0.3,
  driftSpeed: 0.001,
  driftAngle: 0,
  particles: [],
  particleCount: 50,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    this.width = settings.width || 200;
    this.height = settings.height || 150;
    this.size.x = this.width;
    this.size.y = this.height;
    this.color = settings.color || '#E91E63';
    this.opacity = settings.opacity || 0.3;
    this.driftSpeed = settings.drift_speed || 0.001;
    this.driftAngle = Math.random() * Math.PI * 2;
    
    // Generate nebula particles
    this.generateParticles();
  },
  
  update: function() {
    this.parent();
    
    // Update drift movement
    this.pos.x += Math.cos(this.driftAngle) * this.driftSpeed;
    this.pos.y += Math.sin(this.driftAngle) * this.driftSpeed;
    
    // Update particles
    this.updateParticles();
    
    // Slowly change drift direction
    this.driftAngle += (Math.random() - 0.5) * 0.01;
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x;
    var y = this.pos.y - ig.game.screen.y;
    
    ctx.save();
    
    // Draw nebula base
    this.drawNebulaBase(ctx, x, y);
    
    // Draw particles
    this.drawParticles(ctx, x, y);
    
    ctx.restore();
  },
  
  drawNebulaBase: function(ctx, x, y) {
    // Create multiple overlapping gradients for nebula effect
    var gradients = [
      {
        centerX: x + this.width * 0.3,
        centerY: y + this.height * 0.4,
        radius: this.width * 0.4,
        opacity: this.opacity * 0.8
      },
      {
        centerX: x + this.width * 0.7,
        centerY: y + this.height * 0.6,
        radius: this.width * 0.3,
        opacity: this.opacity * 0.6
      },
      {
        centerX: x + this.width * 0.5,
        centerY: y + this.height * 0.3,
        radius: this.width * 0.25,
        opacity: this.opacity * 0.9
      }
    ];
    
    gradients.forEach(function(grad) {
      var gradient = ctx.createRadialGradient(
        grad.centerX, grad.centerY, 0,
        grad.centerX, grad.centerY, grad.radius
      );
      
      gradient.addColorStop(0, this.color + Math.floor(grad.opacity * 255).toString(16).padStart(2, '0'));
      gradient.addColorStop(0.5, this.color + Math.floor(grad.opacity * 128).toString(16).padStart(2, '0'));
      gradient.addColorStop(1, this.color + '00');
      
      ctx.fillStyle = gradient;
      ctx.fillRect(
        grad.centerX - grad.radius,
        grad.centerY - grad.radius,
        grad.radius * 2,
        grad.radius * 2
      );
    }.bind(this));
  },
  
  generateParticles: function() {
    this.particles = [];
    
    for (var i = 0; i < this.particleCount; i++) {
      this.particles.push({
        x: Math.random() * this.width,
        y: Math.random() * this.height,
        size: Math.random() * 2 + 0.5,
        opacity: Math.random() * 0.5 + 0.2,
        driftX: (Math.random() - 0.5) * 0.02,
        driftY: (Math.random() - 0.5) * 0.02,
        twinkle: Math.random() * Math.PI * 2,
        twinkleSpeed: Math.random() * 0.05 + 0.01
      });
    }
  },
  
  updateParticles: function() {
    this.particles.forEach(function(particle) {
      // Update particle position
      particle.x += particle.driftX;
      particle.y += particle.driftY;
      
      // Wrap particles around nebula bounds
      if (particle.x < 0) particle.x = this.width;
      if (particle.x > this.width) particle.x = 0;
      if (particle.y < 0) particle.y = this.height;
      if (particle.y > this.height) particle.y = 0;
      
      // Update twinkle
      particle.twinkle += particle.twinkleSpeed;
    }.bind(this));
  },
  
  drawParticles: function(ctx, baseX, baseY) {
    this.particles.forEach(function(particle) {
      var x = baseX + particle.x;
      var y = baseY + particle.y;
      
      // Calculate twinkle effect
      var twinkleAlpha = Math.sin(particle.twinkle) * 0.3 + 0.7;
      var alpha = particle.opacity * twinkleAlpha;
      
      // Draw particle with glow
      var gradient = ctx.createRadialGradient(
        x, y, 0,
        x, y, particle.size * 2
      );
      
      gradient.addColorStop(0, '#FFFFFF' + Math.floor(alpha * 255).toString(16).padStart(2, '0'));
      gradient.addColorStop(0.5, this.color + Math.floor(alpha * 128).toString(16).padStart(2, '0'));
      gradient.addColorStop(1, this.color + '00');
      
      ctx.fillStyle = gradient;
      ctx.fillRect(
        x - particle.size * 2,
        y - particle.size * 2,
        particle.size * 4,
        particle.size * 4
      );
    }.bind(this));
  }
});

});