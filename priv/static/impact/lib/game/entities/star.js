ig.module(
  'game.entities.star'
)
  .requires(
    'impact.entity'
  )
  .defines(function () {

    EntityStar = ig.Entity.extend({

      size: { x: 4, y: 4 },
      type: ig.Entity.TYPE.NONE,
      checkAgainst: ig.Entity.TYPE.NONE,
      collides: ig.Entity.COLLIDES.NEVER,

      // Star properties
      baseSize: 2,
      brightness: 1.0,
      twinkleSpeed: 0.02,
      twinklePhase: 0,
      color: '#FFFFFF',
      glowRadius: 10,

      init: function (x, y, settings) {
        this.parent(x, y, settings);

        // Ensure settings is an object
        settings = settings || {};

        // Randomize star properties if not provided with validation
        this.baseSize = Math.max(0.5, settings.size || (Math.random() * 3 + 1));
        this.brightness = Math.max(0.1, Math.min(1, settings.brightness || Math.random()));
        this.twinkleSpeed = Math.max(0.001, settings.twinkle_speed || (Math.random() * 0.05 + 0.01));
        this.twinklePhase = Math.random() * Math.PI * 2;
        this.color = settings.color || '#FFFFFF';
        this.glowRadius = Math.max(1, this.baseSize * 3);

        // Initialize current brightness
        this.currentBrightness = this.brightness;

        // Set size based on base size with validation
        this.size.x = this.size.y = Math.max(1, this.baseSize);
      },

      update: function () {
        this.parent();

        // Update twinkle animation
        this.twinklePhase += this.twinkleSpeed;

        // Calculate current brightness with twinkle effect
        var twinkle = Math.sin(this.twinklePhase) * 0.3 + 0.7;
        this.currentBrightness = this.brightness * twinkle;
      },

      draw: function () {
        // Temporarily use simple star rendering to avoid gradient issues
        if (!ig.system.context) return;

        var ctx = ig.system.context;
        var x = this.pos.x - ig.game.screen.x;
        var y = this.pos.y - ig.game.screen.y;

        // Basic validation
        if (!isFinite(x) || !isFinite(y) || !this.currentBrightness) {
          return;
        }

        ctx.save();

        // Simple star rendering without gradients
        var alpha = Math.max(0, Math.min(1, this.currentBrightness || 0.5));

        // Draw simple star point
        ctx.fillStyle = this.color;
        ctx.globalAlpha = alpha;
        ctx.fillRect(x, y, Math.max(1, this.size.x), Math.max(1, this.size.y));

        ctx.restore();
      },

      // Handle click interactions
      handleClick: function () {
        // Create ripple effect
        ig.game.spawnEntity(EntityStarRipple, this.pos.x, this.pos.y, {
          color: this.color,
          maxRadius: 50
        });

        // Send event to LiveView
        if (window.liveSocket) {
          window.liveSocket.execJS(document.body,
            `this.pushEvent("star_click", {star_id: "${this.id}"})`
          );
        }
      }
    });

    // Ripple effect entity for star interactions
    EntityStarRipple = ig.Entity.extend({

      size: { x: 1, y: 1 },
      type: ig.Entity.TYPE.NONE,
      checkAgainst: ig.Entity.TYPE.NONE,
      collides: ig.Entity.COLLIDES.NEVER,

      radius: 0,
      maxRadius: 30,
      color: '#4FC3F7',
      lifetime: 60, // frames
      age: 0,

      init: function (x, y, settings) {
        this.parent(x, y, settings);
        this.maxRadius = settings.maxRadius || 30;
        this.color = settings.color || '#4FC3F7';
      },

      update: function () {
        this.parent();

        this.age++;
        this.radius = (this.age / this.lifetime) * this.maxRadius;

        if (this.age >= this.lifetime) {
          this.kill();
        }
      },

      draw: function () {
        if (!ig.system.context) return;

        var ctx = ig.system.context;
        var x = this.pos.x - ig.game.screen.x;
        var y = this.pos.y - ig.game.screen.y;

        ctx.save();

        var alpha = 1 - (this.age / this.lifetime);
        ctx.strokeStyle = this.color;
        ctx.globalAlpha = alpha;
        ctx.lineWidth = 2;

        ctx.beginPath();
        ctx.arc(x, y, this.radius, 0, Math.PI * 2);
        ctx.stroke();

        ctx.restore();
      }
    });

  });