// TypeScript Babylon.js imports for k3s deployment
// Use dynamic imports to load @babylonjs packages when needed

// MMO-specific TypeScript interfaces
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
}

export interface ChatMessage {
  user_id: number;
  username: string;
  message: string;
  timestamp: string;
  message_type: 'global' | 'system' | 'whisper';
}

export interface PlayerPosition {
  user_id: number;
  x: number;
  y: number;
  z: number;
  rotation_y: number;
  is_moving: boolean;
}

export interface PhoenixLiveViewHook {
  el: HTMLCanvasElement;
  pushEvent: (event: string, payload: any) => void;
  handleEvent: (event: string, callback: (data: any) => void) => void;
  mounted(): void;
  updated?(): void;
  destroyed?(): void;
}

export interface MovementKeys {
  [key: string]: boolean;
  w: boolean;
  a: boolean;
  s: boolean;
  d: boolean;
  ' ': boolean;
}

export interface MouseMovement {
  leftMouseDown: boolean;
  rightMouseDown: boolean;
  isMovingForward: boolean;
  inRightClickMode: boolean;
  moveStartTime: number;
}

// Babylon.js helper functions
export const getBabylon = () => {
  if (typeof BABYLON === 'undefined') {
    throw new Error('BABYLON is not loaded');
  }
  return BABYLON;
};

export const createEngine = (canvas: HTMLCanvasElement, antialias = true) => {
  const B = getBabylon();
  return new B.Engine(canvas, antialias);
};

export const createScene = (engine: any) => {
  const B = getBabylon();
  return new B.Scene(engine);
};

export const createVector3 = (x: number, y: number, z: number) => {
  const B = getBabylon();
  return new B.Vector3(x, y, z);
};

// Dynamic imports for Babylon.js classes - these load when first used
let babylonClasses: any = null;

const loadBabylonClasses = async () => {
  if (babylonClasses) return babylonClasses;
  
  try {
    // Use the same import pattern as in loadMikuModel
    const { Engine } = await import('@babylonjs/core/Engines/engine');
    const { Scene } = await import('@babylonjs/core/scene');
    const { Vector3, Vector2 } = await import('@babylonjs/core/Maths/math.vector');
    const { Color3, Color4 } = await import('@babylonjs/core/Maths/math.color');
    const { Ray } = await import('@babylonjs/core/Culling/ray');
    const { FreeCamera } = await import('@babylonjs/core/Cameras/freeCamera');
    const { ArcRotateCamera } = await import('@babylonjs/core/Cameras/arcRotateCamera');
    const { UniversalCamera } = await import('@babylonjs/core/Cameras/universalCamera');
    const { HemisphericLight } = await import('@babylonjs/core/Lights/hemisphericLight');
    const { DirectionalLight } = await import('@babylonjs/core/Lights/directionalLight');
    const { MeshBuilder } = await import('@babylonjs/core/Meshes/meshBuilder');
    const { StandardMaterial } = await import('@babylonjs/core/Materials/standardMaterial');
    const { PBRMaterial } = await import('@babylonjs/core/Materials/PBR/pbrMaterial');
    const { Animation } = await import('@babylonjs/core/Animations/animation');
    const { AnimationGroup } = await import('@babylonjs/core/Animations/animationGroup');
    const { ActionManager } = await import('@babylonjs/core/Actions/actionManager');
    const { ExecuteCodeAction } = await import('@babylonjs/core/Actions/directActions');

    babylonClasses = {
      Engine, Scene, Vector3, Vector2, Color3, Color4, Ray,
      FreeCamera, ArcRotateCamera, UniversalCamera,
      HemisphericLight, DirectionalLight,
      MeshBuilder, StandardMaterial, PBRMaterial,
      Animation, AnimationGroup, ActionManager, ExecuteCodeAction
    };
    
    return babylonClasses;
  } catch (error) {
    console.error('Failed to load Babylon.js classes:', error);
    throw new Error('Failed to load Babylon.js modules');
  }
};

// Export all Babylon.js classes - these will be loaded dynamically
export let Engine: any, Scene: any, Vector3: any, Vector2: any, Color3: any, Color4: any, Ray: any;
export let FreeCamera: any, ArcRotateCamera: any, UniversalCamera: any;
export let HemisphericLight: any, DirectionalLight: any;
export let MeshBuilder: any, StandardMaterial: any, PBRMaterial: any;
export let Animation: any, AnimationGroup: any;
export let ActionManager: any, ExecuteCodeAction: any;

// Initialize exports when BABYLON is available
export const initializeBabylonExports = async () => {
  const classes = await loadBabylonClasses();
  
  Engine = classes.Engine;
  Scene = classes.Scene;
  Vector3 = classes.Vector3;
  Vector2 = classes.Vector2;
  Color3 = classes.Color3;
  Color4 = classes.Color4;
  Ray = classes.Ray;
  FreeCamera = classes.FreeCamera;
  ArcRotateCamera = classes.ArcRotateCamera;
  UniversalCamera = classes.UniversalCamera;
  HemisphericLight = classes.HemisphericLight;
  DirectionalLight = classes.DirectionalLight;
  MeshBuilder = classes.MeshBuilder;
  StandardMaterial = classes.StandardMaterial;
  PBRMaterial = classes.PBRMaterial;
  Animation = classes.Animation;
  AnimationGroup = classes.AnimationGroup;
  ActionManager = classes.ActionManager;
  ExecuteCodeAction = classes.ExecuteCodeAction;
};