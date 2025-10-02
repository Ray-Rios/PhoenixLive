// MMO-focused TypeScript interfaces for your Phoenix app
// These types will help you with API integration and player management

// User data structure from your Phoenix schema
export interface User {
  id: number;
  email: string;
  name?: string;
  username?: string;
  avatar_url?: string;
  is_verified: boolean;
  created_at: string;
  updated_at: string;
  
  // MMO Stats (add your actual schema fields here)
  level?: number;
  experience?: number;
  health?: number;
  max_health?: number;
  mana?: number;
  max_mana?: number;
  strength?: number;
  agility?: number;
  intelligence?: number;
  constitution?: number;
  
  // Location & World State
  current_zone_id?: number;
  position_x?: number;
  position_y?: number;
  position_z?: number;
  rotation_y?: number;
  
  // Player Status
  is_online?: boolean;
  last_seen?: string;
  current_activity?: string;
}

// API Response wrapper
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  errors?: Record<string, string[]>;
}

// Player Stats for UI and game logic
export interface PlayerStats {
  level: number;
  experience: number;
  experience_to_next: number;
  health: number;
  max_health: number;
  mana: number;
  max_mana: number;
  strength: number;
  agility: number;
  intelligence: number;
  constitution: number;
}

// World/Zone information
export interface Zone {
  id: number;
  name: string;
  description?: string;
  level_range: [number, number];
  max_players: number;
  current_player_count: number;
  is_pvp: boolean;
  background_music?: string;
  environment_settings: {
    fog_density: number;
    lighting_intensity: number;
    water_level: number;
    gravity: number;
  };
}

// Real-time player position for MMO
export interface PlayerPosition {
  user_id: number;
  zone_id: number;
  x: number;
  y: number;
  z: number;
  rotation_y: number;
  timestamp: string;
  is_moving: boolean;
  current_animation?: string;
}

// Chat system
export interface ChatMessage {
  id?: number;
  user_id: number;
  username: string;
  message: string;
  message_type: 'global' | 'zone' | 'whisper' | 'guild' | 'system';
  zone_id?: number;
  target_user_id?: number; // for whispers
  timestamp: string;
  is_system: boolean;
}

// Real-time events from Phoenix
export interface RealtimeEvents {
  // Player events
  'player_joined': { user: User; zone_id: number };
  'player_left': { user_id: number; username: string; zone_id: number };
  'player_moved': PlayerPosition;
  'player_stats_updated': { user_id: number; stats: Partial<PlayerStats> };
  
  // Chat events
  'chat_message': ChatMessage;
  'whisper_received': ChatMessage;
  
  // World events
  'zone_changed': { user_id: number; from_zone: number; to_zone: number };
  'world_event': { event_type: string; data: any };
}

// Phoenix LiveView Hook interface
export interface PhoenixHook {
  el: HTMLElement;
  pushEvent(event: string, payload: any): void;
  handleEvent(event: string, callback: (data: any) => void): void;
  
  // Hook lifecycle
  mounted?(): void;
  updated?(): void;
  destroyed?(): void;
  disconnected?(): void;
  reconnected?(): void;
}

// Game state management
export interface GameState {
  currentUser: User;
  currentZone: Zone;
  nearbyPlayers: Map<number, PlayerPosition>;
  playerStats: PlayerStats;
  chatHistory: ChatMessage[];
  isLoading: boolean;
  connectionStatus: 'connected' | 'disconnected' | 'reconnecting';
}

// API endpoints you'll need for MMO features
export interface MMOApiClient {
  // Player management
  getPlayerStats(userId: number): Promise<ApiResponse<PlayerStats>>;
  updatePlayerPosition(position: PlayerPosition): Promise<ApiResponse<void>>;
  updatePlayerStats(userId: number, stats: Partial<PlayerStats>): Promise<ApiResponse<PlayerStats>>;
  
  // Zone management
  getZoneInfo(zoneId: number): Promise<ApiResponse<Zone>>;
  getPlayersInZone(zoneId: number): Promise<ApiResponse<PlayerPosition[]>>;
  changeZone(userId: number, newZoneId: number): Promise<ApiResponse<Zone>>;
  
  // Chat
  sendChatMessage(message: Omit<ChatMessage, 'id' | 'timestamp'>): Promise<ApiResponse<ChatMessage>>;
  getChatHistory(zoneId: number, limit?: number): Promise<ApiResponse<ChatMessage[]>>;
  
  // Social features (for later)
  sendFriendRequest(targetUserId: number): Promise<ApiResponse<void>>;
  getOnlineFriends(): Promise<ApiResponse<User[]>>;
}

// Utility type for Phoenix channel events
export type ChannelEvent<T extends keyof RealtimeEvents> = {
  event: T;
  payload: RealtimeEvents[T];
};

// Configuration from Phoenix
export interface GameConfig {
  user: User;
  zone: Zone;
  api_base_url: string;
  websocket_url: string;
  debug_mode: boolean;
  features: {
    chat_enabled: boolean;
    pvp_enabled: boolean;
    guilds_enabled: boolean;
    trading_enabled: boolean;
  };
}