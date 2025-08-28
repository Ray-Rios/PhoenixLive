let Hooks = {};

Hooks.ImpactGame = {
  mounted() {
    const canvas = this.el;
    this.players = JSON.parse(canvas.dataset.players);
    this.currentPlayerId = canvas.dataset.currentPlayer;

    const jumpVelocity = -10;
    const gravity = 0.5;
    const moveSpeed = 5;
    const floorY = 584;
    const playerRadius = 8;


    const rawLevel = canvas.dataset.level;
    if (rawLevel) {
      this.levelPath = rawLevel.replace("/impact/levels/", "").replace(".js", "");
    } else {
      console.warn("No data-level provided on canvas, using default");
      this.levelPath = "default"; // safe fallback
    }

    // Track chat messages with timestamps
    this.chatMessages = {};

    // Initialize ImpactJS game
    ig.module('game.main')
      .requires('impact.game', 'impact.entities', 'impact.levels.' + levelPath)
      .defines(() => {
        MyGame = ig.Game.extend({
          players: this.players,
          currentPlayerId: this.currentPlayerId,
          update() {
            this.parent();
            const playerIds = Object.keys(this.players);

            for (let i = 0; i < playerIds.length; i++) {
              const p = this.players[playerIds[i]];

              // Apply horizontal movement
              p.x += p.velocityX || 0;

              // Apply vertical movement and gravity
              if (!p.onGround) {
                p.velocityY = (p.velocityY || 0) + gravity;
              }
              p.y += p.velocityY || 0;

              // Floor collision
              if (p.y > floorY) {
                p.y = floorY;
                p.velocityY = 0;
                p.onGround = true;
              }

              // Wall collision
              if (p.x < 0) { p.x = 0; p.velocityX = 0; }
              if (p.x > 784) { p.x = 784; p.velocityX = 0; }
              if (p.y < 0) { p.y = 0; p.velocityY *= -1; }
            }

            // Player collisions (simple circle collision)
            for (let i = 0; i < playerIds.length; i++) {
              const p1 = this.players[playerIds[i]];
              for (let j = i + 1; j < playerIds.length; j++) {
                const p2 = this.players[playerIds[j]];
                const dx = p2.x - p1.x;
                const dy = p2.y - p1.y;
                const dist = Math.sqrt(dx*dx + dy*dy);
                if (dist < playerRadius*2) {
                  // Push them apart
                  const overlap = (playerRadius*2 - dist) / 2;
                  const nx = dx / dist;
                  const ny = dy / dist;
                  p1.x -= nx * overlap;
                  p1.y -= ny * overlap;
                  p2.x += nx * overlap;
                  p2.y += ny * overlap;
                }
              }
            }
          },
          draw() {
            this.parent();
            const ctx = this.context;

            for (const id in this.players) {
              const p = this.players[id];

              // Draw avatar (circle)
              ctx.fillStyle = p.color || "#3B82F6";
              ctx.beginPath();
              ctx.arc(p.x + 8, p.y + 8, playerRadius, 0, 2 * Math.PI);
              ctx.fill();

              // Draw chat messages
              if (p.message && p.message_time) {
                const elapsed = Date.now() - p.message_time;
                if (elapsed < 1500) {
                  ctx.globalAlpha = 1 - elapsed / 1500;
                  ctx.fillStyle = "#fff";
                  ctx.font = "12px Arial";
                  ctx.textAlign = "center";
                  ctx.fillText(p.message, p.x + 8, p.y - 10 - (elapsed / 20)); // float up
                  ctx.globalAlpha = 1;
                }
              }
            }
          }
        });

        ig.main('#impact-game', MyGame, 60, 800, 600, 1);
      });

    // Listen for LiveView updates
    this.handleEvent("playersUpdated", ({ players }) => {
      if (MyGame) MyGame.players = players;
    });

    // Movement & jump handling
    document.addEventListener('keydown', (e) => {
      const current = this.players[this.currentPlayerId];
      if (!current) return;

      // Ignore movement if typing
      if (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA') return;

      switch(e.code) {
        case 'ArrowLeft':
        case 'KeyA':
          current.velocityX = -moveSpeed;
          break;
        case 'ArrowRight':
        case 'KeyD':
          current.velocityX = moveSpeed;
          break;
        case 'Space':
          if (current.onGround) {
            current.velocityY = jumpVelocity;
            current.onGround = false;
          }
          break;
      }
    });

    document.addEventListener('keyup', (e) => {
      const current = this.players[this.currentPlayerId];
      if (!current) return;

      if (['ArrowLeft', 'ArrowRight', 'KeyA', 'KeyD'].includes(e.code)) {
        current.velocityX = 0;
      }
    });
  },

  updated() {
    if (!this.players) return;
    for (const id in this.players) {
      const p = this.players[id];
      if (p.x < 0 || p.x > 784) p.velocityX = 0;
      if (p.y < 0 || p.y > 584) p.velocityY = 0;
    }
  }
};

export default Hooks;
