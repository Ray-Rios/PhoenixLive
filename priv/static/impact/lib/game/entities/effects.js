ig.module(
  'game.entities.effects'
)
.requires(
  'impact.entity'
)
.defines(function(){

// Damage Number Effect
EntityDamageNumber = ig.Entity.extend({
  
  size: {x: 20, y: 10},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  damage: 0,
  lifetime: 60,
  age: 0,
  color: '#ff4444',
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    this.damage = settings.damage || 0;
    this.color = settings.color || '#ff4444';
    
    // Initial upward velocity
    this.vel.y = -30;
    this.vel.x = (Math.random() - 0.5) * 20;
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    // Slow down over time
    this.vel.x *= 0.98;
    this.vel.y *= 0.95;
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x;
    var y = this.pos.y - ig.game.screen.y;
    
    ctx.save();
    
    var alpha = 1 - (this.age / this.lifetime);
    ctx.globalAlpha = alpha;
    
    ctx.fillStyle = this.color;
    ctx.font = 'bold 12px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('-' + this.damage, x + this.size.x / 2, y + this.size.y);
    
    // Outline for better visibility
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 2;
    ctx.strokeText('-' + this.damage, x + this.size.x / 2, y + this.size.y);
    
    ctx.restore();
  }
});

// Muzzle Flash Effect
EntityMuzzleFlash = ig.Entity.extend({
  
  size: {x: 16, y: 16},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 8,
  age: 0,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x;
    var y = this.pos.y - ig.game.screen.y;
    
    ctx.save();
    
    var alpha = 1 - (this.age / this.lifetime);
    ctx.globalAlpha = alpha;
    
    // Draw flash as expanding circle
    var radius = (this.age / this.lifetime) * 10;
    var gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, '#ffffff');
    gradient.addColorStop(0.5, '#ffff00');
    gradient.addColorStop(1, '#ff8800');
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.restore();
  }
});

// Laser Impact Effect
EntityLaserImpact = ig.Entity.extend({
  
  size: {x: 12, y: 12},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 15,
  age: 0,
  color: '#3b82f6',
  particles: [],
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    this.color = settings.color || '#3b82f6';
    
    // Generate impact particles
    for (var i = 0; i < 6; i++) {
      this.particles.push({
        x: 0,
        y: 0,
        vx: (Math.random() - 0.5) * 60,
        vy: (Math.random() - 0.5) * 60,
        size: 1 + Math.random() * 2,
        life: 1
      });
    }
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    // Update particles
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      particle.x += particle.vx * ig.system.tick;
      particle.y += particle.vy * ig.system.tick;
      particle.life -= ig.system.tick * 3;
      particle.size *= 0.95;
    }
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var centerX = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var centerY = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    // Draw impact flash
    var alpha = 1 - (this.age / this.lifetime);
    ctx.globalAlpha = alpha;
    
    var flashRadius = 8;
    var gradient = ctx.createRadialGradient(centerX, centerY, 0, centerX, centerY, flashRadius);
    gradient.addColorStop(0, '#ffffff');
    gradient.addColorStop(0.5, this.color);
    gradient.addColorStop(1, this.color + '00');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(centerX - flashRadius, centerY - flashRadius, flashRadius * 2, flashRadius * 2);
    
    // Draw particles
    ctx.fillStyle = this.color;
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      if (particle.life > 0) {
        ctx.globalAlpha = particle.life * alpha;
        ctx.fillRect(
          centerX + particle.x - particle.size / 2,
          centerY + particle.y - particle.size / 2,
          particle.size,
          particle.size
        );
      }
    }
    
    ctx.restore();
  }
});

// Abduction Effect
EntityAbductionEffect = ig.Entity.extend({
  
  size: {x: 40, y: 40},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 120,
  age: 0,
  rings: [],
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Generate expanding rings
    for (var i = 0; i < 5; i++) {
      this.rings.push({
        radius: 0,
        maxRadius: 20 + i * 10,
        speed: 0.5 + i * 0.2,
        alpha: 1 - i * 0.15
      });
    }
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    // Update rings
    for (var i = 0; i < this.rings.length; i++) {
      var ring = this.rings[i];
      ring.radius += ring.speed;
      
      if (ring.radius > ring.maxRadius) {
        ring.radius = 0;
      }
    }
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var centerX = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var centerY = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    var baseAlpha = 1 - (this.age / this.lifetime);
    
    // Draw rings
    for (var i = 0; i < this.rings.length; i++) {
      var ring = this.rings[i];
      
      if (ring.radius > 0) {
        ctx.globalAlpha = ring.alpha * baseAlpha;
        ctx.strokeStyle = '#4ade80';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(centerX, centerY, ring.radius, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    
    // Draw central glow
    ctx.globalAlpha = baseAlpha;
    var gradient = ctx.createRadialGradient(centerX, centerY, 0, centerX, centerY, 15);
    gradient.addColorStop(0, '#4ade8080');
    gradient.addColorStop(1, '#4ade8000');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(centerX - 15, centerY - 15, 30, 30);
    
    ctx.restore();
  }
});

// Warp Effect (for teleportation/respawn)
EntityWarpEffect = ig.Entity.extend({
  
  size: {x: 60, y: 60},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 60,
  age: 0,
  particles: [],
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Generate swirling particles
    for (var i = 0; i < 20; i++) {
      this.particles.push({
        angle: (i / 20) * Math.PI * 2,
        radius: 5 + Math.random() * 25,
        speed: 0.1 + Math.random() * 0.1,
        size: 1 + Math.random() * 3,
        color: ['#00ffff', '#0080ff', '#8000ff'][Math.floor(Math.random() * 3)]
      });
    }
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    // Update particles
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      particle.angle += particle.speed;
      
      // Spiral inward
      if (this.age < this.lifetime / 2) {
        particle.radius *= 1.02;
      } else {
        particle.radius *= 0.95;
      }
    }
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var centerX = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var centerY = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    var alpha = 1 - (this.age / this.lifetime);
    
    // Draw particles
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      
      var x = centerX + Math.cos(particle.angle) * particle.radius;
      var y = centerY + Math.sin(particle.angle) * particle.radius;
      
      ctx.globalAlpha = alpha;
      ctx.fillStyle = particle.color;
      ctx.fillRect(x - particle.size / 2, y - particle.size / 2, particle.size, particle.size);
      
      // Add glow
      var gradient = ctx.createRadialGradient(x, y, 0, x, y, particle.size * 2);
      gradient.addColorStop(0, particle.color + '80');
      gradient.addColorStop(1, particle.color + '00');
      
      ctx.fillStyle = gradient;
      ctx.fillRect(x - particle.size * 2, y - particle.size * 2, particle.size * 4, particle.size * 4);
    }
    
    ctx.restore();
  }
});

// Shield Bubble Effect
EntityShieldBubble = ig.Entity.extend({
  
  size: {x: 80, y: 80},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  target: null,
  strength: 100,
  maxStrength: 100,
  pulsePhase: 0,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    this.target = settings.target;
    this.strength = settings.strength || 100;
    this.maxStrength = this.strength;
  },
  
  update: function() {
    this.parent();
    
    if (!this.target || this.target._killed) {
      this.kill();
      return;
    }
    
    // Follow target
    this.pos.x = this.target.pos.x + this.target.size.x / 2 - this.size.x / 2;
    this.pos.y = this.target.pos.y + this.target.size.y / 2 - this.size.y / 2;
    
    // Update pulse
    this.pulsePhase += 0.1;
    
    // Decay shield over time
    this.strength -= 0.5;
    
    if (this.strength <= 0) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var centerX = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var centerY = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    var alpha = (this.strength / this.maxStrength) * 0.6;
    var pulse = Math.sin(this.pulsePhase) * 0.1 + 0.9;
    var radius = (this.size.x / 2) * pulse;
    
    // Draw shield bubble
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = '#00ffff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.stroke();
    
    // Draw hexagonal pattern
    ctx.globalAlpha = alpha * 0.3;
    this.drawHexPattern(ctx, centerX, centerY, radius);
    
    ctx.restore();
  },
  
  drawHexPattern: function(ctx, centerX, centerY, radius) {
    var hexSize = 8;
    var rows = Math.floor(radius * 2 / hexSize);
    var cols = Math.floor(radius * 2 / hexSize);
    
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        var x = centerX - radius + col * hexSize + (row % 2) * hexSize / 2;
        var y = centerY - radius + row * hexSize * 0.866;
        
        // Only draw if within circle
        var distance = Math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        if (distance < radius - hexSize) {
          this.drawHexagon(ctx, x, y, hexSize / 2);
        }
      }
    }
  },
  
  drawHexagon: function(ctx, x, y, size) {
    ctx.beginPath();
    for (var i = 0; i < 6; i++) {
      var angle = (i * Math.PI) / 3;
      var hx = x + size * Math.cos(angle);
      var hy = y + size * Math.sin(angle);
      
      if (i === 0) {
        ctx.moveTo(hx, hy);
      } else {
        ctx.lineTo(hx, hy);
      }
    }
    ctx.closePath();
    ctx.stroke();
  },
  
  absorbDamage: function(damage) {
    this.strength -= damage;
    
    // Create absorption effect
    ig.game.spawnEntity(EntityShieldHit, this.pos.x, this.pos.y);
    
    return Math.max(0, damage - this.strength);
  }
});

// Shield Hit Effect
EntityShieldHit = ig.Entity.extend({
  
  size: {x: 20, y: 20},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 20,
  age: 0,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    if (this.age > this.lifetime) {
      this.kill();
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var centerX = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var centerY = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    var alpha = 1 - (this.age / this.lifetime);
    var radius = (this.age / this.lifetime) * 15;
    
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = '#00ffff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.stroke();
    
    // Inner flash
    ctx.globalAlpha = alpha * 0.5;
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius / 2, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.restore();
  }
});

});