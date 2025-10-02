// MMO Client - TypeScript utility for handling your MMO features
// This works with your existing Babylon.js JavaScript code

import type { 
  User, 
  ApiResponse, 
  PlayerStats, 
  Zone, 
  PlayerPosition, 
  ChatMessage, 
  RealtimeEvents, 
  PhoenixHook, 
  GameState,
  GameConfig
} from './mmo-types';

export class MMOClient {
  private config: GameConfig;
  private gameState: GameState;
  private phoenixHook: PhoenixHook;
  private positionUpdateInterval?: number;

  constructor(hook: PhoenixHook, config: GameConfig) {
    this.phoenixHook = hook;
    this.config = config;
    
    this.gameState = {
      currentUser: config.user,
      currentZone: config.zone,
      nearbyPlayers: new Map(),
      playerStats: this.initializeDefaultStats(),
      chatHistory: [],
      isLoading: false,
      connectionStatus: 'connected'
    };

    this.setupEventListeners();
    this.startPositionSync();
  }

  // Initialize default player stats
  private initializeDefaultStats(): PlayerStats {
    const user = this.config.user;
    return {
      level: user.level || 1,
      experience: user.experience || 0,
      experience_to_next: this.calculateExpToNext(user.level || 1),
      health: user.health || 100,
      max_health: user.max_health || 100,
      mana: user.mana || 50,
      max_mana: user.max_mana || 50,
      strength: user.strength || 10,
      agility: user.agility || 10,
      intelligence: user.intelligence || 10,
      constitution: user.constitution || 10
    };
  }

  private calculateExpToNext(level: number): number {
    // Simple exp formula - customize as needed
    return level * 1000;
  }

  // Set up Phoenix LiveView event listeners
  private setupEventListeners(): void {
    // Player events
    this.phoenixHook.handleEvent('player_joined', (data: RealtimeEvents['player_joined']) => {
      console.log(`${data.user.username} joined the zone`);
      this.addChatMessage('SYSTEM', `${data.user.username} joined the world`, 'system');
    });

    this.phoenixHook.handleEvent('player_left', (data: RealtimeEvents['player_left']) => {
      console.log(`${data.username} left the zone`);
      this.gameState.nearbyPlayers.delete(data.user_id);
      this.addChatMessage('SYSTEM', `${data.username} left the world`, 'system');
    });

    this.phoenixHook.handleEvent('player_moved', (data: RealtimeEvents['player_moved']) => {
      this.updatePlayerPosition(data);
    });

    this.phoenixHook.handleEvent('player_stats_updated', (data: RealtimeEvents['player_stats_updated']) => {
      if (data.user_id === this.config.user.id) {
        this.updateLocalStats(data.stats);
      }
    });

    // Chat events
    this.phoenixHook.handleEvent('chat_message', (data: RealtimeEvents['chat_message']) => {
      this.addChatMessage(data.username, data.message, data.message_type);
    });

    this.phoenixHook.handleEvent('whisper_received', (data: RealtimeEvents['whisper_received']) => {
      this.addChatMessage(`[WHISPER] ${data.username}`, data.message, 'whisper');
    });

    // Zone events
    this.phoenixHook.handleEvent('zone_changed', (data: RealtimeEvents['zone_changed']) => {
      if (data.user_id === this.config.user.id) {
        this.handleZoneChange(data.to_zone);
      }
    });
  }

  // Send chat message
  public sendChatMessage(message: string, messageType: ChatMessage['message_type'] = 'global'): void {
    const chatData: Omit<ChatMessage, 'id' | 'timestamp'> = {
      user_id: this.config.user.id,
      username: this.config.user.username || this.config.user.name || 'Player',
      message: message,
      message_type: messageType,
      zone_id: this.config.zone.id,
      is_system: false
    };

    this.phoenixHook.pushEvent('chat_message', chatData);
  }

  // Add message to chat UI
  private addChatMessage(username: string, message: string, type: string): void {
    const chatMessage: ChatMessage = {
      user_id: 0, // Will be set by server
      username,
      message,
      message_type: type as ChatMessage['message_type'],
      timestamp: new Date().toISOString(),
      is_system: type === 'system'
    };

    this.gameState.chatHistory.push(chatMessage);
    
    // Keep only last 100 messages
    if (this.gameState.chatHistory.length > 100) {
      this.gameState.chatHistory.shift();
    }

    // Update UI (integrate with your existing chat UI)
    this.updateChatUI(chatMessage);
  }

  // Update chat UI (integrate with your Babylon scene's chat system)
  private updateChatUI(message: ChatMessage): void {
    const messagesArea = document.getElementById('chat-messages-area');
    if (!messagesArea) return;

    const messageEl = document.createElement('div');
    messageEl.style.cssText = 'margin-bottom:5px;word-wrap:break-word;';
    
    const timestamp = new Date(message.timestamp).toLocaleTimeString();
    const color = this.getMessageColor(message.message_type);
    
    messageEl.innerHTML = `
      <span style="color:#888">[${timestamp}]</span> 
      <strong style="color:${color}">${message.username}:</strong> 
      <span style="color:${color}">${message.message}</span>
    `;
    
    messagesArea.appendChild(messageEl);
    messagesArea.scrollTop = messagesArea.scrollHeight;

    // Remove old messages
    while (messagesArea.children.length > 50) {
      const firstChild = messagesArea.firstChild;
      if (firstChild) {
        messagesArea.removeChild(firstChild);
      }
    }
  }

  private getMessageColor(type: string): string {
    switch (type) {
      case 'system': return '#ffff00';
      case 'whisper': return '#ff69b4';
      case 'guild': return '#00ff00';
      case 'global': return '#00ffff';
      default: return '#ffffff';
    }
  }

  // Update player position
  public updatePosition(x: number, y: number, z: number, rotationY: number, isMoving: boolean = false): void {
    const position: PlayerPosition = {
      user_id: this.config.user.id,
      zone_id: this.config.zone.id,
      x,
      y,
      z,
      rotation_y: rotationY,
      timestamp: new Date().toISOString(),
      is_moving: isMoving
    };

    // Send to server (throttled)
    this.throttledPositionUpdate(position);
  }

  private lastPositionUpdate = 0;
  private throttledPositionUpdate(position: PlayerPosition): void {
    const now = Date.now();
    if (now - this.lastPositionUpdate > 100) { // Max 10 updates per second
      this.phoenixHook.pushEvent('player_moved', position);
      this.lastPositionUpdate = now;
    }
  }

  // Handle other player position updates
  private updatePlayerPosition(data: PlayerPosition): void {
    if (data.user_id === this.config.user.id) return; // Don't update our own position
    
    this.gameState.nearbyPlayers.set(data.user_id, data);
    
    // TODO: Update the player's mesh in your Babylon scene
    // You can call a method on your existing Babylon scene here
    console.log(`Player ${data.user_id} moved to ${data.x}, ${data.y}, ${data.z}`);
  }

  // Update local player stats
  public updateLocalStats(newStats: Partial<PlayerStats>): void {
    this.gameState.playerStats = { ...this.gameState.playerStats, ...newStats };
    
    // Push to server
    this.phoenixHook.pushEvent('player_stats_updated', {
      user_id: this.config.user.id,
      stats: newStats
    });

    // Update UI
    this.updateStatsUI();
  }

  // Update stats UI (you can integrate this with your game UI)
  private updateStatsUI(): void {
    const stats = this.gameState.playerStats;
    
    // Update health bar
    const healthBar = document.getElementById('health-bar');
    if (healthBar) {
      const percentage = (stats.health / stats.max_health) * 100;
      healthBar.style.width = `${percentage}%`;
    }

    // Update mana bar
    const manaBar = document.getElementById('mana-bar');
    if (manaBar) {
      const percentage = (stats.mana / stats.max_mana) * 100;
      manaBar.style.width = `${percentage}%`;
    }

    // Update level display
    const levelDisplay = document.getElementById('player-level');
    if (levelDisplay) {
      levelDisplay.textContent = `Level ${stats.level}`;
    }
  }

  // Handle zone changes
  private async handleZoneChange(newZoneId: number): Promise<void> {
    this.gameState.isLoading = true;
    
    try {
      // Fetch new zone info
      const response = await this.apiCall<Zone>(`/api/zones/${newZoneId}`);
      if (response.success && response.data) {
        this.gameState.currentZone = response.data;
        this.gameState.nearbyPlayers.clear();
        
        console.log(`Entered zone: ${response.data.name}`);
        this.addChatMessage('SYSTEM', `Entered ${response.data.name}`, 'system');
      }
    } catch (error) {
      console.error('Failed to load zone:', error);
    } finally {
      this.gameState.isLoading = false;
    }
  }

  // API call helper
  private async apiCall<T>(endpoint: string, options: RequestInit = {}): Promise<ApiResponse<T>> {
    try {
      const response = await fetch(`${this.config.api_base_url}${endpoint}`, {
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken(),
          ...options.headers
        },
        ...options
      });

      return await response.json();
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    return token || '';
  }

  // Start periodic position sync
  private startPositionSync(): void {
    this.positionUpdateInterval = window.setInterval(() => {
      // This would integrate with your Babylon scene to get current position
      // For now, just a placeholder
    }, 1000);
  }

  // Cleanup
  public destroy(): void {
    if (this.positionUpdateInterval) {
      clearInterval(this.positionUpdateInterval);
    }
  }

  // Getters for accessing game state
  public get currentUser(): User { return this.gameState.currentUser; }
  public get currentZone(): Zone { return this.gameState.currentZone; }
  public get playerStats(): PlayerStats { return this.gameState.playerStats; }
  public get nearbyPlayers(): Map<number, PlayerPosition> { return this.gameState.nearbyPlayers; }
  public get isLoading(): boolean { return this.gameState.isLoading; }
}

// Export helper function to create MMO client
export function createMMOClient(hook: PhoenixHook, config: GameConfig): MMOClient {
  return new MMOClient(hook, config);
}