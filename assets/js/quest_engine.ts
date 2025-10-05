// Simple Galaxy Quest Engine
import { Player, Alien, Bullet, KeyMap, QuestEngineHook } from './types/quest-engine';

class QuestEngine {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private hook: QuestEngineHook;
  private players: Record<string, Player> = {};
  private currentPlayerId: string | null = null;
  private keys: KeyMap = {};
  private aliens: Alien[] = [];
  private bullets: Bullet[] = [];
  private isTyping: boolean = false;
  private lastShot: number = 0;
  private lastMoveUpdate: number = 0;
  private readonly moveUpdateDelay: number = 100; // Update position every 100ms instead of every frame

  constructor(canvas: HTMLCanvasElement, hook: QuestEngineHook) {
    this.canvas = canvas;
    const context = canvas.getContext('2d');
    if (!context) {
      throw new Error('Unable to get 2D context from canvas');
    }
    this.ctx = context;
    this.hook = hook;
    
    this.init();
  }
  
  private init(): void {
    this.setupCanvas();
    this.setupEventListeners();
    this.spawnAliens();
    this.gameLoop();
  }
  
  private setupCanvas(): void {
    // Fixed canvas size to prevent zoom issues
    this.canvas.width = 1920;
    this.canvas.height = 1080;
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';
    this.canvas.style.objectFit = 'contain';
  }
  
  private setupEventListeners(): void {
    // Chat input detection
    const chatInput = document.querySelector('input[name="message"]') as HTMLInputElement;
    if (chatInput) {
      chatInput.addEventListener('focus', () => this.isTyping = true);
      chatInput.addEventListener('blur', () => this.isTyping = false);
    }
    
    // Keyboard
    document.addEventListener('keydown', (e: KeyboardEvent) => {
      if (this.isTyping) return;
      this.keys[e.code] = true;
      
      if (e.code === 'Space') {
        e.preventDefault();
        this.shoot();
      }
      
      if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight', 'Space'].includes(e.code)) {
        e.preventDefault();
      }
    });
    
    document.addEventListener('keyup', (e: KeyboardEvent) => {
      if (this.isTyping) return;
      this.keys[e.code] = false;
    });
    
    // Mouse click to move
    this.canvas.addEventListener('click', (e: MouseEvent) => {
      const rect = this.canvas.getBoundingClientRect();
      const scaleX = this.canvas.width / rect.width;
      const scaleY = this.canvas.height / rect.height;
      const x = (e.clientX - rect.left) * scaleX;
      const y = (e.clientY - rect.top) * scaleY;
      
      if (this.currentPlayerId && this.players[this.currentPlayerId]) {
        // Use the same throttling mechanism for click movements
        const now = Date.now();
        if (now - this.lastMoveUpdate > this.moveUpdateDelay) {
          this.hook.pushEvent('move_player', { x: Math.floor(x), y: Math.floor(y) });
          this.lastMoveUpdate = now;
        }
      }
    });
  }
  
  private spawnAliens(): void {
    this.aliens = [];
    for (let i = 0; i < 5; i++) {
      this.aliens.push({
        id: i,
        x: Math.random() * (this.canvas.width - 100) + 50,
        y: Math.random() * (this.canvas.height - 100) + 50,
        vx: (Math.random() - 0.5) * 4,
        vy: (Math.random() - 0.5) * 4,
        hp: 5,
        maxHp: 5,
        size: 25,
        lastDamaged: 0
      });
    }
  }
  
  private shoot(): void {
    const now = Date.now();
    if (now - this.lastShot < 300) return; // Rate limit
    
    if (!this.currentPlayerId) return;
    const player = this.players[this.currentPlayerId];
    if (!player) return;
    
    // Find nearest alien
    let nearest: Alien | null = null;
    let nearestDist = Infinity;
    
    this.aliens.forEach((alien: Alien) => {
      const dist = Math.sqrt((alien.x - player.x) ** 2 + (alien.y - player.y) ** 2);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = alien;
      }
    });
    
    if (nearest !== null && nearestDist < 500) {
      this.bullets.push({
        x: player.x,
        y: player.y,
        targetX: nearest.x,
        targetY: nearest.y,
        speed: 10,
        created: now
      });
      this.lastShot = now;
    }
  }
  
  private handleMovement(): void {
    if (this.isTyping) return;
    
    if (!this.currentPlayerId) return;
    const player = this.players[this.currentPlayerId];
    if (!player) return;
    
    let newX = player.x;
    let newY = player.y;
    const speed = 5;
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
      // Update local position immediately for smooth movement
      this.players[this.currentPlayerId].x = newX;
      this.players[this.currentPlayerId].y = newY;
      
      // Throttle server updates to reduce log spam
      const now = Date.now();
      if (now - this.lastMoveUpdate > this.moveUpdateDelay) {
        this.hook.pushEvent('move_player', { x: Math.floor(newX), y: Math.floor(newY) });
        this.lastMoveUpdate = now;
      }
    }
  }
  
  private updateGame(): void {
    const now = Date.now();
    
    // Update aliens
    this.aliens.forEach((alien: Alien) => {
      alien.x += alien.vx;
      alien.y += alien.vy;
      
      // Bounce off walls
      if (alien.x <= alien.size || alien.x >= this.canvas.width - alien.size) {
        alien.vx *= -1;
        alien.x = Math.max(alien.size, Math.min(this.canvas.width - alien.size, alien.x));
      }
      if (alien.y <= alien.size || alien.y >= this.canvas.height - alien.size) {
        alien.vy *= -1;
        alien.y = Math.max(alien.size, Math.min(this.canvas.height - alien.size, alien.y));
      }
    });
    
    // Update bullets
    this.bullets = this.bullets.filter((bullet: Bullet) => {
      const dx = bullet.targetX - bullet.x;
      const dy = bullet.targetY - bullet.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      
      if (dist < bullet.speed) {
        // Hit target - damage aliens
        this.aliens.forEach((alien: Alien) => {
          const alienDist = Math.sqrt((alien.x - bullet.targetX) ** 2 + (alien.y - bullet.targetY) ** 2);
          if (alienDist < alien.size) {
            alien.hp -= 1;
            alien.lastDamaged = now;
          }
        });
        return false; // Remove bullet
      }
      
      // Move bullet
      bullet.x += (dx / dist) * bullet.speed;
      bullet.y += (dy / dist) * bullet.speed;
      
      return now - bullet.created < 3000; // Remove old bullets
    });
    
    // Remove dead aliens and spawn new ones
    this.aliens = this.aliens.filter((alien: Alien) => alien.hp > 0);
    while (this.aliens.length < 5) {
      this.aliens.push({
        id: Math.random(),
        x: Math.random() * (this.canvas.width - 100) + 50,
        y: Math.random() * (this.canvas.height - 100) + 50,
        vx: (Math.random() - 0.5) * 4,
        vy: (Math.random() - 0.5) * 4,
        hp: 5,
        maxHp: 5,
        size: 25,
        lastDamaged: 0
      });
    }
  }
  
  private render(): void {
    // Clear
    this.ctx.fillStyle = '#000011';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw stars
    this.ctx.fillStyle = '#ffffff';
    for (let i = 0; i < 100; i++) {
      const x = (i * 137.5) % this.canvas.width;
      const y = (i * 73.3) % this.canvas.height;
      this.ctx.fillRect(x, y, 2, 2);
    }
    
    // Draw aliens
    this.aliens.forEach((alien: Alien) => {
      const now = Date.now();
      const damaged = now - alien.lastDamaged < 200;
      
      this.ctx.fillStyle = damaged ? '#ff6666' : '#666666';
      this.ctx.beginPath();
      this.ctx.ellipse(alien.x, alien.y, alien.size, alien.size * 0.4, 0, 0, Math.PI * 2);
      this.ctx.fill();
      
      // HP bar
      const barWidth = alien.size * 2;
      const barHeight = 4;
      const barX = alien.x - barWidth / 2;
      const barY = alien.y - alien.size - 10;
      
      this.ctx.fillStyle = '#333333';
      this.ctx.fillRect(barX, barY, barWidth, barHeight);
      
      const hpPercent = alien.hp / alien.maxHp;
      this.ctx.fillStyle = hpPercent > 0.5 ? '#00ff00' : '#ff0000';
      this.ctx.fillRect(barX, barY, barWidth * hpPercent, barHeight);
    });
    
    // Draw bullets
    this.ctx.fillStyle = '#ffff00';
    this.bullets.forEach((bullet: Bullet) => {
      this.ctx.beginPath();
      this.ctx.arc(bullet.x, bullet.y, 3, 0, Math.PI * 2);
      this.ctx.fill();
    });
    
    // Draw players
    Object.values(this.players).forEach((player: Player) => {
      const isMe = player.id === this.currentPlayerId;
      const radius = isMe ? 12 : 10;
      
      this.ctx.fillStyle = player.color || '#3B82F6';
      this.ctx.beginPath();
      this.ctx.arc(player.x, player.y, radius, 0, Math.PI * 2);
      this.ctx.fill();
      
      if (isMe) {
        this.ctx.strokeStyle = '#ffff00';
        this.ctx.lineWidth = 3;
        this.ctx.stroke();
      }
      
      // Name
      this.ctx.fillStyle = '#ffffff';
      this.ctx.font = '14px Arial';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(player.name || 'Player', player.x, player.y - radius - 5);
      
      // Chat message
      if (player.message && player.message_time) {
        const timeSince = Date.now() - player.message_time;
        if (timeSince < 5000) {
          this.ctx.fillStyle = 'rgba(0,0,0,0.8)';
          this.ctx.fillRect(player.x - 60, player.y - radius - 40, 120, 20);
          this.ctx.fillStyle = '#ffffff';
          this.ctx.font = '12px Arial';
          this.ctx.fillText(player.message, player.x, player.y - radius - 25);
        }
      }
    });
  }
  
  public updatePlayers(players: Record<string, Player>): void {
    this.players = players;
  }
  
  public setCurrentPlayer(playerId: string): void {
    this.currentPlayerId = playerId;
  }
  
  private gameLoop(): void {
    this.handleMovement();
    this.updateGame();
    this.render();
    requestAnimationFrame(() => this.gameLoop());
  }
}

// Make QuestEngine available globally for legacy compatibility
declare global {
  interface Window {
    QuestEngine: typeof QuestEngine;
  }
}

window.QuestEngine = QuestEngine;

export default QuestEngine;