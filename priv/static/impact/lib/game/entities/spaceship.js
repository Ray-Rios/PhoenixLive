ig.module(
  'game.entities.spaceship'
)
.requires(
  'impact.entity'
)
.defines(function(){

EntitySpaceship = ig.Entity.extend({
  
  size: {x: 32, y: 24},
  type: ig.Entity.TYPE.B,
  checkAgainst: ig.Entity.TYPE.B,
  collides: ig.Entity.COLLIDES.PASSIVE,
  
  // Spaceship properties
  health: 100,
  maxHealth: 100,
  speed: 50,
  faction: 'federation', // federation, empire, rebels
  weapons: ['laser', 'missile'],
  
  // Visual properties
  color: '#3b82f6', // Blue for federation
  engineColor: '#fbbf24',
  thrusterParticles: [],
  
  // Combat properties
  target: null,
  lastShot: 0,
  shotCooldown: 1000, // milliseconds
  engagementRange: 150,
  
  // Movement properties
  direction: 0,
  turnSpeed: 2,
  acceleration: 100,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    // Apply settings
    this.health = settings.health || 100;
    this.maxHealth = this.health;
    this.faction = settings.faction || 'federation';
    this.speed = settings.speed || 50;
    
    // Set faction colors
    this.setFactionColors();
    
    // Initialize direction
    this.direction = Math.random() * Math.PI * 2;
    
    // Generate thruster particles
    this.generateThrusterParticles();
  },
  
  update: function() {
    this.parent();
    
    // Update behavior based on faction and situation
    this.updateBehavior();
    
    // Update thruster particles
    this.updateThrusterParticles();
    
    // Apply movement
    this.vel.x = Math.cos(this.direction) * this.speed;
    this.vel.y = Math.sin(this.direction) * this.speed;
    
    // Keep within screen bounds
    this.constrainToScreen();
    
    // Check health
    if (this.health <= 0) {
      this.createDeathEffect();
      this.kill();
    }
  },
  
  updateBehavior: function() {
    var currentTime = ig.Timer.time * 1000;
    
    // Find targets based on faction
    var enemies = this.findEnemies();
    var nearestEnemy = this.findNearestEnemy(enemies);
    
    if (nearestEnemy && this.distanceTo(nearestEnemy) < this.engagementRange) {
      // Combat behavior
      this.engageTarget(nearestEnemy, currentTime);
    } else {
      // Patrol behavior
      this.patrolBehavior();
    }
  },
  
  findEnemies: function() {
    var enemies = [];
    
    // Add aliens as enemies for all factions
    var aliens = ig.game.getEntitiesByType(EntityAlien);
    enemies = enemies.concat(aliens);
    
    // Add enemy spaceships based on faction
    var spaceships = ig.game.getEntitiesByType(EntitySpaceship);
    for (var i = 0; i < spaceships.length; i++) {
      var ship = spaceships[i];
      if (ship !== this && this.isEnemy(ship)) {
        enemies.push(ship);
      }
    }
    
    return enemies;
  },
  
  isEnemy: function(otherShip) {
    switch(this.faction) {
      case 'federation':
        return otherShip.faction === 'empire';
      case 'empire':
        return otherShip.faction === 'federation' || otherShip.faction === 'rebels';
      case 'rebels':
        return otherShip.faction === 'empire';
      default:
        return false;
    }
  },
  
  findNearestEnemy: function(enemies) {
    if (enemies.length === 0) return null;
    
    var nearest = enemies[0];
    var nearestDistance = this.distanceTo(nearest);
    
    for (var i = 1; i < enemies.length; i++) {
      var distance = this.distanceTo(enemies[i]);
      if (distance < nearestDistance) {
        nearest = enemies[i];
        nearestDistance = distance;
      }
    }
    
    return nearest;
  },
  
  engageTarget: function(target, currentTime) {
    this.target = target;
    
    // Turn towards target
    var targetAngle = Math.atan2(
      target.pos.y - this.pos.y,
      target.pos.x - this.pos.x
    );
    
    this.turnTowards(targetAngle);
    
    // Shoot if in range and cooldown is ready
    var distance = this.distanceTo(target);
    if (distance < 100 && currentTime - this.lastShot > this.shotCooldown) {
      this.fireWeapon(target);
      this.lastShot = currentTime;
    }
  },
  
  patrolBehavior: function() {
    // Randomly change direction occasionally
    if (Math.random() < 0.01) {
      this.direction += (Math.random() - 0.5) * 1;
    }
    
    // Avoid screen edges
    var margin = 50;
    if (this.pos.x < margin) {
      this.direction = 0; // Move right
    } else if (this.pos.x > ig.system.width - margin) {
      this.direction = Math.PI; // Move left
    }
    
    if (this.pos.y < margin) {
      this.direction = Math.PI / 2; // Move down
    } else if (this.pos.y > ig.system.height - margin) {
      this.direction = -Math.PI / 2; // Move up
    }
  },
  
  turnTowards: function(targetAngle) {
    var angleDiff = targetAngle - this.direction;
    
    // Normalize angle difference
    while (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
    while (angleDiff < -Math.PI) angleDiff += Math.PI * 2;
    
    // Turn towards target
    if (Math.abs(angleDiff) > 0.1) {
      this.direction += Math.sign(angleDiff) * this.turnSpeed * ig.system.tick;
    }
  },
  
  fireWeapon: function(target) {
    // Create projectile
    var projectileSpeed = 200;
    var dx = target.pos.x - this.pos.x;
    var dy = target.pos.y - this.pos.y;
    var distance = Math.sqrt(dx * dx + dy * dy);
    
    if (distance > 0) {
      var projectile = ig.game.spawnEntity(EntityLaser,
        this.pos.x + this.size.x / 2,
        this.pos.y + this.size.y / 2,
        {
          vel: {
            x: (dx / distance) * projectileSpeed,
            y: (dy / distance) * projectileSpeed
          },
          owner: this,
          damage: 25,
          color: this.color
        }
      );
    }
    
    // Create muzzle flash
    ig.game.spawnEntity(EntityMuzzleFlash,
      this.pos.x + this.size.x / 2,
      this.pos.y + this.size.y / 2
    );
  },
  
  setFactionColors: function() {
    switch(this.faction) {
      case 'federation':
        this.color = '#3b82f6'; // Blue
        this.engineColor = '#fbbf24'; // Yellow
        break;
      case 'empire':
        this.color = '#ef4444'; // Red
        this.engineColor = '#f97316'; // Orange
        break;
      case 'rebels':
        this.color = '#10b981'; // Green
        this.engineColor = '#06b6d4'; // Cyan
        break;
    }
  },
  
  generateThrusterParticles: function() {
    this.thrusterParticles = [];
    for (var i = 0; i < 8; i++) {
      this.thrusterParticles.push({
        x: 0,
        y: 0,
        life: Math.random(),
        maxLife: 0.5 + Math.random() * 0.5,
        size: 1 + Math.random() * 2
      });
    }
  },
  
  updateThrusterParticles: function() {
    for (var i = 0; i < this.thrusterParticles.length; i++) {
      var particle = this.thrusterParticles[i];
      
      // Update particle life
      particle.life -= ig.system.tick * 3;
      
      if (particle.life <= 0) {
        // Reset particle
        particle.life = particle.maxLife;
        particle.x = -Math.cos(this.direction) * (this.size.x / 2 + 5 + Math.random() * 10);
        particle.y = -Math.sin(this.direction) * (this.size.y / 2 + 5 + Math.random() * 10);
        particle.size = 1 + Math.random() * 2;
      }
    }
  },
  
  constrainToScreen: function() {
    if (this.pos.x < 0) {
      this.pos.x = 0;
      this.direction = -this.direction + Math.PI;
    } else if (this.pos.x > ig.system.width - this.size.x) {
      this.pos.x = ig.system.width - this.size.x;
      this.direction = -this.direction + Math.PI;
    }
    
    if (this.pos.y < 0) {
      this.pos.y = 0;
      this.direction = -this.direction;
    } else if (this.pos.y > ig.system.height - this.size.y) {
      this.pos.y = ig.system.height - this.size.y;
      this.direction = -this.direction;
    }
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x + this.size.x / 2;
    var y = this.pos.y - ig.game.screen.y + this.size.y / 2;
    
    ctx.save();
    
    // Draw thruster particles first (behind ship)
    this.drawThrusterParticles(ctx, x, y);
    
    // Rotate context for ship direction
    ctx.translate(x, y);
    ctx.rotate(this.direction);
    
    // Draw ship body
    this.drawShipBody(ctx);
    
    // Draw faction markings
    this.drawFactionMarkings(ctx);
    
    ctx.restore();
    
    // Draw health bar (not rotated)
    this.drawHealthBar(ctx, x, y);
    
    // Draw shield effect if damaged
    if (this.health < this.maxHealth * 0.5) {
      this.drawShieldEffect(ctx, x, y);
    }
  },
  
  drawShipBody: function(ctx) {
    // Main hull
    ctx.fillStyle = this.color;
    ctx.beginPath();
    ctx.ellipse(0, 0, this.size.x / 2, this.size.y / 3, 0, 0, Math.PI * 2);
    ctx.fill();
    
    // Cockpit
    ctx.fillStyle = this.lightenColor(this.color, 0.3);
    ctx.beginPath();
    ctx.ellipse(this.size.x / 4, 0, this.size.x / 6, this.size.y / 6, 0, 0, Math.PI * 2);
    ctx.fill();
    
    // Wings
    ctx.fillStyle = this.darkenColor(this.color, 0.2);
    ctx.fillRect(-this.size.x / 3, -this.size.y / 2, this.size.x / 6, this.size.y);
    ctx.fillRect(-this.size.x / 3, this.size.y / 3, this.size.x / 6, this.size.y / 6);
    
    // Engine exhausts
    ctx.fillStyle = this.engineColor;
    ctx.fillRect(-this.size.x / 2, -this.size.y / 6, this.size.x / 8, this.size.y / 12);
    ctx.fillRect(-this.size.x / 2, this.size.y / 12, this.size.x / 8, this.size.y / 12);
  },
  
  drawFactionMarkings: function(ctx) {
    ctx.fillStyle = '#ffffff';
    ctx.font = '8px Arial';
    ctx.textAlign = 'center';
    
    var symbol = '';
    switch(this.faction) {
      case 'federation':
        symbol = '★';
        break;
      case 'empire':
        symbol = '▲';
        break;
      case 'rebels':
        symbol = '◆';
        break;
    }
    
    ctx.fillText(symbol, 0, 2);
  },
  
  drawThrusterParticles: function(ctx, centerX, centerY) {
    ctx.fillStyle = this.engineColor;
    
    for (var i = 0; i < this.thrusterParticles.length; i++) {
      var particle = this.thrusterParticles[i];
      
      if (particle.life > 0) {
        var alpha = particle.life / particle.maxLife;
        ctx.globalAlpha = alpha;
        
        var particleX = centerX + particle.x;
        var particleY = centerY + particle.y;
        
        ctx.fillRect(
          particleX - particle.size / 2,
          particleY - particle.size / 2,
          particle.size,
          particle.size
        );
      }
    }
    
    ctx.globalAlpha = 1;
  },
  
  drawHealthBar: function(ctx, x, y) {
    if (this.health < this.maxHealth) {
      var barWidth = this.size.x;
      var barHeight = 3;
      var barY = y - this.size.y / 2 - 10;
      
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
  
  drawShieldEffect: function(ctx, x, y) {
    var time = ig.Timer.time;
    var alpha = 0.3 + Math.sin(time * 10) * 0.2;
    
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = '#00ffff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(x, y, this.size.x / 2 + 5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  },
  
  createDeathEffect: function() {
    // Create explosion effect
    ig.game.spawnEntity(EntitySpaceshipExplosion,
      this.pos.x + this.size.x / 2,
      this.pos.y + this.size.y / 2,
      { faction: this.faction }
    );
    
    // Send death event to LiveView
    if (window.liveViewHook) {
      window.liveViewHook.pushGameEvent('entity_destroyed', {
        id: this.liveViewId,
        type: 'spaceship',
        faction: this.faction,
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
    var originalColor = this.color;
    this.color = '#ffffff';
    setTimeout(() => {
      this.color = originalColor;
    }, 100);
  },
  
  // Utility functions
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

// Laser Projectile
EntityLaser = ig.Entity.extend({
  
  size: {x: 8, y: 2},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.B,
  collides: ig.Entity.COLLIDES.NEVER,
  
  damage: 25,
  color: '#3b82f6',
  owner: null,
  lifetime: 3, // seconds
  age: 0,
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    
    this.damage = settings.damage || 25;
    this.color = settings.color || '#3b82f6';
    this.owner = settings.owner;
    
    // Set velocity if provided
    if (settings.vel) {
      this.vel.x = settings.vel.x;
      this.vel.y = settings.vel.y;
    }
  },
  
  update: function() {
    this.parent();
    
    this.age += ig.system.tick;
    
    // Remove after lifetime
    if (this.age > this.lifetime) {
      this.kill();
    }
    
    // Remove if off screen
    if (this.pos.x < -50 || this.pos.x > ig.system.width + 50 ||
        this.pos.y < -50 || this.pos.y > ig.system.height + 50) {
      this.kill();
    }
  },
  
  check: function(other) {
    // Don't hit owner
    if (other === this.owner) return;
    
    // Deal damage
    if (other.takeDamage) {
      other.takeDamage(this.damage);
    }
    
    // Create impact effect
    ig.game.spawnEntity(EntityLaserImpact, this.pos.x, this.pos.y, {
      color: this.color
    });
    
    this.kill();
  },
  
  draw: function() {
    if (!ig.system.context) return;
    
    var ctx = ig.system.context;
    var x = this.pos.x - ig.game.screen.x;
    var y = this.pos.y - ig.game.screen.y;
    
    ctx.save();
    
    // Draw laser beam with glow
    var gradient = ctx.createLinearGradient(x, y, x + this.size.x, y);
    gradient.addColorStop(0, this.color + '00');
    gradient.addColorStop(0.5, this.color);
    gradient.addColorStop(1, this.color + '00');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(x, y, this.size.x, this.size.y);
    
    // Core beam
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(x + 1, y + this.size.y / 4, this.size.x - 2, this.size.y / 2);
    
    ctx.restore();
  }
});

// Spaceship Explosion Effect
EntitySpaceshipExplosion = ig.Entity.extend({
  
  size: {x: 60, y: 60},
  type: ig.Entity.TYPE.NONE,
  checkAgainst: ig.Entity.TYPE.NONE,
  collides: ig.Entity.COLLIDES.NEVER,
  
  lifetime: 60,
  age: 0,
  particles: [],
  faction: 'federation',
  
  init: function(x, y, settings) {
    this.parent(x, y, settings);
    this.faction = settings.faction || 'federation';
    
    // Generate explosion particles
    for (var i = 0; i < 25; i++) {
      this.particles.push({
        x: 0,
        y: 0,
        vx: (Math.random() - 0.5) * 150,
        vy: (Math.random() - 0.5) * 150,
        size: 2 + Math.random() * 6,
        color: this.getExplosionColor(),
        life: 1,
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 10
      });
    }
  },
  
  getExplosionColor: function() {
    var colors = ['#ff6b35', '#f7931e', '#ffcc02', '#fff200'];
    return colors[Math.floor(Math.random() * colors.length)];
  },
  
  update: function() {
    this.parent();
    
    this.age++;
    
    // Update particles
    for (var i = 0; i < this.particles.length; i++) {
      var particle = this.particles[i];
      particle.x += particle.vx * ig.system.tick;
      particle.y += particle.vy * ig.system.tick;
      particle.life -= ig.system.tick * 1.5;
      particle.size *= 0.98;
      particle.rotation += particle.rotationSpeed * ig.system.tick;
      
      // Add gravity effect
      particle.vy += 20 * ig.system.tick;
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
        ctx.save();
        ctx.translate(centerX + particle.x, centerY + particle.y);
        ctx.rotate(particle.rotation);
        
        ctx.fillStyle = particle.color;
        ctx.globalAlpha = particle.life;
        ctx.fillRect(-particle.size / 2, -particle.size / 2, particle.size, particle.size);
        
        ctx.restore();
      }
    }
    
    ctx.restore();
  }
});

});