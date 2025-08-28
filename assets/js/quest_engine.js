// Simple Quest Engine - Full Screen Movable Avatars with Chat Bubbles
class QuestEngine {
  constructor(canvas, socket) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.socket = socket;
    this.players = {};
    this.currentPlayerId = null;
    this.keys = {};
    
    // Make canvas full screen
    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());
    
    this.setupEventListeners();
    this.gameLoop();
  }
  
  resizeCanvas() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.canvas.style.position = 'fixed';
    this.canvas.style.top = '0';
    this.canvas.style.left = '0';
    this.canvas.style.zIndex = '1';
  }
  
  setupEventListeners() {
    // Keyboard controls
    document.addEventListener('keydown', (e) => {
      this.keys[e.code] = true;
      
      if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight'].includes(e.code)) {
        e.preventDefault();
        this.handleMovement();
      }
    });
    
    document.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
    });
    
    // Mouse/touch controls
    this.canvas.addEventListener('click', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      if (this.currentPlayerId && this.players[this.currentPlayerId]) {
        this.socket.pushEvent('move_player', { x: x, y: y });
      }
    });
  }
  
  handleMovement() {
    const player = this.players[this.currentPlayerId];
    if (!player) return;
    
    let newX = player.x;
    let newY = player.y;
    const speed = 5;
    
    if (this.keys['KeyA'] || this.keys['ArrowLeft']) {
      newX -= speed;
    }
    if (this.keys['KeyD'] || this.keys['ArrowRight']) {
      newX += speed;
    }
    if (this.keys['KeyW'] || this.keys['ArrowUp']) {
      newY -= speed;
    }
    if (this.keys['KeyS'] || this.keys['ArrowDown']) {
      newY += speed;
    }
    
    // Keep within bounds
    newX = Math.max(30, Math.min(this.canvas.width - 30, newX));
    newY = Math.max(30, Math.min(this.canvas.height - 30, newY));
    
    if (newX !== player.x || newY !== player.y) {
      this.socket.pushEvent('move_player', { x: newX, y: newY });
    }
  }
  
  updatePlayers(players) {
    this.players = players;
  }
  
  setCurrentPlayer(playerId) {
    this.currentPlayerId = playerId;
  }
  
  render() {
    // Clear canvas with dark background
    this.ctx.fillStyle = '#0f172a';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw grid pattern
    this.drawGrid();
    
    // Draw all players
    Object.values(this.players).forEach(player => {
      this.drawPlayer(player);
    });
    
    // Draw instructions
    this.drawInstructions();
  }
  
  drawGrid() {
    this.ctx.strokeStyle = '#1e293b';
    this.ctx.lineWidth = 1;
    
    const gridSize = 50;
    
    // Vertical lines
    for (let x = 0; x < this.canvas.width; x += gridSize) {
      this.ctx.beginPath();
      this.ctx.moveTo(x, 0);
      this.ctx.lineTo(x, this.canvas.height);
      this.ctx.stroke();
    }
    
    // Horizontal lines
    for (let y = 0; y < this.canvas.height; y += gridSize) {
      this.ctx.beginPath();
      this.ctx.moveTo(0, y);
      this.ctx.lineTo(this.canvas.width, y);
      this.ctx.stroke();
    }
  }
  
  drawPlayer(player) {
    const x = player.x || 100;
    const y = player.y || 100;
    const isCurrentPlayer = player.id === this.currentPlayerId;
    const radius = isCurrentPlayer ? 25 : 20;
    
    // Draw player circle
    this.ctx.fillStyle = player.color || '#3B82F6';
    this.ctx.beginPath();
    this.ctx.arc(x, y, radius, 0, Math.PI * 2);
    this.ctx.fill();
    
    // Draw border for current player
    if (isCurrentPlayer) {
      this.ctx.strokeStyle = '#fbbf24';
      this.ctx.lineWidth = 3;
      this.ctx.stroke();
    }
    
    // Draw avatar if available
    if (player.avatar_url) {
      // TODO: Load and draw avatar image
    }
    
    // Draw simple face
    this.ctx.fillStyle = 'white';
    // Eyes
    this.ctx.beginPath();
    this.ctx.arc(x - 7, y - 5, 3, 0, Math.PI * 2);
    this.ctx.arc(x + 7, y - 5, 3, 0, Math.PI * 2);
    this.ctx.fill();
    
    // Smile
    this.ctx.strokeStyle = 'white';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    this.ctx.arc(x, y + 3, 8, 0, Math.PI);
    this.ctx.stroke();
    
    // Draw player name
    this.ctx.fillStyle = 'white';
    this.ctx.font = 'bold 14px Arial';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(player.name || 'Player', x, y - radius - 10);
    
    // Draw chat bubble if player has a message
    if (player.message && player.message_time) {
      const timeSince = Date.now() - player.message_time;
      if (timeSince < 8000) { // Show for 8 seconds
        this.drawChatBubble(x, y - radius - 30, player.message);
      }
    }
  }
  
  drawChatBubble(x, y, message) {
    const padding = 12;
    const maxWidth = 200;
    
    // Measure text
    this.ctx.font = '14px Arial';
    const words = message.split(' ');
    const lines = [];
    let currentLine = '';
    
    words.forEach(word => {
      const testLine = currentLine + (currentLine ? ' ' : '') + word;
      const metrics = this.ctx.measureText(testLine);
      
      if (metrics.width > maxWidth && currentLine) {
        lines.push(currentLine);
        currentLine = word;
      } else {
        currentLine = testLine;
      }
    });
    
    if (currentLine) {
      lines.push(currentLine);
    }
    
    const lineHeight = 18;
    const bubbleWidth = Math.min(maxWidth + padding * 2, Math.max(...lines.map(line => this.ctx.measureText(line).width)) + padding * 2);
    const bubbleHeight = lines.length * lineHeight + padding * 2;
    
    // Draw bubble background
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
    this.ctx.fillRect(x - bubbleWidth / 2, y - bubbleHeight, bubbleWidth, bubbleHeight);
    
    // Draw bubble border
    this.ctx.strokeStyle = '#fbbf24';
    this.ctx.lineWidth = 2;
    this.ctx.strokeRect(x - bubbleWidth / 2, y - bubbleHeight, bubbleWidth, bubbleHeight);
    
    // Draw bubble tail
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
    this.ctx.beginPath();
    this.ctx.moveTo(x - 8, y);
    this.ctx.lineTo(x + 8, y);
    this.ctx.lineTo(x, y - 15);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.stroke();
    
    // Draw text
    this.ctx.fillStyle = 'white';
    this.ctx.textAlign = 'center';
    this.ctx.font = '14px Arial';
    lines.forEach((line, index) => {
      this.ctx.fillText(line, x, y - bubbleHeight + padding + (index + 1) * lineHeight - 2);
    });
  }
  
  drawInstructions() {
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    this.ctx.fillRect(10, 10, 300, 120);
    
    this.ctx.strokeStyle = '#fbbf24';
    this.ctx.lineWidth = 2;
    this.ctx.strokeRect(10, 10, 300, 120);
    
    this.ctx.fillStyle = 'white';
    this.ctx.font = 'bold 16px Arial';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('Quest Controls:', 20, 35);
    
    this.ctx.font = '14px Arial';
    this.ctx.fillText('• WASD or Arrow Keys: Move around', 20, 55);
    this.ctx.fillText('• Click anywhere: Move to that spot', 20, 75);
    this.ctx.fillText('• Type message below: Chat bubble appears', 20, 95);
    this.ctx.fillText('• Golden border = You', 20, 115);
  }
  
  gameLoop() {
    this.render();
    requestAnimationFrame(() => this.gameLoop());
  }
}

// Make QuestEngine globally available
window.QuestEngine = QuestEngine;