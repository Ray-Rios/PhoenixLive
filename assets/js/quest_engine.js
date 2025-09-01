// Full Screen Galaxy Quest Engine - Fixed
class QuestEngine {
  constructor(canvas, hook) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.hook = hook;
    this.players = {};
    this.currentPlayerId = null;
    this.keys = {};
    this.entities = [];
    this.isTyping = false;
    
    this.init();
  }
  
  init() {
    this.resizeCanvas();
    this.setupEventListeners();
    this.spawnEntities();
    this.gameLoop();
  }
  
  resizeCanvas() {
    try {
      this.canvas.width = window.innerWidth;
      this.canvas.height = window.innerHeight;
    } catch (e) {
      console.error('Canvas resize error:', e);
    }
  }
  
  setupEventListeners() {
    try {
      // Window resize
      window.addEventListener('resize', () => {
        this.resizeCanvas();
      });
      
      // Track if user is typing in chat
      const chatInput = document.querySelector('input[name="message"]');
      if (chatInput) {
        chatInput.addEventListener('focus', () => {
          this.isTyping = true;
        });
        chatInput.addEventListener('blur', () => {
          this.isTyping = false;
        });
      }
      
      // Keyboard controls - only when not typing
      document.addEventListener('keydown', (e) => {
        if (this.isTyping) return;
        
        this.keys[e.code] = true;
        
        if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight'].includes(e.code)) {
          e.preventDefault();
        }
      });
      
      document.addEventListener('keyup', (e) => {
        if (this.isTyping) return;
        this.keys[e.code] = false;
      });
      
      // Mouse controls
      this.canvas.addEventListener('click', (e) => {
        try {
          const rect = this.canvas.getBoundingClientRect();
          const x = e.clientX - rect.left;
          const y = e.clientY - rect.top;
          
          if (this.currentPlayerId && this.players[this.currentPlayerId]) {
            this.hook.pushEvent('move_player', { x: Math.floor(x), y: Math.floor(y) });
          }
        } catch (error) {
          console.error('Click handler error:', error);
        }
      });
    } catch (e) {
      console.error('Event listener setup error:', e);
    }
  }
  
  spawnEntities() {
    try {
      this.entities = [];
      
      // Create stars
      const starCount = 150;
      for (let i = 0; i < starCount; i++) {
        this.entities.push({
          type: 'star',
          x: Math.random() * this.canvas.width,
          y: Math.random() * this.canvas.height,
          size: Math.random() * 3 + 1,
          brightness: Math.random(),
          twinkle: Math.random() * Math.PI * 2,
          twinkleSpeed: Math.random() * 0.02 + 0.01
        });
      }

      // Create aliens - proper UFO design
      for (let i = 0; i < 4; i++) {
        this.entities.push({
          type: 'alien',
          x: Math.random() * this.canvas.width,
          y: Math.random() * this.canvas.height,
          vx: (Math.random() - 0.5) * 3,
          vy: (Math.random() - 0.5) * 3,
          size: 30,
          abductionRange: 80,
          lastDirectionChange: 0,
          beamActive: false,
          beamTarget: null
        });
      }
    } catch (e) {
      console.error('Entity spawn error:', e);
    }
  }
  
  handleMovement() {
    try {
      if (this.isTyping) return;
      
      const player = this.players[this.currentPlayerId];
      if (!player) return;
      
      let newX = player.x;
      let newY = player.y;
      const speed = 6;
      let moved = false;
      
      if (this.keys['KeyA'] || this.keys['ArrowLeft']) {
        newX = Math.max(20, player.x - speed);
        moved = true;
      }
      if (this.keys['KeyD'] || this.keys['ArrowRight']) {
        newX = Math.min(this.canvas.width - 20, player.x + speed);
        moved = true;
      }
      if (this.keys['KeyW'] || this.keys['ArrowUp']) {
        newY = Math.max(20, player.y - speed);
        moved = true;
      }
      if (this.keys['KeyS'] || this.keys['ArrowDown']) {
        newY = Math.min(this.canvas.height - 20, player.y + speed);
        moved = true;
      }
      
      if (moved) {
        this.hook.pushEvent('move_player', { x: Math.floor(newX), y: Math.floor(newY) });
      }
    } catch (e) {
      console.error('Movement error:', e);
    }
  }
  
  updateEntities() {
    try {
      const currentTime = Date.now();
      
      this.entities.forEach(entity => {
        if (entity.type === 'star') {
          entity.twinkle += entity.twinkleSpeed;
        } else if (entity.type === 'alien') {
          // Move alien
          entity.x += entity.vx;
          entity.y += entity.vy;

          // Bounce off walls
          if (entity.x <= entity.size || entity.x >= this.canvas.width - entity.size) {
            entity.vx *= -1;
            entity.x = Math.max(entity.size, Math.min(this.canvas.width - entity.size, entity.x));
          }
          if (entity.y <= entity.size || entity.y >= this.canvas.height - entity.size) {
            entity.vy *= -1;
            entity.y = Math.max(entity.size, Math.min(this.canvas.height - entity.size, entity.y));
          }

          // Random direction changes
          if (currentTime - entity.lastDirectionChange > 3000 && Math.random() < 0.01) {
            entity.vx += (Math.random() - 0.5) * 2;
            entity.vy += (Math.random() - 0.5) * 2;
            
            const speed = Math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy);
            if (speed > 4) {
              entity.vx = (entity.vx / speed) * 4;
              entity.vy = (entity.vy / speed) * 4;
            }
            
            entity.lastDirectionChange = currentTime;
          }

          // Check collision with current player
          const player = this.players[this.currentPlayerId];
          if (player) {
            const distance = Math.sqrt(
              Math.pow(entity.x - player.x, 2) + 
              Math.pow(entity.y - player.y, 2)
            );
            
            if (distance < entity.abductionRange) {
              entity.beamActive = true;
              entity.beamTarget = { x: player.x, y: player.y };
              
              if (distance < 40) {
                this.hook.pushEvent('player_abducted', { player_id: this.currentPlayerId });
              }
            } else {
              entity.beamActive = false;
              entity.beamTarget = null;
            }
          }
        }
      });
    } catch (e) {
      console.error('Entity update error:', e);
    }
  }
  
  updatePlayers(players) {
    this.players = players;
  }
  
  setCurrentPlayer(playerId) {
    this.currentPlayerId = playerId;
  }
  
  render() {
    try {
      // Clear canvas
      this.ctx.fillStyle = '#000011';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      // Draw entities
      this.drawEntities();
      
      // Draw players
      Object.values(this.players).forEach(player => {
        this.drawPlayer(player);
      });
    } catch (e) {
      console.error('Render error:', e);
    }
  }
  
  drawEntities() {
    try {
      this.entities.forEach(entity => {
        this.ctx.save();
        
        if (entity.type === 'star') {
          const alpha = entity.brightness * (Math.sin(entity.twinkle) * 0.4 + 0.6);
          this.ctx.fillStyle = '#ffffff';
          this.ctx.globalAlpha = alpha;
          this.ctx.fillRect(entity.x, entity.y, entity.size, entity.size);
          
        } else if (entity.type === 'alien') {
          // Draw abduction beam first (behind UFO)
          if (entity.beamActive && entity.beamTarget) {
            this.ctx.strokeStyle = 'rgba(0, 255, 100, 0.6)';
            this.ctx.lineWidth = 8;
            this.ctx.beginPath();
            this.ctx.moveTo(entity.x, entity.y + entity.size/2);
            this.ctx.lineTo(entity.beamTarget.x, entity.beamTarget.y);
            this.ctx.stroke();
            
            // Beam glow
            this.ctx.strokeStyle = 'rgba(255, 255, 0, 0.3)';
            this.ctx.lineWidth = 16;
            this.ctx.stroke();
          }
          
          // Draw UFO body (metallic disc)
          this.ctx.fillStyle = '#666666';
          this.ctx.beginPath();
          this.ctx.ellipse(entity.x, entity.y, entity.size, entity.size * 0.4, 0, 0, Math.PI * 2);
          this.ctx.fill();
          
          // UFO highlight
          this.ctx.fillStyle = '#999999';
          this.ctx.beginPath();
          this.ctx.ellipse(entity.x, entity.y - 3, entity.size * 0.8, entity.size * 0.3, 0, 0, Math.PI * 2);
          this.ctx.fill();
          
          // UFO dome
          this.ctx.fillStyle = 'rgba(0, 255, 100, 0.7)';
          this.ctx.beginPath();
          this.ctx.ellipse(entity.x, entity.y - entity.size * 0.2, entity.size * 0.6, entity.size * 0.3, 0, 0, Math.PI * 2);
          this.ctx.fill();
          
          // UFO dome highlight
          this.ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
          this.ctx.beginPath();
          this.ctx.ellipse(entity.x - entity.size * 0.2, entity.y - entity.size * 0.3, entity.size * 0.2, entity.size * 0.15, 0, 0, Math.PI * 2);
          this.ctx.fill();
          
          // Rotating lights around the edge
          const time = Date.now() * 0.005;
          this.ctx.fillStyle = '#ffff00';
          for (let i = 0; i < 6; i++) {
            const angle = (i / 6) * Math.PI * 2 + time;
            const lightX = entity.x + Math.cos(angle) * entity.size * 0.9;
            const lightY = entity.y + Math.sin(angle) * entity.size * 0.35;
            this.ctx.beginPath();
            this.ctx.arc(lightX, lightY, 4, 0, Math.PI * 2);
            this.ctx.fill();
            
            // Light glow
            this.ctx.fillStyle = 'rgba(255, 255, 0, 0.3)';
            this.ctx.beginPath();
            this.ctx.arc(lightX, lightY, 8, 0, Math.PI * 2);
            this.ctx.fill();
            this.ctx.fillStyle = '#ffff00';
          }
        }
        
        this.ctx.restore();
      });
    } catch (e) {
      console.error('Entity draw error:', e);
    }
  }
  
  drawPlayer(player) {
    try {
      const x = player.x || 100;
      const y = player.y || 100;
      const isCurrentPlayer = player.id === this.currentPlayerId;
      const radius = isCurrentPlayer ? 12 : 10;
      
      this.ctx.save();
      
      // Player glow
      if (isCurrentPlayer) {
        this.ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        this.ctx.beginPath();
        this.ctx.arc(x, y, radius + 5, 0, Math.PI * 2);
        this.ctx.fill();
      }
      
      // Player body
      this.ctx.fillStyle = player.color || '#3B82F6';
      this.ctx.beginPath();
      this.ctx.arc(x, y, radius, 0, Math.PI * 2);
      this.ctx.fill();
      
      // Player border
      this.ctx.strokeStyle = isCurrentPlayer ? '#fbbf24' : '#ffffff';
      this.ctx.lineWidth = isCurrentPlayer ? 3 : 2;
      this.ctx.stroke();
      
      // Simple face
      this.ctx.fillStyle = 'white';
      this.ctx.beginPath();
      this.ctx.arc(x - 4, y - 3, 2, 0, Math.PI * 2);
      this.ctx.arc(x + 4, y - 3, 2, 0, Math.PI * 2);
      this.ctx.fill();
      
      this.ctx.strokeStyle = 'white';
      this.ctx.lineWidth = 1.5;
      this.ctx.beginPath();
      this.ctx.arc(x, y + 2, 5, 0, Math.PI);
      this.ctx.stroke();
      
      // Player name
      this.ctx.fillStyle = '#ffffff';
      this.ctx.font = 'bold 14px Arial';
      this.ctx.textAlign = 'center';
      this.ctx.strokeStyle = '#000000';
      this.ctx.lineWidth = 3;
      this.ctx.strokeText(player.name || 'Player', x, y - radius - 8);
      this.ctx.fillText(player.name || 'Player', x, y - radius - 8);
      
      // Chat bubble
      if (player.message && player.message_time) {
        const timeSince = Date.now() - player.message_time;
        if (timeSince < 8000) {
          this.drawChatBubble(x, y - radius - 25, player.message);
        }
      }
      
      this.ctx.restore();
    } catch (e) {
      console.error('Player draw error:', e);
    }
  }
  
  drawChatBubble(x, y, message) {
    try {
      const padding = 12;
      const maxWidth = 250;
      
      this.ctx.font = '14px Arial';
      const textWidth = this.ctx.measureText(message).width;
      const bubbleWidth = Math.min(maxWidth, textWidth + padding * 2);
      const bubbleHeight = 30;
      
      // Bubble background
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
      this.ctx.fillRect(x - bubbleWidth / 2, y - bubbleHeight, bubbleWidth, bubbleHeight);
      
      // Bubble border
      this.ctx.strokeStyle = '#00ff44';
      this.ctx.lineWidth = 2;
      this.ctx.strokeRect(x - bubbleWidth / 2, y - bubbleHeight, bubbleWidth, bubbleHeight);
      
      // Bubble tail
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
      this.ctx.beginPath();
      this.ctx.moveTo(x - 8, y);
      this.ctx.lineTo(x + 8, y);
      this.ctx.lineTo(x, y - 12);
      this.ctx.closePath();
      this.ctx.fill();
      this.ctx.stroke();
      
      // Text
      this.ctx.fillStyle = 'white';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(message, x, y - bubbleHeight/2 + 5);
    } catch (e) {
      console.error('Chat bubble draw error:', e);
    }
  }
  
  gameLoop() {
    try {
      this.handleMovement();
      this.updateEntities();
      this.render();
      requestAnimationFrame(() => this.gameLoop());
    } catch (e) {
      console.error('Game loop error:', e);
      // Try to restart the game loop after a delay
      setTimeout(() => {
        requestAnimationFrame(() => this.gameLoop());
      }, 1000);
    }
  }
}

window.QuestEngine = QuestEngine;