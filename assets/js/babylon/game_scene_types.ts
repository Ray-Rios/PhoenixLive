// Enhanced TypeScript interfaces for the game system
import type { CharacterType } from './character_model_manager';

// Global window extensions
declare global {
  interface Window {
    __lobbyMetrics?: {
      mounts: number;
      updates: number;
    };
  }
}

// Phoenix LiveView Hook interface
export interface PhoenixLiveViewHook {
  el: HTMLCanvasElement;
  pushEvent: (event: string, payload: any) => void;
  handleEvent: (event: string, callback: (data: any) => void) => void;
  mounted(): void;
  updated?(): void;
  destroyed?(): void;
}

// Babylon.js type imports (using any for compatibility until proper types are available)
export type BabylonEngine = any;
export type BabylonScene = any;
export type BabylonMesh = any;
export type BabylonCamera = any;
export type BabylonVector3 = any;
export type BabylonAnimationGroup = any;
export type BabylonMaterial = any;

// Game state interfaces
export interface GameSceneConfig {
  environment?: {
    fogDensity?: number;
    lightingIntensity?: number;
    waterLevel?: number;
    gravity?: number;
  };
  world?: {
    size?: number;
    islandRadius?: number;
    waterSize?: number;
  };
}

export interface UserData {
  id: number;
  name?: string;
  username?: string;
  email?: string;
  level?: number;
  experience?: number;
  health?: number;
  mana?: number;
  position_x?: number;
  position_y?: number;
  position_z?: number;
  rotation_y?: number;
  character_type?: CharacterType;
}

export interface MovementKeys {
  [key: string]: boolean;
  w: boolean;
  a: boolean;
  s: boolean;
  d: boolean;
  ' ': boolean; // spacebar
  b: boolean; // build mode toggle
}

export interface MouseMovement {
  leftMouseDown: boolean;
  rightMouseDown: boolean;
  isMovingForward: boolean;
  inRightClickMode: boolean;
  moveStartTime: number;
}

export interface ChatUIElements {
  chatContainer: HTMLDivElement;
  messagesArea: HTMLDivElement;
  chatInput: HTMLInputElement;
}

// Character system interfaces
export interface CharacterModel {
  name: string;
  mesh: BabylonMesh;
  animationGroups: BabylonAnimationGroup[];
  type: CharacterType;
  scale: { x: number; y: number; z: number };
  boundingInfo?: any;
}

export interface CharacterBehavior {
  updateMovement(input: any, deltaTime: number): void;
  getCurrentAnimationState(): string;
  canPerformAction(action: string): boolean;
  getMovementState(): any;
}

// Scene state interface
export interface GameSceneState {
  // Babylon.js objects
  engine?: BabylonEngine;
  scene?: BabylonScene;
  camera?: BabylonCamera;
  player?: BabylonMesh;
  terrain?: BabylonMesh;
  water?: BabylonMesh;
  
  // Character system
  characterModelManager?: any;
  characterModel?: CharacterModel;
  characterConfig?: any;
  characterBehavior?: CharacterBehavior;
  playerAnimations?: BabylonAnimationGroup[];
  
  // World building
  materialLibrary?: any;
  worldBuilderTools?: any;
  startingIsland?: BabylonMesh;
  
  // Movement and input
  keys: MovementKeys;
  mouseMovement: MouseMovement;
  moveSpeed: number;
  isInWater: boolean;
  isJumping: boolean;
  jumpVelocity: number;
  
  // Event handlers
  keyDownHandler?: (e: KeyboardEvent) => void;
  keyUpHandler?: (e: KeyboardEvent) => void;
  
  // UI elements
  chatContainer?: HTMLDivElement;
  messagesArea?: HTMLDivElement;
  chatInput?: HTMLInputElement;
  
  // Configuration and data
  sceneConfig: GameSceneConfig;
  userData: UserData;
  _lastDataset?: DOMStringMap;
}

// Event data interfaces
export interface ChatMessageData {
  username: string;
  message: string;
  user_id?: number;
}

export interface UserJoinedData {
  username: string;
  user_id: number;
}

export interface UserLeftData {
  username: string;
  user_id: number;
}