// OpenWorldLobbyScene - Proper TypeScript Class Implementation
import { 
  Engine, Scene, Vector3, Color3, Ray, ArcRotateCamera, HemisphericLight,
  DirectionalLight, MeshBuilder, StandardMaterial, ActionManager, SceneLoader,
  initializeBabylonExports, TransformNode
} from './babylon_imports';
import { MaterialLibrary, WorldBuilderTools } from './world-builder-tools';
import { CharacterModelManager } from './character_model_manager';
import type { 
  PhoenixLiveViewHook, GameSceneState, MovementKeys, MouseMovement,
  GameSceneConfig, UserData, ChatMessageData, UserJoinedData, UserLeftData,
  BabylonEngine, BabylonScene, BabylonMesh, BabylonCamera
} from './game_scene_types';

export class OpenWorldLobbyScene implements PhoenixLiveViewHook {
  public el!: HTMLCanvasElement;
  
  // Core Babylon.js objects
  private engine?: BabylonEngine;
  private scene?: BabylonScene;
  private camera?: BabylonCamera;
  private player?: BabylonMesh;
  private terrain?: BabylonMesh;
  private water?: BabylonMesh;
  
  // Character system
  private characterModelManager?: CharacterModelManager;
  private characterModel?: any;
  private characterConfig?: any;
  private characterBehavior?: any;
  private playerAnimations?: any[];
  
  // World building
  private materialLibrary?: MaterialLibrary;
  private worldBuilderTools?: WorldBuilderTools;
  private startingIsland?: BabylonMesh;
  
  // Multi-user system
  private otherUsers: Map<string, any> = new Map(); // userId -> user mesh
  private currentUserId?: string;
  
  // Movement and input state
  private keys: MovementKeys = {
    w: false,
    a: false,
    s: false,
    d: false,
    ' ': false,
    b: false
  };
  
  private mouseMovement: MouseMovement = {
    leftMouseDown: false,
    rightMouseDown: false,
    isMovingForward: false,
    inRightClickMode: false,
    moveStartTime: 0
  };
  
  private moveSpeed: number = 5;
  private forwardSpeedMultiplier: number = 1.0;
  private strafeSpeedMultiplier: number = 0.8;
  private isInWater: boolean = false;
  private isJumping: boolean = false;
  private jumpVelocity: number = 0;
  private buildMode: boolean = false; // gated world editing
  private useUnifiedMovement: boolean = true; // new simplified movement system override
  private playerVisual?: any; // child mesh when using pivot
  
  // Event handlers
  private keyDownHandler?: (e: KeyboardEvent) => void;
  private keyUpHandler?: (e: KeyboardEvent) => void;
  private lastBuildModeToggle = 0;
  private toastContainer?: HTMLDivElement;
  private pointerOverUI: boolean = false;
  
  // Position broadcasting
  private lastPositionUpdate = 0;
  private lastPosition = { x: 0, y: 0, z: 0 };
  
  // UI elements
  private chatContainer?: HTMLDivElement;
  private messagesArea?: HTMLDivElement;
  private chatInput?: HTMLInputElement;
  
  // Configuration and data
  private sceneConfig: GameSceneConfig = {};
  private userData: UserData = { id: 0 };
  private _lastDataset?: DOMStringMap;

    // Dataset attributes supported on canvas element:
    // data-forward-speed="float"   : scales forward movement fallback (default 1.0)
    // data-strafe-speed="float"    : scales strafe movement fallback (default 0.8)
    // data-build-mode="true|false"  : enables world editing interactions (default false)

  // Phoenix LiveView Hook Methods
  public pushEvent!: (event: string, payload: any) => void;
  public handleEvent!: (event: string, callback: (data: any) => void) => void;

  public mounted(): void {
    console.log('OpenWorldLobbyScene hook mounted');
    ;(window as any).__OpenWorldLobbySceneMounted = true;
    // Provide no-op fallbacks early if LiveView wiring hasn't attached yet (manual fallback mount scenario)
    if (typeof this.pushEvent !== 'function') {
      (this as any).pushEvent = () => { /* no-op fallback */ };
    }
    if (typeof this.handleEvent !== 'function') {
      (this as any).handleEvent = () => { /* no-op fallback */ };
    }
    
    // Initialize metrics
    if (!window.__lobbyMetrics) {
      window.__lobbyMetrics = { mounts: 0, updates: 0 };
      console.log('[LobbyMetrics] Initialized metrics');
    }
    window.__lobbyMetrics.mounts += 1;
    console.log(`[LobbyMetrics] Mount #${window.__lobbyMetrics.mounts}`);
    
    // Parse configuration data
    this.sceneConfig = JSON.parse(this.el.dataset.sceneConfig || '{}');
    this.userData = JSON.parse(this.el.dataset.user || '{}');

    // Canvas element is the hook element
    
    // Initialize the scene
    this.initializeScene()
      .then(() => {
        this.setupEventListeners();
        // Restore persisted build mode preference
        try {
          const saved = localStorage.getItem('lobby.buildMode');
            if (saved === 'true' && !this.buildMode) {
              this.buildMode = true; // initial state before toggle to avoid double flip
              // Force UI state sync
              (this as any).toggleBuildMode?.();
            }
        } catch(_) {}
        console.log('OpenWorldLobbyScene ready');
      })
      .catch(e => console.error('Init failed:', e));
  }

  public updated(): void {
    if (window.__lobbyMetrics) {
      window.__lobbyMetrics.updates += 1;
    }
    
    // Debug: log update reason and diff
    const prev = this._lastDataset || {};
    const curr = { ...this.el.dataset };
    const changed: string[] = [];
    
    for (const k in curr) {
      if (curr[k] !== prev[k]) {
        changed.push(`${k}: ${prev[k]} → ${curr[k]}`);
      }
    }
    
    this._lastDataset = curr;
    console.log('[LobbyDebug] LiveView updated, dataset:', curr, 'Changed:', changed);
  }

  public destroyed(): void {
    console.log('OpenWorldLobbyScene destroyed');
    this.cleanup();
  }

  // Scene Initialization
  private async initializeScene(): Promise<void> {
    console.log('Initializing scene...');
    
    try {
      // Ensure Babylon dynamic classes are fully loaded before constructing Engine
      await initializeBabylonExports();
      const existing = (window as any).BABYLON || {};
      const sceneLoaderRef = SceneLoader || existing.SceneLoader || (window as any).SceneLoader || (globalThis as any).SceneLoader;
      if (typeof (window as any).BABYLON === 'undefined') {
        (window as any).BABYLON = {
          Engine, Scene, Vector3, Color3, Ray, ArcRotateCamera, HemisphericLight,
          DirectionalLight, MeshBuilder, StandardMaterial, ActionManager, SceneLoader: sceneLoaderRef
        };
        console.log('[LobbyDebug] BABYLON facade created', { hasSceneLoader: !!sceneLoaderRef });
      } else {
        if (!(window as any).BABYLON.SceneLoader && sceneLoaderRef) {
          (window as any).BABYLON.SceneLoader = sceneLoaderRef;
          console.log('[LobbyDebug] SceneLoader attached to existing BABYLON facade');
        } else if (!(window as any).BABYLON.SceneLoader) {
          console.warn('[LobbyDebug] SceneLoader still undefined after dynamic import');
        }
      }
    } catch (e) {
      console.error('Failed to initialize BABYLON:', e);
      return;
    }
    
    this.createChatUI();
    this.setupCanvas();

  // Pull optional speed multipliers from dataset (e.g., data-forward-speed, data-strafe-speed)
  const fwd = parseFloat(this.el.dataset.forwardSpeed || '');
  const strafe = parseFloat(this.el.dataset.strafeSpeed || '');
  if (!isNaN(fwd) && fwd > 0) this.forwardSpeedMultiplier = fwd;
  if (!isNaN(strafe) && strafe > 0) this.strafeSpeedMultiplier = strafe;
  this.buildMode = (this.el.dataset.buildMode === 'true');
    
    console.log('[LobbyDebug] Babylon Engine ref type:', typeof Engine, Engine);
    this.engine = new Engine(this.el, true, { 
      preserveDrawingBuffer: true, 
      stencil: true, 
      antialias: true 
    });
    
  console.log('[LobbyDebug] Babylon Scene ref type:', typeof Scene, Scene);
  this.scene = new Scene(this.engine);
  // Camera safeguard: ensure there is always an active camera (prevents black screen if player creation fails)
  if (!this.scene.activeCamera) {
    try {
      const tmpCam = new ArcRotateCamera('safeguard_camera', Math.PI / 2, Math.PI / 3, 120, new Vector3(0, 30, 0), this.scene);
      // DO NOT attach controls to temporary camera - prevents control interference
      // tmpCam.attachControl(this.el, true); // REMOVED: causes control conflicts
      this.scene.activeCamera = tmpCam;
      console.log('[LobbyDebug] Safeguard ArcRotateCamera created (no controls attached)');
    } catch (camErr) {
      console.warn('[LobbyDebug] Failed to create safeguard camera', camErr);
    }
  }
    this.scene.actionManager = new ActionManager(this.scene);
    this.engine.resize();
    
    this.setupEnvironment();
    
    // Initialize World Builder System
    this.materialLibrary = new MaterialLibrary(this.scene);
    this.worldBuilderTools = new WorldBuilderTools(this.scene, this.materialLibrary);
    console.log('🏗️ World Builder tools initialized');
    
    await this.createWorld();
    await this.createPlayer();
    this.setupMovement();
    this.setupServerEventHandlers();
    if (typeof this.handleEvent === 'function') {
      try {
        this.setupEventListeners?.();
      } catch (e) {
        console.warn('[LobbyHook] setupEventListeners threw:', e);
      }
    } else {
      console.warn('[LobbyHook] handleEvent missing; skipping setupEventListeners');
    }
    
    // Start render loop
    this.engine.runRenderLoop(() => {
      this.updateMovement();
      this.scene?.render();
      
      // Auto-resize check
      if (this.engine &&
          (this.engine.getRenderWidth() !== this.el.clientWidth ||
           this.engine.getRenderHeight() !== this.el.clientHeight)) {
        this.engine.resize();
      }
    });
    
    window.addEventListener('resize', () => this.engine?.resize());
    console.log('Scene initialized successfully');
  }

  private setupCanvas(): void {
    this.el.style.width = '100%';
    this.el.style.height = '100%';
    requestAnimationFrame(() => {
      const parent = this.el.parentElement;
      let w = window.innerWidth;
      let h = window.innerHeight - 30;
      if (parent) {
        w = parent.offsetWidth || w;
        h = parent.offsetHeight || h;
      }
      this.el.width = w;
      this.el.height = h;
      console.log(`[LobbyDebug] Canvas size set to: ${this.el.width}x${this.el.height}`);
    });
  }

  private setupEnvironment(): void {
    if (!this.scene) return;
    
    const hemi = new HemisphericLight('ambient', new Vector3(0, 1, 0), this.scene);
    hemi.intensity = 0.6;
    
    const sun = new DirectionalLight('sun', new Vector3(-1, -1, -0.5), this.scene);
    sun.intensity = 0.8;
    sun.diffuse = new Color3(1, 0.9, 0.8);
    
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = new Color3(0.7, 0.8, 0.9);
    this.scene.fogDensity = 0.0002;
  }

  // World Creation
  private async createWorld(): Promise<void> {
    console.log('Creating infinite world builder...');
    
    try {
      await this.createInfiniteWorld();
    } catch (e) {
      console.warn('Infinite world failed; using fallback flat terrain', e);
      this.createFallbackTerrain();
    }
    
    this.createInfiniteWater();
  }

  private async createInfiniteWorld(): Promise<void> {
    if (!this.scene) return;
    
    const islandRadius = 100;
    const islandSubdivisions = 64;
    
    this.startingIsland = MeshBuilder.CreateDisc('startingIsland', {
      radius: islandRadius,
      subdivisions: islandSubdivisions
    }, this.scene);
    
    this.startingIsland.rotation.x = Math.PI / 2;
    this.startingIsland.position.y = 50;
    
    const islandMat = new StandardMaterial('islandMaterial', this.scene);
    islandMat.diffuseColor = new Color3(0.6, 0.8, 0.4);
    this.startingIsland.material = islandMat;
    this.startingIsland.checkCollisions = true;
    
    console.log('✅ Starting island created');
    this.terrain = this.startingIsland;
  }

  private createFallbackTerrain(): void {
    if (!this.scene) return;
    
    this.terrain = MeshBuilder.CreateGround('fallbackTerrain', {
      width: 200,
      height: 200,
      subdivisions: 50
    }, this.scene);
    
    this.terrain.position.y = 50;
    const mat = new StandardMaterial('fallbackTerrainMaterial', this.scene);
    mat.diffuseColor = new Color3(0.3, 0.5, 0.3);
    this.terrain.material = mat;
  }

  private createInfiniteWater(): void {
    if (!this.scene) return;
    
    const waterSize = 10000;
    this.water = MeshBuilder.CreateGround('infiniteWater', {
      width: waterSize,
      height: waterSize,
      subdivisions: 8
    }, this.scene);
    
    this.water.position.y = 45;
    
    const waterMat = new StandardMaterial('infiniteWaterMaterial', this.scene);
    waterMat.diffuseColor = new Color3(0.1, 0.3, 0.8);
    waterMat.alpha = 0.8;
    waterMat.backFaceCulling = false;
    this.water.material = waterMat;
    
    // Animated water effect
    this.scene.registerBeforeRender(() => {
      if (this.water) {
        const t = Date.now() * 0.001;
        this.water.position.y = 45 + Math.sin(t * 0.3) * 0.5;
      }
    });
    
    console.log('✅ Infinite water created');
  }

  // Character Creation
  private async createPlayer(): Promise<void> {
    try {
      await this.loadRandomCharacter();
    } catch (e) {
      console.error('Random character load failed (no fallback model will be created):', e);
  this.showToast?.('Character failed to load. See console for details.');
    }
  }

  private async loadRandomCharacter(): Promise<void> {
    if (!this.scene) return;
    
    // Initialize character model manager
    // Read optional character manifest from dataset (JSON array of folder names)
    let manifestNames: string[] | undefined;
    try {
      if (this.el.dataset.characterManifest) {
        const parsed = JSON.parse(this.el.dataset.characterManifest);
        if (Array.isArray(parsed)) manifestNames = parsed;
      }
    } catch (e) {
      console.warn('Failed to parse data-character-manifest:', e);
    }
    this.characterModelManager = new CharacterModelManager(this.scene, manifestNames);
    
    // Get a random character configuration
    const characterConfig = this.characterModelManager.getRandomCharacterConfig();
    console.log(`🎲 Selected random character: ${characterConfig.name} (${characterConfig.type})`);
    
    // Load the character model
    const characterModel = await this.characterModelManager.loadCharacterModel(characterConfig.type);
    
  // Wrap loaded mesh in a pivot so rotation & movement always affect root uniformly
  this.playerVisual = characterModel.mesh;
  const pivot = new TransformNode('playerPivot', this.scene);
  pivot.position = new Vector3(0, 55, 0);
  this.playerVisual.setParent(pivot);
  this.player = pivot as any; // treat pivot as player for movement
  
  // Debug character setup
  console.log('🐾 Character setup:', {
    meshName: this.playerVisual.name,
    meshPosition: this.playerVisual.position,
    meshScaling: this.playerVisual.scaling,
    pivotPosition: pivot.position,
    boundingInfo: this.playerVisual.getBoundingInfo?.(),
    visible: this.playerVisual.isVisible
  });
  
  // Ensure character is visible
  this.playerVisual.isVisible = true;
  if (this.playerVisual.setEnabled) this.playerVisual.setEnabled(true);
  
  // Also ensure all child meshes are visible
  const allMeshes = this.scene.meshes.filter((m: any) => 
    m.name.includes(characterConfig.name) || m.parent === this.playerVisual
  );
  allMeshes.forEach((mesh: any) => {
    mesh.isVisible = true;
    if (mesh.setEnabled) mesh.setEnabled(true);
    console.log(`🔍 Child mesh: ${mesh.name}, visible: ${mesh.isVisible}`);
  });
    
    // Store character information
    this.characterModel = characterModel;
    this.characterConfig = characterConfig;
    
    // Universal: no per-character behavior system
    this.playerAnimations = characterModel.animationGroups || [];
    if (this.playerAnimations.length) console.log('Character animations:', this.playerAnimations.map(a => a.name));
    
    // Set up camera
    this.setupCamera();
    
  // Universal controls message (only once)
  this.addChatMessage('SYSTEM', 'Controls: W forward | S back | A/D turn (hold right mouse for strafe).', '#ffff66');
  // Add name tag for the local player as well
  try { this.addNameTag(this.player, this.getCurrentUsername()); } catch(_) {}
    
    console.log(`✅ Random character loaded: ${characterConfig.name}`, {
      type: characterConfig.type,
      animations: this.playerAnimations.length
    });
    
    // DEBUG: List all meshes in scene
    console.log('🌍 All meshes in scene:', this.scene.meshes.map((m: any) => ({
      name: m.name,
      position: m.position,
      visible: m.isVisible,
      enabled: m.isEnabled
    })));
  }

  private createFallbackPlayer(): void {
    // Removed: no primitive fallback player per strict load policy.
  }

  private setupCamera(): void {
    if (!this.player || !this.scene) return;

    // Create ArcRotateCamera with standard MMO settings
    this.camera = new ArcRotateCamera('playerCamera', Math.PI * 1.5, Math.PI / 3, 10, this.player.position.clone(), this.scene);

    // Standard MMO camera controls - mouse always controls camera rotation
    this.camera.attachControl(this.el, true);

    this.camera.lowerRadiusLimit = 5;
    this.camera.upperRadiusLimit = 120;
    this.camera.lowerBetaLimit = 0.15;
    this.camera.upperBetaLimit = Math.PI / 2.1;
    this.camera.wheelPrecision = 40;
    this.camera.panningSensibility = 0; // disable panning

    // Camera follows character automatically
    this.camera.setTarget(this.player.position);

    // Continuous camera following
    this.scene.onBeforeRenderObservable.add(() => {
      if (!this.camera || !this.player) return;
      this.camera.setTarget(this.player.position);
    });

    // Make this the active camera
    if (this.scene.activeCamera && this.scene.activeCamera !== this.camera) {
      try { this.scene.activeCamera.dispose(); } catch (_) { /* ignore */ }
    }
    this.scene.activeCamera = this.camera;

    console.log('🎮 MMO Camera setup complete - mouse rotates camera, WASD moves character');
  }

  // Removed addCharacterWelcomeMessage (species-specific guidance no longer needed in universal control mode)

  // Movement System
  private setupMovement(): void {
    this.mouseMovement = {
      leftMouseDown: false,
      rightMouseDown: false,
      isMovingForward: false,
      inRightClickMode: false,
      moveStartTime: 0
    };

    this.keyDownHandler = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      const chat = document.getElementById('chat-input');
      const chatFocus = chat && document.activeElement === chat;
      
      if (['w', 'a', 's', 'd', ' ', 'b'].includes(k) && !chatFocus) {
        e.preventDefault();
        e.stopPropagation();
        this.keys[k as keyof MovementKeys] = true;
      }

      // CTRL toggles build mode (ignore if typing in chat or repeating)
      if ((e.key === 'Control' || e.code === 'ControlLeft' || e.code === 'ControlRight') && !chatFocus) {
        const now = Date.now();
        if (now - this.lastBuildModeToggle > 250) { // debounce
          this.toggleBuildMode();
          this.lastBuildModeToggle = now;
        }
      }
      // ESC exits build mode
      if (e.key === 'Escape' && this.buildMode) {
        this.toggleBuildMode(false);
      }
    };

    this.keyUpHandler = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      const chat = document.getElementById('chat-input');
      const chatFocus = chat && document.activeElement === chat;
      
      if (['w', 'a', 's', 'd', ' ', 'b'].includes(k) && !chatFocus) {
        e.preventDefault();
        e.stopPropagation();
        this.keys[k as keyof MovementKeys] = false;
      }
    };

    document.addEventListener('keydown', this.keyDownHandler, { capture: true });
    document.addEventListener('keyup', this.keyUpHandler, { capture: true });
    this.setupMouseControls();
    // TODO: Re-enable after implementing building UI\n    // this.createBuildingUI();
  }

  private setupMouseControls(): void {
    this.el.addEventListener('contextmenu', e => e.preventDefault());
    
    this.el.addEventListener('mousedown', (e: MouseEvent) => {
      if (e.button === 0) {
        this.mouseMovement.leftMouseDown = true;
        this.checkForwardMovement();
      } else if (e.button === 2) {
        e.preventDefault();
        this.mouseMovement.rightMouseDown = true;
        this.checkForwardMovement();
        this.startRightClickMode();
      }
    });

    this.el.addEventListener('mouseup', (e: MouseEvent) => {
      if (e.button === 0) {
        this.mouseMovement.leftMouseDown = false;
        this.checkForwardMovement();
      } else if (e.button === 2) {
        this.mouseMovement.rightMouseDown = false;
        this.checkForwardMovement();
        this.endRightClickMode();
      }
    });

    this.el.addEventListener('mouseleave', () => {
      this.mouseMovement.leftMouseDown = false;
      this.mouseMovement.rightMouseDown = false;
      this.mouseMovement.isMovingForward = false;
      this.endRightClickMode();
    });
  }

  private startRightClickMode(): void {
    if (!this.camera || !this.player) return;
    this.mouseMovement.inRightClickMode = true;
  }

  private endRightClickMode(): void {
    if (!this.camera) return;
    this.mouseMovement.inRightClickMode = false;
  }

  private checkForwardMovement(): void {
    const should = this.mouseMovement.leftMouseDown && this.mouseMovement.rightMouseDown;
    
    if (should && !this.mouseMovement.isMovingForward) {
      this.mouseMovement.isMovingForward = true;
      this.mouseMovement.moveStartTime = Date.now();
    } else if (!should && this.mouseMovement.isMovingForward) {
      this.mouseMovement.isMovingForward = false;
    }
  }

  private updateMovement(): void {
    if (!this.player || !this.camera || !this.engine) return;
    const dt = this.engine.getDeltaTime() / 1000;
    this.applyUnifiedMovement(dt);
  }

  // New unified movement system ensuring: W forward, S backward, A/D turn (unless right mouse => strafe)
  private applyUnifiedMovement(dt: number): void {
    if (!this.player) return;
    
    // Standard MMO movement system: WASD moves character relative to camera direction
    const yawSpeed = 2.2; // radians/sec (not used in MMO style)
    let moveForward = 0; // +1 forward, -1 backward
    let moveStrafe = 0;  // +1 right, -1 left

    // Standard MMO WASD controls - always strafe, no turning
    if (this.keys.w) moveForward += 1;
    if (this.keys.s) moveForward -= 1;
    if (this.keys.a) moveStrafe -= 1;
    if (this.keys.d) moveStrafe += 1;

    // Normalize diagonal movement
    if (moveForward !== 0 && moveStrafe !== 0) {
      const inv = 1 / Math.sqrt(2);
      moveForward *= inv;
      moveStrafe *= inv;
    }

    if (moveForward !== 0 || moveStrafe !== 0) {
      // Move character relative to camera's current facing direction (MMO style)
      const alpha = this.camera.alpha; // Camera's horizontal rotation

      // Calculate movement vectors based on camera orientation
      const fwd = new Vector3(Math.sin(alpha), 0, Math.cos(alpha));
      const right = new Vector3(Math.cos(alpha), 0, -Math.sin(alpha));

      const velocity = fwd.scale(moveForward * this.moveSpeed * this.forwardSpeedMultiplier)
        .add(right.scale(moveStrafe * this.moveSpeed * this.strafeSpeedMultiplier));

      (this.player as any).position.x += velocity.x * dt;
      (this.player as any).position.z += velocity.z * dt;

      // Simple ground clamp (retain existing Y)
      if ((this.player as any).position.y < 50) (this.player as any).position.y = 50;
    }

    // Camera automatically follows character (handled in setupCamera)
    // No manual setTarget needed here

    // Broadcast position (throttled)
    this.broadcastPosition();

    // Basic animation fallback
    this.updateCharacterAnimation();
  }

  private updateCharacterAnimation(): void {
    if (!this.playerAnimations || !this.playerAnimations.length) return;
    const moving = this.keys.w || this.keys.s || this.keys.a || this.keys.d;
    const lower = (n: string) => n.toLowerCase();
  const find = (q: string) => (this.playerAnimations || []).find(a => lower(a.name).includes(q));
    const target = moving ? (find('run') || find('walk')) : find('idle');
    if (!target) return;
    if (!target.isPlaying) {
      this.playerAnimations.forEach(a => { if (a !== target && a.isPlaying) a.stop(); });
      target.start(true);
    }
  }

  private getTerrainHeightAt(x: number, z: number): number {
    if (!this.terrain || !this.scene) return 0;
    
    const rayOrig = new Vector3(x, 100, z);
    const hit = this.scene.pickWithRay(new Ray(rayOrig, new Vector3(0, -1, 0)), (m: any) => m === this.terrain);
    return (hit.hit && hit.pickedPoint) ? hit.pickedPoint.y : 0;
  }

  // Chat System
  private createChatUI(): void {
    // Idempotent: if chat already exists, skip
    if (this.chatContainer && document.body.contains(this.chatContainer)) {
      return;
    }

    // Remove any orphaned previous instance
    const existing = document.getElementById('world-chat-container');
    if (existing) existing.remove();

    const chatContainer = document.createElement('div');
    chatContainer.id = 'world-chat-container';
    chatContainer.style.cssText = `
      position: absolute;
      bottom: 20px;
      left: 20px;
      width: 400px;
      max-height: 300px;
      background: rgba(0,0,0,0.8);
      border-radius: 8px;
      padding: 10px;
      font-family: monospace;
      font-size: 12px;
      color: #00ff00;
      z-index: 1000;
      pointer-events: auto;
    `;

    const messagesArea = document.createElement('div');
    messagesArea.id = 'chat-messages-area';
    messagesArea.style.cssText = `
      max-height: 200px;
      overflow-y: auto;
      margin-bottom: 10px;
      padding: 5px;
    `;

    const inputContainer = document.createElement('div');
    inputContainer.style.cssText = 'display: flex; gap: 5px;';

    const chatInput = document.createElement('input');
    chatInput.id = 'chat-input';
    chatInput.type = 'text';
    chatInput.placeholder = 'Type message...';
    chatInput.style.cssText = `
      flex: 1;
      background: rgba(0,0,0,0.9);
      border: 1px solid #00ff00;
      color: #00ff00;
      padding: 5px;
      border-radius: 4px;
      font-family: monospace;
      font-size: 12px;
    `;

    const sendBtn = document.createElement('button');
    sendBtn.textContent = 'Send';
    sendBtn.style.cssText = `
      background: #00ff00;
      color: #000;
      border: none;
      padding: 5px 10px;
      border-radius: 4px;
      cursor: pointer;
      font-family: monospace;
      font-size: 12px;
    `;

    inputContainer.appendChild(chatInput);
    inputContainer.appendChild(sendBtn);
    chatContainer.appendChild(messagesArea);
    chatContainer.appendChild(inputContainer);
    // Prefer mounting outside LiveView diff region for persistence across patches
    // so LiveView re-renders do not destroy the chat container.
    try {
      if (!document.getElementById('world-chat-container')) {
        // Wrap in a fixed-position holder to avoid layout shifts
        const holderId = 'world-chat-holder';
        let holder = document.getElementById(holderId);
        if (!holder) {
          holder = document.createElement('div');
          holder.id = holderId;
          holder.style.cssText = 'position:fixed; bottom:0; left:0; width:0; height:0; z-index: 1500; pointer-events:none;';
          document.body.appendChild(holder);
        }
        chatContainer.style.position = 'relative';
        chatContainer.style.bottom = 'auto';
        chatContainer.style.left = 'auto';
        chatContainer.style.margin = '0 0 20px 20px';
        holder.appendChild(chatContainer);
      }
    } catch (e) {
      console.warn('[LobbyChat] Fallback to parent append due to body attach failure:', e);
      this.el.parentElement?.appendChild(chatContainer);
    }

    this.chatContainer = chatContainer;
    this.messagesArea = messagesArea;
    this.chatInput = chatInput;

    // Event handlers for chat
    this.setupChatEventHandlers(chatInput, sendBtn);
  }

  private setupChatEventHandlers(chatInput: HTMLInputElement, sendBtn: HTMLButtonElement): void {
    const enterHandler = (e: KeyboardEvent) => {
      e.stopImmediatePropagation();
      if (e.key === 'Enter') {
        e.preventDefault();
        this.sendChatMessage();
        return false;
      }
    };

    chatInput.addEventListener('keydown', enterHandler, true);
    chatInput.addEventListener('keyup', e => e.stopImmediatePropagation(), true);
    chatInput.addEventListener('keypress', (e: KeyboardEvent) => {
      e.stopImmediatePropagation();
      if (e.key === 'Enter') {
        e.preventDefault();
        return false;
      }
    }, true);

    sendBtn.addEventListener('click', (e: MouseEvent) => {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.sendChatMessage();
      return false;
    }, true);
  }

  private addChatMessage(username: string, message: string, color: string = '#00ff00'): void {
    if (!this.messagesArea) return;
    
    const el = document.createElement('div');
    el.style.cssText = `margin-bottom: 5px; color: ${color}; word-wrap: break-word;`;
    const ts = new Date().toLocaleTimeString();
    el.innerHTML = `<span style="color: #888">[${ts}]</span> <strong>${username}:</strong> ${message}`;
    this.messagesArea.appendChild(el);
    this.messagesArea.scrollTop = this.messagesArea.scrollHeight;
    
    // Keep only last 50 messages
    while (this.messagesArea.children.length > 50) {
      this.messagesArea.removeChild(this.messagesArea.firstChild!);
    }
  }

  private sendChatMessage(): void {
    if (!this.chatInput || !this.chatInput.value.trim()) return;
    
    const msg = this.chatInput.value.trim();
    const username = this.getCurrentUsername();
    this.addChatMessage(username, msg);
    
    try {
      if (typeof this.pushEvent === 'function') {
        this.pushEvent('chat_message', {
          message: msg,
          username,
          user_id: this.userData?.id
        });
      }
    } catch (e) {
      console.warn('Failed to send chat:', e);
    }
    
    this.chatInput.value = '';
    this.chatInput.blur();
  }

  // Event Handlers
  private setupEventListeners(): void {
    this.handleEvent('chat_message', (d: ChatMessageData) => {
      if (d.username !== this.getCurrentUsername()) {
        this.addChatMessage(d.username, d.message);
      }
    });
    
    this.handleEvent('user_joined', (d: UserJoinedData) => {
      this.addChatMessage('SYSTEM', `${d.username} joined the world`, '#00ffff');
    });
    
    this.handleEvent('user_left', (d: UserLeftData) => {
      this.addChatMessage('SYSTEM', `${d.username} left the world`, '#ff8800');
    });
  }

  private getCurrentUsername(): string {
    return this.userData?.name || this.userData?.username || 'Player';
  }

  // Position Broadcasting and Multi-user Support
  private broadcastPosition(): void {
    if (!this.player) return;
    if (typeof this.pushEvent !== 'function') return; // Fallback mount without LiveView wiring
    
    const now = Date.now();
    const pos = this.player.position;
    
    // Only broadcast if position changed significantly or enough time passed
    const moved = Math.abs(pos.x - this.lastPosition.x) > 0.1 || 
                  Math.abs(pos.y - this.lastPosition.y) > 0.1 || 
                  Math.abs(pos.z - this.lastPosition.z) > 0.1;
    
    if (moved && now - this.lastPositionUpdate > 100) { // Max 10 updates per second
      this.pushEvent('update_position', {
        x: pos.x,
        y: pos.y,
        z: pos.z
      });
      
      this.lastPositionUpdate = now;
      this.lastPosition = { x: pos.x, y: pos.y, z: pos.z };
    }
  }

  private setupServerEventHandlers(): void {
    if (typeof this.handleEvent !== 'function' || typeof this.pushEvent !== 'function') {
      console.warn('[LobbyNet] LiveView event wiring not available (likely manual fallback mount). Skipping server event handlers.');
      return;
    }
    // Get user ID for filtering
    this.currentUserId = this.getCurrentUserId();
    
    // Handle other users joining
    this.handleEvent('user_joined', (data: any) => {
      console.log('User joined:', data);
      this.handleUserJoined(data);
    });
    
    // Handle other users leaving
    this.handleEvent('user_left', (data: any) => {
      console.log('User left:', data);
      this.handleUserLeft(data);
    });
    
    // Handle position updates from other users
    this.handleEvent('position_update', (data: any) => {
      this.handlePositionUpdate(data);
    });
  }

  private getCurrentUserId(): string {
    // Extract user ID from the canvas data attribute
    const userId = this.el.dataset.userId;
    return userId || '';
  }

  // Multi-user System Methods
  private handleUserJoined(data: any): void {
    const { user_id, position, character_type } = data;
    
    if (user_id === this.currentUserId) {
      return; // Don't render ourselves
    }
    
    console.log(`👥 User joined: ${user_id} with character: ${character_type}`);
    this.createOtherUserCharacter(user_id, position, character_type);
  }

  private handleUserLeft(data: any): void {
    const { user_id } = data;
    
    if (user_id === this.currentUserId) {
      return;
    }
    
    console.log(`👋 User left: ${user_id}`);
    this.removeOtherUserCharacter(user_id);
  }

  private handlePositionUpdate(data: any): void {
    const { user_id, x, y, z, rotation_y } = data;
    
    if (user_id === this.currentUserId) {
      return; // Don't update ourselves
    }
    
    const userMesh = this.otherUsers.get(user_id);
    if (userMesh) {
      // Update position smoothly
      userMesh.position.x = x;
      userMesh.position.y = y;
      userMesh.position.z = z;
      if (rotation_y !== undefined) {
        userMesh.rotation.y = rotation_y;
      }
    }
  }

  private async createOtherUserCharacter(userId: string, position: any, characterType: string): Promise<void> {
    if (!this.scene || !this.characterModelManager) return;
    
    try {
      // Load the same character model for other users
      const config = this.characterModelManager.getCharacterConfig(characterType as any);
      if (!config) {
        console.warn(`Unknown character type: ${characterType}`);
        return;
      }
      
      const characterModel = await this.characterModelManager.loadCharacterModel(config.type);
      const otherUserMesh = characterModel.mesh;
      
      // Position the character
      otherUserMesh.position.x = position.x || 0;
      otherUserMesh.position.y = position.y || 50;
      otherUserMesh.position.z = position.z || 0;
      
      // Make it slightly transparent to distinguish from player
      if (otherUserMesh.material) {
        otherUserMesh.material.alpha = 0.8;
      }
      
      // Add a name tag
      this.addNameTag(otherUserMesh, `User ${userId.slice(-4)}`);
      
      // Store reference
      this.otherUsers.set(userId, otherUserMesh);
      
      console.log(`✅ Created character for user ${userId}`);
    } catch (error) {
      console.error(`Failed to create character for user ${userId}:`, error);
    }
  }

  private removeOtherUserCharacter(userId: string): void {
    const userMesh = this.otherUsers.get(userId);
    if (userMesh) {
      userMesh.dispose();
      this.otherUsers.delete(userId);
      console.log(`🗑️ Removed character for user ${userId}`);
    }
  }

  private addNameTag(mesh: any, name: string): void {
    if (!this.scene) return;
    
    try {
      // Create a simple text plane above the character
      const nameTagPlane = MeshBuilder.CreatePlane(`nametag_${name}`, { size: 2 }, this.scene);
      nameTagPlane.position.y = 3; // Above the character
      nameTagPlane.billboardMode = 7; // Face camera
      nameTagPlane.setParent(mesh);
      
      // Create text material (simplified)
      const nameTagMaterial = new StandardMaterial(`nametag_mat_${name}`, this.scene);
      nameTagMaterial.diffuseColor = new Color3(1, 1, 1);
      nameTagMaterial.emissiveColor = new Color3(0.2, 0.8, 0.2);
      nameTagPlane.material = nameTagMaterial;
    } catch (error) {
      console.warn('Could not create name tag:', error);
    }
  }

  // --- Build Mode: Toggle & UI Wiring ---
  private toggleBuildMode(forceValue?: boolean): void {
    this.buildMode = (typeof forceValue === 'boolean') ? forceValue : !this.buildMode;
    const buildPanel = document.getElementById('build-ui-panel');
    const playPanels = Array.from(document.querySelectorAll('.play-ui-panel')) as HTMLElement[];
    if (buildPanel) {
      if (this.buildMode) {
        buildPanel.classList.add('build-ui-active');
      } else {
        buildPanel.classList.remove('build-ui-active');
      }
    }
    playPanels.forEach(p => {
      if (this.buildMode) p.classList.add('play-ui-hidden'); else p.classList.remove('play-ui-hidden');
    });
    // Reflect attribute for other systems
    this.el.dataset.buildMode = String(this.buildMode);
    console.log('[BuildMode]', this.buildMode ? 'ENABLED' : 'DISABLED');
    if (this.buildMode) this.wireBuildUI();
    this.persistBuildMode();
    this.showToast(this.buildMode ? 'Build Mode Enabled (ESC to exit)' : 'Build Mode Disabled');
  }

  private wireBuildUI(): void {
    const panel = document.getElementById('build-ui-panel');
    if (!panel) return;
    const hook: any = this;
    const getTools = () => hook.worldBuilderTools;
    // Tool buttons
    panel.querySelectorAll('button[data-build-tool]').forEach(btn => {
      btn.addEventListener('click', () => {
        const tool = (btn as HTMLElement).getAttribute('data-build-tool');
        if (getTools()) {
          getTools().setTool(tool);
        }
        panel.querySelectorAll('button[data-build-tool]').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
      }, { once: false });
    });
    // Actions
    panel.querySelectorAll('button[data-build-action]').forEach(btn => {
      btn.addEventListener('click', () => {
        const action = (btn as HTMLElement).getAttribute('data-build-action');
        const tools = getTools();
        if (!tools) return;
        if (action === 'delete') tools.deleteSelected();
        if (action === 'clear') tools.clearAll();
      }, { once: false });
    });
    // Sliders
    const size = panel.querySelector('#brush-size-input') as HTMLInputElement;
    const strength = panel.querySelector('#brush-strength-input') as HTMLInputElement;
    size?.addEventListener('input', () => { const t = getTools(); t && t.setBrushSize(parseInt(size.value, 10)); });
    strength?.addEventListener('input', () => { const t = getTools(); t && t.setBrushStrength(parseInt(strength.value, 10)); });
    // Material select
    const materialSel = panel.querySelector('#material-select') as HTMLSelectElement;
    materialSel?.addEventListener('change', () => { const t = getTools(); t && t.setMaterial(materialSel.value); });

    // Pointer over UI detection
    const uiRoot = panel.parentElement || panel;
    const mouseIn = () => { this.pointerOverUI = true; };
    const mouseOut = (ev: any) => {
      // Only set false if leaving the root completely
      if (!uiRoot.contains(ev.relatedTarget)) {
        this.pointerOverUI = false;
      }
    };
    uiRoot.addEventListener('mouseenter', mouseIn, true);
    uiRoot.addEventListener('mouseleave', mouseOut, true);
  }

  private persistBuildMode(): void {
    try { localStorage.setItem('lobby.buildMode', this.buildMode ? 'true' : 'false'); } catch(_) {}
  }

  private ensureToastContainer(): HTMLDivElement {
    if (!this.toastContainer) {
      const div = document.createElement('div');
      div.id = 'lobby-toast-container';
      div.style.position = 'fixed';
      div.style.top = '12px';
      div.style.right = '12px';
      div.style.zIndex = '9999';
      div.style.display = 'flex';
      div.style.flexDirection = 'column';
      div.style.gap = '6px';
      document.body.appendChild(div);
      this.toastContainer = div;
    }
    return this.toastContainer;
  }

  private showToast(message: string, duration = 2200): void {
    const container = this.ensureToastContainer();
    const item = document.createElement('div');
    item.textContent = message;
    item.style.background = 'rgba(0,0,0,0.7)';
    item.style.color = '#fff';
    item.style.padding = '6px 10px';
    item.style.fontSize = '13px';
    item.style.borderRadius = '4px';
    item.style.boxShadow = '0 2px 6px rgba(0,0,0,0.4)';
    item.style.opacity = '0';
    item.style.transform = 'translateY(-6px)';
    item.style.transition = 'opacity 160ms ease, transform 160ms ease';
    container.appendChild(item);
    requestAnimationFrame(() => {
      item.style.opacity = '1';
      item.style.transform = 'translateY(0)';
    });
    setTimeout(() => {
      item.style.opacity = '0';
      item.style.transform = 'translateY(-6px)';
      setTimeout(() => { if (item.parentElement) item.parentElement.removeChild(item); }, 220);
    }, duration);
  }

  // Cleanup
  private cleanup(): void {
    // Reset movement state
    this.mouseMovement.isMovingForward = false;
    this.mouseMovement.leftMouseDown = false;
    this.mouseMovement.rightMouseDown = false;
    this.mouseMovement.inRightClickMode = false;
    
    // Remove UI elements
    if (this.chatContainer?.parentElement) {
      this.chatContainer.parentElement.removeChild(this.chatContainer);
    }
    
    // Remove event listeners
    if (this.keyDownHandler) {
      document.removeEventListener('keydown', this.keyDownHandler, { capture: true });
    }
    if (this.keyUpHandler) {
      document.removeEventListener('keyup', this.keyUpHandler, { capture: true });
    }
    
    // Cleanup character systems
    if (this.characterModelManager) {
      this.characterModelManager.dispose();
    }
    
    // Dispose Babylon.js resources
    if (this.engine) {
      this.engine.dispose();
    }
  }
}

// Export for Phoenix LiveView Hook usage
export const OpenWorldLobbySceneHook = new OpenWorldLobbyScene();

// Instrumentation: confirm module evaluated
if (!(window as any).__LobbyModuleLoaded) {
  (window as any).__LobbyModuleLoaded = Date.now();
  console.log('[LobbyModule] open_world_lobby_scene_class.ts loaded at', new Date().toISOString());
}

// Expose for debugging
(window as any).OpenWorldLobbySceneHook = OpenWorldLobbySceneHook;

// Fallback mechanism: only activate on pages where the lobby canvas actually exists
// and only attempt a manual mount if LiveView has not mounted after a grace period.
(() => {
  const lobbyCanvasSelector = 'canvas#world-builder-scene[phx-hook="OpenWorldLobbyScene"]';
  const initialCanvas = document.querySelector(lobbyCanvasSelector);
  if (!initialCanvas) {
    // Observe for later insertion, but stay quiet unless it appears.
    const observer = new MutationObserver(() => {
      if ((window as any).__OpenWorldLobbySceneMounted) { observer.disconnect(); return; }
      const el = document.querySelector(lobbyCanvasSelector);
      if (el) {
        observer.disconnect();
        // Give LiveView a short window (500ms) to mount naturally before forcing.
        setTimeout(() => {
          if (!(window as any).__OpenWorldLobbySceneMounted) {
            console.warn('[LobbyFallback] LiveView hook not mounted after delayed appearance; invoking manually.');
            (OpenWorldLobbySceneHook as any).el = el;
            if (typeof (OpenWorldLobbySceneHook as any).mounted === 'function') {
              (OpenWorldLobbySceneHook as any).mounted();
            }
          }
        }, 500);
      }
    });
    try { observer.observe(document.documentElement, { subtree: true, childList: true }); } catch (_) {}
    return; // No immediate canvas found; defer.
  }
  // Canvas is present immediately; schedule a gentle check.
  setTimeout(() => {
    if (!(window as any).__OpenWorldLobbySceneMounted) {
      console.warn('[LobbyFallback] Hook not mounted (early canvas present); invoking manually.');
      (OpenWorldLobbySceneHook as any).el = initialCanvas as any;
      if (typeof (OpenWorldLobbySceneHook as any).mounted === 'function') {
        (OpenWorldLobbySceneHook as any).mounted();
      }
    }
  }, 1200);
})();

