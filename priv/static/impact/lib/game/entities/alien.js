ig.module(
  'game.entities.alien'
)
.requires(
  'impact.entity'
)
.defines(function(){

EntityAlien = ig.Entity.extend({
  
  size: {x: 24, y: 24},
  type: ig.Entity.TYPE.B,
  checkAgainst: ig.Entity.TYPE.A,
  collides: ig.Entity.COLLIDES.PASSIVE,
  
  // Alien properties
  health: 50,
  maxHealth: 50,
  speed: 30,
  behavior: 'patrol', // patrol, hunt_player, abduct
  faction: 'alien',
  
  // Visual properties
  color: '#4ade80', // Green
  glowColor: '#22c55e',
  tentacles: [],
  animationPhase: 0,
  
  // Behavior properties
  target: null,
  lastAction: 0,
  abductionBeam: null,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Apply settings
    this.health = settings.health || 50;
    this.maxHealth = this.health;
    this.behavior = settings.behavior || 'patrol';
    this.speed = settings.speed || 30;
    
    // Generate tentacles for visual effect
    this.generateTentacles();
    
    // Set random animation phase
    this.animationPhase = Math.random() * Math.PI * 2;
  },
  
  update: function() {
    this.parent();
    
    // Update animation
    this.animationPhase += 0.1;
    
    // Update behavior
    this.updateBehavior();
    
    // Update tentacles
    this.updateTentacles();
    
    // Check health
    if (this.health <= 0) {
      this.createDeathEffect();
      this.kill();
    }
  },
  
  updateBehavior: function() {
    var currentTime = ig.Timer.time;
    
    switch(this.behavior) {
      case 'patrol':
        this.patrolBehavior();
        break;
      case 'hunt_player':
        this.huntPlayerBehavior();
        break;
      case 'abduct':
        this.abductBehavior();
        break;
    }
  },
  
  patrolBehavior: function() {
    // Move in a random pattern
    var moveX = Math.sin(this.animationPhase) * this.speed * ig.system.tick;
    var moveY = Math.cos(this.animationPhase * 0.7) * this.speed * 0.5 * ig.system.tick;
    
    this.vel.x = moveX;
    this.vel.y = moveY;
    
    // Occasionally change to hunt behavior
    if (Math.random() < 0.001) {
      this.behavior = 'hunt_player';
    }
  },
  
  huntPlayerBehavior: function() {
    // Find player (assuming player entity exists)
    var player = this.findPlayer();
    
    if (player) {
      var dx = player.pos.x - this.pos.x;
      var dy = player.pos.y - this.pos.y;
      var distance = Math.sqrt(dx * dx + dy * dy);
      
      if (distance > 0) {
        this.vel.x = (dx / distance) * this.speed;
        this.vel.y = (dy / distance) * this.speed;
      }
      
      // Switch to abduct if close enough
      if (distance < 50) {
        this.behavior = 'abduct';
      }
    } else {
      // No player found, go back to patrol
      this.behavior = 'patrol';
    }
  },
  
  abductBehavior: function() {
    var player = this.findPlayer();
    
    if (player) {
      var distance = this.distanceTo(player);
      
      if (distance < 80) {
        // Hover above player
        this.vel.x = (player.pos.x - this.pos.x) * 0.5;
        this.vel.y = Math.sin(this.animationPhase * 2) * 10;
        
        // Create abduction beam
        if (!this.abductionBeam) {
          this.abductionBeam = ig.game.spawnEntity(EntityAbductionBeam, 
            this.pos.x, this.pos.y + this.size.y, {
              alien: this,
              target: player
            });
        }
        
        // Attempt abduction
        if (distance < 30 && Math.random() < 0.02) {
          this.attemptAbduction(player);
        }
      } else {
        // Move closer to player
        this.behavior = 'hunt_player';
        if (this.abductionBeam) {
          this.abductionBeam.kill();
          this.abductionBeam = null;
        }
      }
    } else {
      this.behavior = 'patrol';
    }
  },
  
  attemptAbduction: function(player) {
    // Send abduction event to LiveView
    if (window.liveViewHook) {
      window.liveViewHook.pushGameEvent('abduction_attempt', {
        alien_id: this.liveViewId,
        player_x: player.pos.x,
        player_y: player.pos.y
      });
    }
    
    // Create abduction effect
    ig.game.spawnEntity(EntityAbductionEffect, player.pos.x, player.pos.y);
  },
  
  findPlayer: function() {
    // Look for player entity or use player position from LiveView
    var players = ig.game.getEntitiesByType(EntityPlayer);
    return players.length > 0 ? players[0] : null;
  },
  
  generateTentacles: function() {
    this.tentacles = [];
    var tentacleCount = 4 + Math.floor(Math.random() * 3);
    
    for (var i = 0; i < tentacleCount; i++) {
      this.tentacles.push({
        angle: (i / tentacleCount) * Math.PI * 2,
        length: 8 + Math.random() * 6,
        phase: Math.random() * Math.PI * 2,
        speed: 0.05 + Math.random() * 0.05
      });
    }
  },
  
  updateTentacles: function() {
    for (var i = 0; i < this.tentacles.length; i++) {
      var tentacle = this.tentacles[i];
      tentacle.phase += tentacle.speed;
      tentacle.currentLength = tentacle.length + Math.sin(tentacle.phase) * 2;
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var y = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    // Draw glow effect
    this.drawGlow(ctx, x, y);
    
    // Draw tentacles
    this.drawTentacles(ctx, x, y);
    
    // Draw main body
    this.drawBody(ctx, x, y);
    
    // Draw eyes
    this.drawEyes(ctx, x, y);
    
    // Draw health bar
    this.drawHealthBar(ctx, x, y);
    
    ctx.restore();
  },
  
  drawGlow: function(ctx, x, y) {
    var glowRadius = this.size.x + 10;
    var gradient = ctx.createRadialGradient(x, y, 0, x, y, glowRadius);
    
    var alpha = 0.3 + Math.sin(this.animationPhase) * 0.1;
    gradient.addColorStop(0, this.glowColor + Math.floor(alpha * 255).toString(16).padStart(2, '0'));
    gradient.addColorStop(1, this.glowColor + '00');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(x - glowRadius, y - glowRadius, glowRadius * 2, glowRadius * 2);
  },
  
  drawTentacles: function(ctx, centerX, centerY) {
    ctx.strokeStyle = this.color;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    
    for (var i = 0; i < this.tentacles.length; i++) {
      var tentacle = this.tentacles[i];
      var angle = tentacle.angle + Math.sin(this.animationPhase) * 0.2;
      
      var endX = centerX + Math.cos(angle) * tentacle.currentLength;
      var endY = centerY + Math.sin(angle) * tentacle.currentLength;
      
      // Draw curved tentacle
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      
      var controlX = centerX + Math.cos(angle) * tentacle.currentLength * 0.5;
      var controlY = centerY + Math.sin(angle) * tentacle.currentLength * 0.5 + 
                     Math.sin(tentacle.phase) * 3;
      
      ctx.quadraticCurveTo(controlX, controlY, endX, endY);
      ctx.stroke();
    }
  },
  
  drawBody: function(ctx, x, y) {
    // Main body - pulsating ellipse
    var bodyRadius = this.size.x / 2 + Math.sin(this.animationPhase * 2) * 2;
    
    ctx.fillStyle = this.color;
    ctx.beginPath();
    ctx.ellipse(x, y, bodyRadius, bodyRadius * 0.8, 0, 0, Math.PI * 2);
    ctx.fill();
    
    // Body pattern
    ctx.fillStyle = this.darkenColor(this.color, 0.2);
    for (var i = 0; i < 3; i++) {
      var patternRadius = bodyRadius * (0.3 + i * 0.2);
      var patternAlpha = 0.5 - i * 0.15;
      
      ctx.globalAlpha = patternAlpha;
      ctx.beginPath();
      ctx.ellipse(x, y - 2, patternRadius, patternRadius * 0.6, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    
    ctx.globalAlpha = 1;
  },
  
  drawEyes: function(ctx, x, y) {
    var eyeOffset = this.size.x / 4;
    var eyeSize = 3;
    
    // Left eye
    ctx.fillStyle = '#ff0000';
    ctx.beginPath();
    ctx.arc(x - eyeOffset, y - 3, eyeSize, 0, Math.PI * 2);
    ctx.fill();
    
    // Right eye
    ctx.beginPath();
    ctx.arc(x + eyeOffset, y - 3, eyeSize, 0, Math.PI * 2);
    ctx.fill();
    
    // Eye glow
    var eyeGlow = ctx.createRadialGradient(x - eyeOffset, y - 3, 0, x - eyeOffset, y - 3, eyeSize * 2);
    eyeGlow.addColorStop(0, '#ff000080');
    eyeGlow.addColorStop(1, '#ff000000');
    
    ctx.fillStyle = eyeGlow;
    ctx.fillRect(x - eyeOffset - eyeSize * 2, y - 3 - eyeSize * 2, eyeSize * 4, eyeSize * 4);
    ctx.fillRect(x + eyeOffset - eyeSize * 2, y - 3 - eyeSize * 2, eyeSize * 4, eyeSize * 4);
  },
  
  drawHealthBar: function(ctx, x, y) {
    if (this.health < this.maxHealth) {
      var barWidth = this.size.x;
      var barHeight = 3;
      var barY = y - this.size.y / 2 - 8;
      
      // Background
      ctx.fillStyle = '#333333';
      ctx.fillRect(x - barWidth / 2, barY, barWidth, barHeight);
      
      // Health
      var healthPercent = this.health / this.maxHealth;
      var healthColor = healthPercent > 0.5 ? '#4ade80' : healthPercent > 0.25 ? '#fbbf24' : '#ef4444';
      
      ctx.fillStyle = healthColor;
      ctx.fillRect(x - barWidth / 2, barY, barWidth * healthPercent, barHeight);
    }
  },
  
  createDeathEffect: function() {
    // Create explosion effect
    ig.game.spawnEntity(EntityAlienExplosion, 
      this.pos.x + this.size.x / 2, 
      this.pos.y + this.size.y / 2
    );
    
    // Send death event to LiveView
    if (window.liveViewHook) {
      window.liveViewHook.pushGameEvent('entity_destroyed', {
        id: this.liveViewId,
        type: 'alien',
        x: this.pos.x,
        y: this.pos.y
      });
    }
  },
  
  takeDamage: function(amount) {
    this.health -= amount;
    
    // Create damage effect
    ig.game.spawnEntity(EntityDamageNumber, this.pos.x, this.pos.y - 10, {
      damage: amount
    });
    
    // Flash effect
    this.color = '#ffffff';
    setTimeout(() => {
      this.color = '#4ade80';
    }, 100);
  },
  
  // Utility functions
  darkenColor: function(color, amount) {
    var num = parseInt(color.replace("#", ""), 16);
    var amt = Math.round(2.55 * amount * 100);
    var R = (num >> 16) - amt;
    var G = (num >> 8 & 0x00FF) - amt;
    var B = (num & 0x0000FF) - amt;
    
    return "#" + (0x1000000 + (R < 255 ? R < 1 ? 0 : R : 255) * 0x10000 +
      (G < 255 ? G < 1 ? 0 : G : 255) * 0x100 +
      (B < 255 ? B < 1 ? 0 : B : 255)).toString(16).slice(1);
  }
});

// Abduction Beam Effect
EntityAbductionBeam = ig.Entity.extend({
  
  size: {x: 60, y: 200},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  alien: null,
  target: null,
  intensity: 0,
  particles: [],
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    this.alien = settings.alien;
    this.target = settings.target;
    
    // Generate beam particles
    this.generateParticles();
  },
  
  update: function() {
    this.parent();
    
    if (!this.alien || this.alien._killed) {
      this.kill();
      return;
    }
    
    // Follow alien position
    this.pos.x = this.alien.pos.x + this.alien.size.x / 2 - this.size.x / 2;
    this.pos.y = this.alien.pos.y + this.alien.size.y;
    
    // Update intensity
    this.intensity = Math.min(1, this.intensity + 0.02);
    
    // Update particles
    this.updateParticles();
  },
  
  generateParticles: function() {
    this.particles = [];
    for (var i = 0; i < 20; i++) {
      this.particles.push({
        x: Math.random() * this.size.x,
        y: Math.random() * this.size.y,
        speed: 1 + Math.random() * 2,
        size: 1 + Math.random() * 2,
        alpha: Math.random()
      });
    }
  },
  
  updateParticles: function() {
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      particle.y += particle.speed;
      
      if (particle.y > this.size.y) {
        particle.y = 0;
        particle.x = Math.random() * this.size.x;
      }
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x;
    var y = this.pos.y - ig.game.screen.y;
    
    ctx.save();
    
    // Draw beam gradient
    var gradient = ctx.createLinearGradient(x + this.size.x / 2, y, x + this.size.x / 2, y + this.size.y);
    gradient.addColorStop(0, '#4ade8080');
    gradient.addColorStop(0.5, '#4ade8040');
    gradient.addColorStop(1, '#4ade8020');
    
    ctx.fillStyle = gradient;
    ctx.globalAlpha = this.intensity;
    ctx.fillRect(x, y, this.size.x, this.size.y);
    
    // Draw particles
    ctx.fillStyle = '#ffffff';
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      ctx.globalAlpha = particle.alpha * this.intensity;
      ctx.fillRect(x + particle.x, y + particle.y, particle.size, particle.size);
    }
    
    ctx.restore();
  }
});

// Alien Explosion Effect
EntityAlienExplosion = ig.Entity.extend({
  
  size: {x: 40, y: 40},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 30,
  age: 0,
  particles: [],
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Generate explosion particles
    for (var i = 0; i < 15; i++) {
      this.particles.push({
        x: 0,
        y: 0,
        vx: (Math.random() - 0.5) * 100,
        vy: (Math.random() - 0.5) * 100,
        size: 2 + Math.random() * 4,
        color: ['#4ade80', '#22c55e', '#16a34a'][Math.floor(Math.random() * 3)],
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
      particle.life -= ig.system.tick * 2;
      particle.size *= 0.98;
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
    
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      if (particle.life > 0) {
        ctx.fillStyle = particle.color;
        ctx.globalAlpha = particle.life;
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

});