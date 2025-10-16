// Core Three.js Scene Manager - Replaces ALL Babylon.js functionality
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import type { 
  ThreeSceneState, 
  ThreeSceneConfig, 
  CameraConfig, 
  LightingConfig,
  PhoenixLiveViewHook,
  GameWorldState,
  InputState,
  PerformanceMetrics,
  PlayerCharacter,
  CreatureNPC
} from '../types';

export class ThreeSceneManager implements PhoenixLiveViewHook {
  el: HTMLElement;
  private sceneState: ThreeSceneState | null = null;
  private worldState: GameWorldState | null = null;
  private inputState: InputState | null = null;
  private performanceMetrics: PerformanceMetrics | null = null;
  private animationId: number | null = null;
  private isDestroyed = false;

  constructor(element: HTMLElement) {
    if (!element) {
      throw new Error('ThreeSceneManager requires a valid HTML element');
    }
    this.el = element;
    this.initializeWindow();
  }

  private initializeWindow(): void {
    if (!window.ThreeJSMMO) {
      window.ThreeJSMMO = {
        scene: null,
        world: null,
        input: null,
        performance: null,
        debug: true
      };
    }
  }

  // Phoenix LiveView Hook Methods
  mounted(): void {
    console.log('🚀 ThreeJS Scene mounted');
    this.initializeScene()
      .then(() => {
        console.log('✅ ThreeJS Scene initialized successfully');
        this.setupEventListeners();
        this.startRenderLoop();
      })
      .catch(error => {
        console.error('❌ Failed to initialize ThreeJS scene:', error);
        this.handleError('initialization_failed', error);
      });
  }

  updated(): void {
    console.log('🔄 ThreeJS Scene updated');
    this.handleServerUpdates();
  }

  destroyed(): void {
    console.log('🗑️ ThreeJS Scene destroyed');
    this.cleanup();
  }

  // Core Scene Initialization
  private async initializeScene(): Promise<void> {
    // Check if this.el is already a canvas, or look for one inside
    let canvas: HTMLCanvasElement;
    
    if (this.el.tagName === 'CANVAS') {
      canvas = this.el as HTMLCanvasElement;
    } else {
      canvas = this.el.querySelector('canvas') as HTMLCanvasElement;
      if (!canvas) {
        // Create canvas if it doesn't exist (for galaxy scene)
        canvas = document.createElement('canvas');
        canvas.style.cssText = 'display: block; width: 100%; height: 100%;';
        this.el.appendChild(canvas);
      }
    }

    // Scene setup
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87CEEB);
    scene.fog = new THREE.Fog(0x87CEEB, 100, 1000);

    // Camera setup
    const camera = new THREE.PerspectiveCamera(
      75,
      canvas.clientWidth / canvas.clientHeight,
      0.1,
      2000
    );
    camera.position.set(0, 10, 30);

    // Renderer setup
    const renderer = new THREE.WebGLRenderer({ 
      canvas, 
      antialias: true,
      alpha: true,
      powerPreference: 'high-performance'
    });
    renderer.setSize(canvas.clientWidth, canvas.clientHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1;

    // Controls setup
    const controls = new OrbitControls(camera, canvas);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.minDistance = 5;
    controls.maxDistance = 100;
    controls.maxPolarAngle = Math.PI / 2;

    // Clock for animations
    const clock = new THREE.Clock();

    // Store scene state
    this.sceneState = {
      scene,
      camera,
      renderer,
      controls,
      clock,
      isInitialized: true,
      isDisposed: false
    };

    // Initialize world state
    this.worldState = {
      player: null,
      otherPlayers: new Map(),
      creatures: new Map(),
      environment: {
        buildings: new Map(),
        trees: new Map(),
        rocks: new Map(),
        water: null,
        skybox: null
      },
      terrain: null
    };

    // Initialize input state
    this.inputState = {
      keys: {
        forward: false,
        backward: false,
        left: false,
        right: false,
        jump: false,
        run: false,
        crouch: false,
        interact: false,
        inventory: false,
        chat: false
      },
      mouse: {
        x: 0,
        y: 0,
        deltaX: 0,
        deltaY: 0,
        leftButton: false,
        rightButton: false,
        middleButton: false,
        wheel: 0
      },
      touch: {
        touches: [],
        isActive: false
      }
    };

    // Set global references
    window.ThreeJSMMO.scene = this.sceneState;
    window.ThreeJSMMO.world = this.worldState;
    window.ThreeJSMMO.input = this.inputState;

    // Setup lighting
    this.setupLighting();
    
    // Setup environment
    this.setupEnvironment();
    
    // Load initial assets
    await this.loadInitialAssets();

    console.log('✅ ThreeJS scene initialization complete');
  }

  private setupLighting(): void {
    if (!this.sceneState) return;

    const { scene } = this.sceneState;

    // Ambient light
    const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
    scene.add(ambientLight);

    // Directional light (sun)
    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(100, 100, 50);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    directionalLight.shadow.camera.near = 0.5;
    directionalLight.shadow.camera.far = 500;
    scene.add(directionalLight);

    console.log('✅ Lighting setup complete');
  }

  private setupEnvironment(): void {
    if (!this.sceneState) return;

    const { scene } = this.sceneState;

    // Ground plane
    const groundGeometry = new THREE.PlaneGeometry(200, 200);
    const groundMaterial = new THREE.MeshLambertMaterial({ 
      color: 0x567d46 
    });
    const ground = new THREE.Mesh(groundGeometry, groundMaterial);
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    scene.add(ground);

    // Grid helper for debugging
    const gridHelper = new THREE.GridHelper(200, 50, 0x444444, 0x444444);
    scene.add(gridHelper);

    console.log('✅ Environment setup complete');
  }

  private async loadInitialAssets(): Promise<void> {
    // This is where we would load FBX models, textures, etc.
    // For now, create some test objects
    if (!this.sceneState) return;

    const { scene } = this.sceneState;

    // Test character (cube)
    const characterGeometry = new THREE.BoxGeometry(2, 4, 2);
    const characterMaterial = new THREE.MeshStandardMaterial({ 
      color: 0xff6600 
    });
    const character = new THREE.Mesh(characterGeometry, characterMaterial);
    character.position.set(0, 2, 0);
    character.castShadow = true;
    scene.add(character);

    // Test creatures (spheres)
    for (let i = 0; i < 5; i++) {
      const creatureGeometry = new THREE.SphereGeometry(1.5, 8, 6);
      const creatureMaterial = new THREE.MeshStandardMaterial({ 
        color: Math.random() * 0xffffff 
      });
      const creature = new THREE.Mesh(creatureGeometry, creatureMaterial);
      creature.position.set(
        (Math.random() - 0.5) * 40,
        1.5,
        (Math.random() - 0.5) * 40
      );
      creature.castShadow = true;
      scene.add(creature);
    }

    console.log('✅ Initial assets loaded');
  }

  private setupEventListeners(): void {
    if (!this.sceneState) return;

    // Window resize
    window.addEventListener('resize', this.handleResize.bind(this));

    // Keyboard input
    document.addEventListener('keydown', this.handleKeyDown.bind(this));
    document.addEventListener('keyup', this.handleKeyUp.bind(this));

    // Mouse input
    this.el.addEventListener('mousedown', this.handleMouseDown.bind(this));
    this.el.addEventListener('mouseup', this.handleMouseUp.bind(this));
    this.el.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.el.addEventListener('wheel', this.handleWheel.bind(this));

    console.log('✅ Event listeners setup complete');
  }

  private startRenderLoop(): void {
    if (!this.sceneState) return;

    const render = (): void => {
      if (this.isDestroyed || !this.sceneState) return;

      const { scene, camera, renderer, controls, clock } = this.sceneState;
      const deltaTime = clock.getDelta();

      // Update controls
      (controls as any).update();

      // Update animations
      this.updateAnimations(deltaTime);

      // Update performance metrics
      this.updatePerformanceMetrics();

      // Render scene
      renderer.render(scene, camera);

      // Continue loop
      this.animationId = requestAnimationFrame(render);
    };

    render();
    console.log('✅ Render loop started');
  }

  private updateAnimations(deltaTime: number): void {
    if (!this.worldState) return;

    // Update character animations
    if (this.worldState.player && this.worldState.player.mixer) {
      this.worldState.player.mixer.update(deltaTime);
    }

    // Update other player animations
    this.worldState.otherPlayers.forEach((player: PlayerCharacter) => {
      if (player.mixer) {
        player.mixer.update(deltaTime);
      }
    });

    // Update creature animations
    this.worldState.creatures.forEach((creature: CreatureNPC) => {
      if (creature.mixer) {
        creature.mixer.update(deltaTime);
      }
    });
  }

  private updatePerformanceMetrics(): void {
    if (!this.sceneState) return;

    const { renderer } = this.sceneState;
    const info = renderer.info;

    this.performanceMetrics = {
      fps: 0, // Would calculate from frame timing
      frameTime: 0,
      triangles: info.render.triangles,
      drawCalls: info.render.calls,
      textureMemory: info.memory.textures,
      geometryMemory: info.memory.geometries,
      programs: info.programs?.length || 0
    };

    window.ThreeJSMMO.performance = this.performanceMetrics;
  }

  private handleResize(): void {
    if (!this.sceneState) return;

    const { camera, renderer } = this.sceneState;
    const canvas = renderer.domElement;

    camera.aspect = canvas.clientWidth / canvas.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(canvas.clientWidth, canvas.clientHeight);
  }

  private handleKeyDown(event: KeyboardEvent): void {
    if (!this.inputState) return;

    switch (event.code) {
      case 'KeyW': this.inputState.keys.forward = true; break;
      case 'KeyS': this.inputState.keys.backward = true; break;
      case 'KeyA': this.inputState.keys.left = true; break;
      case 'KeyD': this.inputState.keys.right = true; break;
      case 'Space': this.inputState.keys.jump = true; break;
      case 'ShiftLeft': this.inputState.keys.run = true; break;
      case 'KeyC': this.inputState.keys.crouch = true; break;
      case 'KeyE': this.inputState.keys.interact = true; break;
      case 'KeyI': this.inputState.keys.inventory = true; break;
      case 'Enter': this.inputState.keys.chat = true; break;
    }
  }

  private handleKeyUp(event: KeyboardEvent): void {
    if (!this.inputState) return;

    switch (event.code) {
      case 'KeyW': this.inputState.keys.forward = false; break;
      case 'KeyS': this.inputState.keys.backward = false; break;
      case 'KeyA': this.inputState.keys.left = false; break;
      case 'KeyD': this.inputState.keys.right = false; break;
      case 'Space': this.inputState.keys.jump = false; break;
      case 'ShiftLeft': this.inputState.keys.run = false; break;
      case 'KeyC': this.inputState.keys.crouch = false; break;
      case 'KeyE': this.inputState.keys.interact = false; break;
      case 'KeyI': this.inputState.keys.inventory = false; break;
      case 'Enter': this.inputState.keys.chat = false; break;
    }
  }

  private handleMouseDown(event: MouseEvent): void {
    if (!this.inputState) return;

    switch (event.button) {
      case 0: this.inputState.mouse.leftButton = true; break;
      case 1: this.inputState.mouse.middleButton = true; break;
      case 2: this.inputState.mouse.rightButton = true; break;
    }
  }

  private handleMouseUp(event: MouseEvent): void {
    if (!this.inputState) return;

    switch (event.button) {
      case 0: this.inputState.mouse.leftButton = false; break;
      case 1: this.inputState.mouse.middleButton = false; break;
      case 2: this.inputState.mouse.rightButton = false; break;
    }
  }

  private handleMouseMove(event: MouseEvent): void {
    if (!this.inputState) return;

    const rect = this.el.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    this.inputState.mouse.deltaX = x - this.inputState.mouse.x;
    this.inputState.mouse.deltaY = y - this.inputState.mouse.y;
    this.inputState.mouse.x = x;
    this.inputState.mouse.y = y;
  }

  private handleWheel(event: WheelEvent): void {
    if (!this.inputState) return;

    this.inputState.mouse.wheel = event.deltaY;
  }

  private handleServerUpdates(): void {
    // Handle updates from Phoenix LiveView
    const sceneConfig = this.getSceneConfig();
    if (sceneConfig) {
      this.applySceneConfiguration(sceneConfig);
    }
  }

  private getSceneConfig(): any {
    try {
      const configData = this.el.dataset.sceneConfig;
      return configData ? JSON.parse(configData) : null;
    } catch {
      return null;
    }
  }

  private applySceneConfiguration(config: any): void {
    if (!this.sceneState || !config) return;

    const { camera } = this.sceneState;

    // Update camera if specified
    if (config.camera) {
      if (config.camera.position) {
        camera.position.set(
          config.camera.position.x || 0,
          config.camera.position.y || 10,
          config.camera.position.z || 30
        );
      }
    }
  }

  private handleError(type: string, error: Error): void {
    console.error(`ThreeJS Scene Error [${type}]:`, error);
    
    // Could emit to Phoenix LiveView
    if (this.pushEvent) {
      this.pushEvent('threejs_error', {
        type,
        message: error.message,
        stack: error.stack
      });
    }
  }

  private cleanup(): void {
    this.isDestroyed = true;

    // Stop render loop
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }

    // Dispose Three.js resources
    if (this.sceneState) {
      this.sceneState.controls.dispose();
      this.sceneState.renderer.dispose();
      this.sceneState.isDisposed = true;
    }

    // Clear global references
    if (window.ThreeJSMMO) {
      window.ThreeJSMMO.scene = null;
      window.ThreeJSMMO.world = null;
      window.ThreeJSMMO.input = null;
      window.ThreeJSMMO.performance = null;
    }

    // Remove event listeners
    window.removeEventListener('resize', this.handleResize.bind(this));
    document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    document.removeEventListener('keyup', this.handleKeyUp.bind(this));

    console.log('✅ ThreeJS scene cleanup complete');
  }

  // Phoenix LiveView event methods (optional)
  pushEvent?(event: string, payload: any): void;
  pushEventTo?(selector: string, event: string, payload: any): void;
  handleEvent?(event: string, callback: (payload: any) => void): void;
}

export default ThreeSceneManager;