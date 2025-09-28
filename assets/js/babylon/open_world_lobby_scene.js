// Open World Lobby System - CraterLake Adventure
import { SeamlessZoneManager } from './seamless_zone_manager';
import { 
    Engine, Scene, Vector3, Vector2, Matrix, Quaternion, Color3, Color4,
    FreeCamera, ArcRotateCamera, UniversalCamera,
    HemisphericLight, DirectionalLight,
    MeshBuilder, StandardMaterial, PBRMaterial,
    ActionManager, ExecuteCodeAction, PointerEventTypes
} from './babylon_imports';

/**
 * Open World Lobby Scene Hook - CraterLake Adventure with Cat Avatars
 */
export const OpenWorldLobbyScene = {
    mounted() {
        console.log('OpenWorldLobbyScene hook mounted');
        this.el._babylonHook = this;
        
        // Initialize state
        this.users = new Map();
        this.chatMessages = [];
        this.currentUser = null;
        // Centralized constants
        this.constants = {
            waterLevel: 50,
            // Increase gap so small wave oscillations don't cause flip-flop
            waterEnterOffset: -0.2,  // must be a bit below surface to count entering
            waterExitOffset: 0.6     // must rise well above to count exiting
        };
        
        // Get configuration from Phoenix LiveView
        this.sceneConfig = JSON.parse(this.el.dataset.sceneConfig || '{}');
        this.userData = JSON.parse(this.el.dataset.user || '{}');
        this.serverUsers = JSON.parse(this.el.dataset.users || '[]');
        // Begin async initialization (no blocking overlay; will announce via chat)
        this.systemChat?.('Initializing CraterLake world...');
        this.initializeOpenWorld()
            .then(() => {
                this.setupEventListeners();
                this.systemChat?.('CraterLake world ready. Have fun!');
            })
            .catch(error => {
                console.error('Failed to initialize open world lobby:', error);
                this.systemChat?.('Initialization failed: ' + (error.message || error));
            });
    },

    updated() {
        console.log('OpenWorldLobbyScene updated');
        
        // Update user data from server
        const newUsers = JSON.parse(this.el.dataset.users || '[]');
        this.updateServerUsers(newUsers);
    },

    destroyed() {
        console.log('OpenWorldLobbyScene destroyed');
        this.cleanup();
    },

    // Legacy compatibility: seamless_zone_manager may call this for zones requiring GUI
    // Our simplified lobby removed overlay GUI, so provide a safe no-op.
    async setupOverlayUI() {
        // Intentionally empty - prevents TypeError from legacy call path.
        return Promise.resolve();
    },

    /**
     * Initialize the open world system with CraterLake
     */
    async initializeOpenWorld() {
        console.log('Initializing CraterLake open world...');
        
        // Create chat UI first so progress messages are visible immediately
        this.createChatUI();
        this.systemChat?.('Initializing CraterLake world...');
        
        // Initialize Babylon.js scene
        await this.initializeBabylonScene();
        
        // Setup seamless zone manager with CraterLake configuration
        this.zoneManager = new SeamlessZoneManager(this, {
            // CraterLake world configuration - optimized for new 1024x1024 heightmap
            worldSize: 1024,        // Match heightmap size for 1:1 mapping
            chunkSize: 128,         // Adjusted for 1024 world size
            loadRadius: 2,          // Slightly more chunks for better coverage
            unloadRadius: 4,        // Unload chunks 4+ away
            
            // Performance settings optimized for speed
            maxConcurrentLoads: 1,  // Reduced to prevent blocking
            lodEnabled: false,      // Disable LOD initially for simplicity
            
            // Lake-specific settings
            seaLevel: 50,          // Water level in the crater
            enableSeamlessTransitions: false, // Disable for now
            transitionDistance: 32
        });
        
        // Add CraterLake heightmap as a custom region
        this.setupCraterLakeRegion();
        
        // Initialize the world system (spawn in middle of crater lake) with timeout - updated for 1024x1024 map
        const spawnPosition = new Vector3(0, 52, 0); // Center of 1024x1024 world, just above water level
        console.log('🌍 Starting zone manager initialization...');
        try {
            await Promise.race([
                this.zoneManager.initialize(spawnPosition),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Zone initialization timeout')), 2000))
            ]);
            console.log('✅ Zone manager initialized');
        } catch (error) {
            console.warn('Zone initialization failed/timeout:', error.message);
            // Continue anyway - basic scene still works
        }
        
        // Setup water system with timeout
        console.log('🌊 Setting up water system...');
        try {
            await Promise.race([
                this.setupWaterSystem(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Water setup timeout')), 1000))
            ]);
            console.log('✅ Water system ready');
        } catch (error) {
            console.warn('Water setup failed/timeout:', error.message);
            // Create minimal water plane as fallback
            this.createMinimalWater();
        }

    // Load crater lake mesh (optional decorative mesh if provided) with timeout
    console.log('🏔️ Loading optional crater lake mesh...');
    try {
        await Promise.race([
            this.loadCraterLakeMesh(),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Mesh loading timeout')), 1000))
        ]);
        console.log('✅ Crater lake mesh loaded');
    } catch (error) {
        console.warn('Mesh loading failed/timeout:', error.message);
        // Continue without decorative mesh
    }
        
        // Create t-rex avatar for current user with timeout
        console.log('🦖 Creating t-rex avatar...');
        this.avatarLoadAttempted = true;
        try {
            await Promise.race([
                this.createCatAvatar(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Avatar creation timeout')), 2000))
            ]);
            console.log('✅ T-Rex avatar ready');
            this.avatarLoadSuccessful = true;
        } catch (error) {
            console.warn('Avatar creation failed/timeout:', error.message);
            // Only create minimal fallback if main avatar didn't load
            if (!this.playerCat) {
                this.createMinimalAvatar();
                // Try background loading to replace minimal avatar
                this.loadFullAvatarBackground();
            }
        }
        
        // Setup multiplayer user tracking
        this.setupMultiplayerSystem();
        
        // Setup chat event handling (UI already created earlier)
        this.setupChatEventHandling();
        
        console.log('CraterLake open world ready!');
    },

    /**
     * Initialize basic Babylon.js scene
     */
    async initializeBabylonScene() {
        // Create engine
        const canvas = this.el;
        this.engine = new Engine(canvas, true, {
            preserveDrawingBuffer: true,
            stencil: true,
            antialias: true
        });
        
        // Create scene
        this.scene = new Scene(this.engine);
        this.scene.actionManager = new ActionManager(this.scene);
        console.debug('[CraterLake] Scene & action manager created');

        // Setup environment
        this.setupEnvironment();
        console.debug('[CraterLake] Environment setup invoked');

        // Start render loop
        this.engine.runRenderLoop(() => {
            this.scene.render();
        });
        console.debug('[CraterLake] Render loop started');

        // Handle resize
        window.addEventListener('resize', () => this.engine.resize());
    },

    /**
     * Setup scene environment (lighting, skybox, etc.)
     */
    setupEnvironment() {
        // Ambient lighting for outdoor scene
        const hemisphericLight = new HemisphericLight('ambient', new Vector3(0, 1, 0), this.scene);
        hemisphericLight.intensity = 0.6;
        
        // Sun light
        const sunLight = new DirectionalLight('sun', new Vector3(-1, -1, -0.5), this.scene);
        sunLight.intensity = 0.8;
        sunLight.diffuse = new Color3(1, 0.9, 0.8); // Warm sunlight
        
        // Setup camera for lake view
        this.camera = new UniversalCamera('playerCamera', new Vector3(0, 55, 0), this.scene);
        console.debug('[CraterLake] UniversalCamera created');
        try {
            if (typeof this.camera.attachControl === 'function') {
                this.camera.attachControl(this.el, true);
                console.debug('[CraterLake] Camera attachControl succeeded');
            } else {
                console.warn('[CraterLake] attachControl missing on camera');
            }
        } catch (e) {
            console.error('[CraterLake] Failed to attach camera control', e);
        }
        
        // Camera settings for swimming/walking
        this.camera.setTarget(Vector3.Zero());
        this.camera.minZ = 0.1;
        this.camera.maxZ = 10000;
        
        // Setup fog for distance
        this.scene.fogMode = Scene.FOGMODE_EXP2;
        this.scene.fogColor = new Color3(0.7, 0.8, 0.9);
        this.scene.fogDensity = 0.0002;
    },

    /**
     * Setup CraterLake as a special heightmap region
     */
    setupCraterLakeRegion() {
        // Add CraterLake as a special region in the world system - updated for new 1024x1024 heightmap
        this.zoneManager.worldSystem.addWorldRegion('craterlake', {
            center: { x: 0, z: 0 },
            radius: 512,            // Half of 1024 world size
            heightRange: { min: 0, max: 200 },
            terrainType: 'heightmap',
            biome: 'volcanic_lake',
            heightmapSource: 'craterlake_custom'
        });
        
        // Add custom heightmap provider for CraterLake with new heightmap
        const craterLakeProvider = new CraterLakeHeightmapProvider({
            heightmapPath: '/assets/terrain/heightmaps/NewCratorProject_HeightMap_1024x1024_0_0.png',
            fallbackPaths: [
                '/models/NewCratorProject_HeightMap_1024x1024_0_0.png',
                '/assets/NewCratorProject_HeightMap_1024x1024_0_0.png',
                '/NewCratorProject_HeightMap_1024x1024_0_0.png'
            ]
        });
        this.zoneManager.streamingSystem.addChunkProvider('craterlake_custom', craterLakeProvider);
    },

    /**
     * Create minimal water plane as fallback when full setup fails
     */
    createMinimalWater() {
        console.log('Creating minimal water fallback...');
        const waterSize = 1000;
        this.waterMesh = MeshBuilder.CreateGround('minimal_water', {
            width: waterSize,
            height: waterSize,
            subdivisions: 4
        }, this.scene);
        
        this.waterMesh.position.y = this.constants.waterLevel;
        
        const waterMaterial = new StandardMaterial('minimal_water_mat', this.scene);
        waterMaterial.diffuseColor = new Color3(0.1, 0.4, 0.8);
        waterMaterial.alpha = 0.7;
        this.waterMesh.material = waterMaterial;
    },

    /**
     * Create minimal avatar as fallback when model loading fails
     */
    createMinimalAvatar() {
        console.log('Creating minimal avatar fallback...');
        
        // Clean up any existing avatar first
        if (this.playerCat) {
            this.playerCat.dispose();
            this.playerCat = null;
        }
        
        this.playerCat = MeshBuilder.CreateCapsule('minimal_trex', {
            radius: 0.8,
            height: 2.5
        }, this.scene);
        
        this.playerCat.position.set(0, this.constants.waterLevel + 1, 0);
        this.playerCat.metadata = { isMinimalAvatar: true }; // Mark as minimal fallback
        
        const material = new StandardMaterial('minimal_trex_mat', this.scene);
        material.diffuseColor = new Color3(0.4, 0.6, 0.3); // T-Rex green color
        this.playerCat.material = material;
        
        // Setup camera and ensure controls work
        this.setupCatCameraFollow();
        
        // Ensure mouse controls are active (sometimes gets lost during avatar creation)
        if (this.camera && this.camera.inputs) {
            // Don't clear inputs - we need them for camera controls!
            // this.camera.inputs.clear(); // This was breaking camera controls
        }
        
        // Add debugging info
        console.log('✅ Minimal avatar created with camera controls ready');
    },

    /**
     * Setup water system for the crater lake
     */
    async setupWaterSystem() {
        console.log('Setting up crater lake water...');
        
        // Create large water plane for the lake
        const waterSize = 2000; // Large enough to cover visible lake area
        this.waterMesh = MeshBuilder.CreateGround('lake_water', {
            width: waterSize,
            height: waterSize,
            subdivisions: 32
        }, this.scene);
        
        // Position at water level
    this.waterMesh.position.y = this.constants.waterLevel; // Sea level
        
        // Create water material
        const waterMaterial = new StandardMaterial('water_material', this.scene);
        waterMaterial.diffuseColor = new Color3(0.1, 0.3, 0.8);
        waterMaterial.specularColor = new Color3(0.8, 0.8, 1.0);
        waterMaterial.emissiveColor = new Color3(0.05, 0.1, 0.2);
        waterMaterial.alpha = 0.8;
        waterMaterial.backFaceCulling = false;
        
        this.waterMesh.material = waterMaterial;
        
        // Add subtle water animation
        this.scene.registerBeforeRender(() => {
            if (this.waterMesh) {
                const time = Date.now() * 0.001;
                this.waterMesh.position.y = this.constants.waterLevel + Math.sin(time * 0.5) * 0.2; // Gentle wave motion
            }
        });
    },

    /**
     * Create t-rex avatar for the current user
     */
    async createCatAvatar() {
        console.log('Creating t-rex avatar...');
        
        try {
            // Load the cat model
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            await import('@babylonjs/loaders/glTF');

            // Try multiple possible static paths
            const tried = [];
            const candidatePaths = [
                { root: '/models/', file: 't-rex.gltf' },
                { root: '/models/', file: 't-rex.glb' },
                { root: '/assets/models/', file: 't-rex.gltf' },
                { root: '/assets/models/', file: 't-rex.glb' },
                { root: '/assets/', file: 't-rex.gltf' },
                { root: '/', file: 't-rex.gltf' }
            ];
            let result = null;
            for (const p of candidatePaths) {
                try {
                    console.log(`Attempting to load t-rex model from: ${p.root}${p.file}`);
                    
                    // For GLTF files, check if companion files exist before attempting load
                    if (p.file.endsWith('.gltf')) {
                        try {
                            // Quick check if scene.bin exists
                            const binCheck = await fetch(`${p.root}scene.bin`, { method: 'HEAD' });
                            if (!binCheck.ok) {
                                console.log(`⚠️ Binary file scene.bin not accessible at ${p.root}scene.bin`);
                            }
                        } catch (binError) {
                            console.log(`⚠️ Cannot check for binary file: ${binError.message}`);
                        }
                    }
                    
                    // Import with proper scene loader configuration for GLTF with binary files
                    result = await SceneLoader.ImportMeshAsync('', p.root, p.file, this.scene);
                    if (result && result.meshes && result.meshes.length > 0) {
                        console.log(`✅ Successfully loaded t-rex model from ${p.root}${p.file}`);
                        break;
                    } else {
                        console.log(`⚠️ No meshes found in ${p.root}${p.file}`);
                        tried.push(`${p.root}${p.file} (no meshes)`);
                    }
                } catch (e) {
                    console.log(`❌ Failed to load from ${p.root}${p.file}:`, e.message);
                    // Try alternative file if this was a .gltf and we have .glb
                    if (p.file === 'cat1.gltf') {
                        try {
                            console.log(`Trying alternative GLB format: ${p.root}cat1.glb`);
                            result = await SceneLoader.ImportMeshAsync('', p.root, 'cat1.glb', this.scene);
                            if (result && result.meshes && result.meshes.length > 0) {
                                console.log(`✅ Successfully loaded cat model from ${p.root}cat1.glb`);
                                break;
                            }
                        } catch (glbError) {
                            console.log(`❌ GLB fallback also failed: ${glbError.message}`);
                        }
                    }
                    tried.push(`${p.root}${p.file} (${e.message})`);
                }
            }
            if (!result || !result.meshes || result.meshes.length === 0) {
                console.warn('T-Rex model not found in candidate paths:', tried.join(', '));
                throw new Error('T-Rex model not found in any candidate path');
            }
            
            if (result.meshes.length > 0) {
                this.playerCat = result.meshes[0];
                this.playerCat.position.copyFrom(this.camera.position);
                this.playerCat.position.y = 52; // Start just above water
                this.playerCat.scaling = new Vector3(2, 2, 2); // Make cat bigger
                
                // Setup cat animation if available
                if (result.animationGroups.length > 0) {
                    this.catAnimations = result.animationGroups;
                    this.mapAnimations(result.animationGroups);
                    this.playAnimationState('idle');
                }
                
                // Add name tag above cat
                await this.createNameTag(this.playerCat, this.getCurrentUsername());
                
                // Setup third-person camera follow
                this.setupCatCameraFollow();
                
                console.log('✅ T-Rex avatar created and configured');
            }
        } catch (error) {
            console.error('Failed to load t-rex model, creating fallback avatar:', error);
            this.createFallbackAvatar();
        }
    },

    /**
     * Attempt to load full avatar in background to replace minimal one
     */
    async loadFullAvatarBackground() {
        // Don't attempt background loading if main avatar already succeeded
        if (this.avatarLoadSuccessful) {
            console.log('Skipping background load - main avatar already successful');
            return;
        }
        
        // Only try background loading if we have a minimal avatar
        if (!this.playerCat || !this.playerCat.metadata?.isMinimalAvatar) {
            return;
        }

        console.log('🔄 Attempting background full avatar load...');
        
        try {
            // Wait a bit to let other systems settle
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            // Try to load the full avatar
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            await import('@babylonjs/loaders/glTF');

            const candidatePaths = [
                { root: '/models/', file: 't-rex.gltf' },
                { root: '/models/', file: 't-rex.glb' }
            ];

            for (const p of candidatePaths) {
                try {
                    console.log(`Background loading: ${p.root}${p.file}`);
                    const result = await SceneLoader.ImportMeshAsync('', p.root, p.file, this.scene);
                    
                    if (result && result.meshes && result.meshes.length > 0) {
                        console.log(`✅ Background load successful: ${p.root}${p.file}`);
                        
                        // Store current position and camera setup
                        const currentPos = this.playerCat.position.clone();
                        const currentRotation = this.characterRotation || 0;
                        
                        // Dispose minimal avatar
                        this.playerCat.dispose();
                        
                        // Setup new avatar
                        this.playerCat = result.meshes[0];
                        this.playerCat.position.copyFrom(currentPos);
                        this.playerCat.rotation.y = currentRotation;
                        this.playerCat.scaling = new Vector3(2, 2, 2);
                        this.playerCat.metadata = { isMinimalAvatar: false };
                        
                        // Setup animations if available
                        if (result.animationGroups.length > 0) {
                            this.catAnimations = result.animationGroups;
                            this.mapAnimations(result.animationGroups);
                            this.playAnimationState('idle');
                        }
                        
                        // Re-setup camera follow
                        this.setupCatCameraFollow();
                        
                        console.log('✅ Successfully replaced minimal avatar with full model');
                        return;
                    }
                } catch (e) {
                    console.log(`Background load failed for ${p.root}${p.file}:`, e.message);
                }
            }
            
            console.log('Background avatar load failed - keeping minimal avatar');
            
        } catch (error) {
            console.log('Background avatar loading error:', error.message);
        }
    },

    /**
     * Create fallback avatar if t-rex model fails to load
     */
    createFallbackAvatar() {
        this.playerCat = MeshBuilder.CreateCapsule('player_cat', {
            radius: 0.5,
            height: 1.5
        }, this.scene);
        
        this.playerCat.position.copyFrom(this.camera.position);
        this.playerCat.position.y = 52;
        
        const material = new StandardMaterial('cat_material', this.scene);
        material.diffuseColor = new Color3(0.8, 0.6, 0.4); // Cat color
        this.playerCat.material = material;
        
        this.setupCatCameraFollow();
    },

    /**
     * Setup third-person camera to follow the cat
     */
    setupCatCameraFollow() {
        if (!this.playerCat) return;
        
        // Convert to arc rotate camera for third-person view
        this.camera.dispose();
        
        this.camera = new ArcRotateCamera(
            'catCamera',
            0,             // Start behind cat (alpha)
            Math.PI / 3,   // Look down slightly (beta)
            8,             // Distance from cat (radius)
            this.playerCat.position,
            this.scene
        );
        
        // Babylon v8: use attachControl instead of deprecated/non-existent attachToCanvas
        if (this.camera.attachControl) {
            this.camera.attachControl(this.el, true);
        } else {
            console.warn('Camera does not support attachControl – skipping');
        }
        this.camera.lowerRadiusLimit = 3;
        this.camera.upperRadiusLimit = 20;
        this.camera.lowerBetaLimit = 0.1; // Don't let camera go below ground
        this.camera.upperBetaLimit = Math.PI / 2.1; // Don't let camera flip over
        
        // Enable camera controls but customize them for MMO-style gameplay
        if (this.camera && this.camera.inputs) {
            // Keep mouse controls enabled for camera rotation
            // this.camera.inputs.clear(); // DON'T clear - we need these!
        }
        
        // Setup MMO-style movement and camera controls
        this.setupMMOControls();
    },

    /**
     * Setup MMO-style controls (WASD movement + mouse camera)
     */
    setupMMOControls() {
        const keys = {};
        this.moveSpeed = 5;
        this.isInWater = true; // Start in water
        this.characterRotation = 0; // Character facing direction
    // Movement physics extensions
    this.baseMoveSpeed = 5;
    this.currentMoveSpeed = this.baseMoveSpeed;
    this.waterDragFactor = 0.65; // Target speed multiplier while swimming
    this.waterAccelBlend = 0.05;  // Smoothing factor for speed transitions
    this.coyoteTimeMs = 150;      // Grace period after leaving ground allowing jump
    this.lastGroundedAt = performance.now();
    this.wasGrounded = true;
    this.slopeSlipThresholdDeg = 32; // Start sliding when slope exceeds this
    this.slopeSlipExtraDeg = 4; // Additional degrees before full slide speed
    this.slopeSlipSpeed = 4; // Base slide horizontal speed contribution
        
        // Mouse control state
        this.mouseState = {
            leftButtonDown: false,
            rightButtonDown: false,
            lastMouseX: 0,
            lastMouseY: 0
        };
        
        // Keyboard input
        this.scene.actionManager.registerAction(new ExecuteCodeAction(ActionManager.OnKeyDownTrigger, (evt) => {
            evt.sourceEvent.preventDefault(); // Prevent page reload/navigation
            evt.sourceEvent.stopPropagation(); // Stop bubbling that might trigger other handlers
            const k = evt.sourceEvent.key.toLowerCase();
            keys[k] = true;
            if (k === ' ') this.handleJumpPress();
        }));
        
        this.scene.actionManager.registerAction(new ExecuteCodeAction(ActionManager.OnKeyUpTrigger, (evt) => {
            evt.sourceEvent.preventDefault(); // Prevent page reload/navigation
            evt.sourceEvent.stopPropagation(); // Stop bubbling that might trigger other handlers
            const k = evt.sourceEvent.key.toLowerCase();
            keys[k] = false;
            if (k === ' ') this.handleJumpRelease();
        }));
        
        // Additional global keyboard interception for safety
        this.keys = keys; // Store reference for movement system (reuse existing keys object)
        
        document.addEventListener('keydown', (evt) => {
            const k = evt.key.toLowerCase();
            if (['w', 'a', 's', 'd', ' ', 'shift', 'control'].includes(k)) {
                evt.preventDefault();
                evt.stopPropagation();
                evt.stopImmediatePropagation();
                keys[k] = true; // Track key state for movement
                if (k === ' ') this.handleJumpPress();
            }
        }, { capture: true });
        
        document.addEventListener('keyup', (evt) => {
            const k = evt.key.toLowerCase();
            if (['w', 'a', 's', 'd', ' ', 'shift', 'control'].includes(k)) {
                evt.preventDefault();
                evt.stopPropagation();
                evt.stopImmediatePropagation();
                keys[k] = false; // Track key state for movement
                if (k === ' ') this.handleJumpRelease();
            }
        }, { capture: true });
        
        // Mouse controls
        this.el.addEventListener('mousedown', (evt) => {
            evt.preventDefault(); // Prevent default mouse behavior
            evt.stopPropagation();
            if (evt.button === 0) { // Left mouse button
                this.mouseState.leftButtonDown = true;
                this.el.requestPointerLock();
            } else if (evt.button === 2) { // Right mouse button
                this.mouseState.rightButtonDown = true;
                this.el.requestPointerLock();
            }
            this.mouseState.lastMouseX = evt.clientX;
            this.mouseState.lastMouseY = evt.clientY;
        });
        
        this.el.addEventListener('mouseup', (evt) => {
            evt.preventDefault();
            evt.stopPropagation();
            if (evt.button === 0) {
                this.mouseState.leftButtonDown = false;
            } else if (evt.button === 2) {
                this.mouseState.rightButtonDown = false;
            }
            
            // Release pointer lock when no mouse buttons are pressed
            if (!this.mouseState.leftButtonDown && !this.mouseState.rightButtonDown) {
                document.exitPointerLock();
            }
        });
        
        this.el.addEventListener('mousemove', (evt) => {
            evt.preventDefault();
            evt.stopPropagation();
            if (this.mouseState.leftButtonDown || this.mouseState.rightButtonDown) {
                const deltaX = evt.movementX || evt.webkitMovementX || 0;
                const deltaY = evt.movementY || evt.webkitMovementY || 0;
                
                const sensitivity = 0.005; // Increased sensitivity for better response
                
                if (this.mouseState.leftButtonDown) {
                    // Left click: Rotate both camera and character
                    if (this.camera) {
                        this.camera.alpha -= deltaX * sensitivity;
                        this.camera.beta += deltaY * sensitivity;
                        
                        // Update character rotation to match camera
                        this.characterRotation = this.camera.alpha;
                        if (this.playerCat) {
                            this.playerCat.rotation.y = this.characterRotation;
                        }
                    }
                    
                } else if (this.mouseState.rightButtonDown) {
                    // Right click: Only rotate camera, leave character facing alone
                    if (this.camera) {
                        this.camera.alpha -= deltaX * sensitivity;
                        this.camera.beta += deltaY * sensitivity;
                    }
                }
                
                // Clamp beta to prevent camera flipping
                if (this.camera) {
                    this.camera.beta = Math.max(this.camera.lowerBetaLimit || 0.1, 
                                              Math.min(this.camera.upperBetaLimit || Math.PI/2, this.camera.beta));
                }
            }
        });
        
        // Disable context menu on right click
        this.el.addEventListener('contextmenu', (evt) => {
            evt.preventDefault();
            evt.stopPropagation();
            evt.stopImmediatePropagation();
        });
        
        // Mouse wheel for zooming
        this.el.addEventListener('wheel', (evt) => {
            evt.preventDefault();
            evt.stopPropagation();
            const zoomSensitivity = 0.5;
            this.camera.radius += evt.deltaY * zoomSensitivity * 0.01;
            this.camera.radius = Math.max(this.camera.lowerRadiusLimit, Math.min(this.camera.upperRadiusLimit, this.camera.radius));
        });
        
        // Movement update loop
    this.prevCatPosition = null;
    this.animationState = 'idle';
    // Jump system state init
    this.isJumping = false;
    this.jumpStartTime = 0;
    this.jumpHoldMax = 2000; // ms
    this.jumpHeld = false;
    this.initialJumpVelocity = 10;
    this.additionalHoldBoost = 8;
    this.gravity = -25;
    this.verticalVelocity = 0;
    this.lastInWater = this.isInWater;
        this.scene.registerBeforeRender(() => {
            if (!this.playerCat) return;
            
            try {
                const deltaTime = this.engine.getDeltaTime() / 1000;

                // Update movement & camera
                const moved = this.updateCharacterMovement(this.keys, deltaTime);
                this.updateCameraFollow();

                // Ground follow always (even if idle)
                this.applyGroundFollow(deltaTime);

                // Jump physics update first
                this.updateJump(deltaTime);

                // Compute velocity magnitude for animation state machine
                if (!this.prevCatPosition) this.prevCatPosition = this.playerCat.position.clone();
                const dx = this.playerCat.position.x - this.prevCatPosition.x;
                const dz = this.playerCat.position.z - this.prevCatPosition.z;
                const velocity = Math.sqrt(dx * dx + dz * dz) / Math.max(deltaTime, 0.0001);
                this.prevCatPosition.copyFrom(this.playerCat.position);
                this.updateAnimationState(velocity);
                this.applySlopeAlignment(deltaTime);
                this.applySlopeSlip(deltaTime);
                this.updateDebugOverlay(deltaTime, velocity);
                this.detectWaterTransitions();
                this.interpolateRemoteUsers(deltaTime);
            } catch (error) {
                console.error('Render loop error:', error);
                // Continue running to prevent complete failure
            }
        });
    },

    // Restored water transition detection (previously removed by refactor)
    detectWaterTransitions() {
        if (!this.playerCat) return;
        // This function now delegates to hysteresis-based status update used in movement path
        this.updateWaterStateHysteresis();
    },

    spawnSplash(position, entering) {
        import('@babylonjs/core/Particles/particleSystem').then(({ ParticleSystem }) => {
            import('@babylonjs/core/Materials/Textures/texture').then(({ Texture }) => {
                const ps = new ParticleSystem('splash', 180, this.scene);
                ps.particleTexture = new Texture('https://assets.babylonjs.com/textures/flare.png', this.scene);
                ps.minEmitBox = new Vector3(-0.4, 0, -0.4);
                ps.maxEmitBox = new Vector3(0.4, 0.2, 0.4);
                if (entering) {
                    ps.color1 = new Color3(0.7,0.8,1.0);
                    ps.color2 = new Color3(0.4,0.6,0.9);
                } else {
                    ps.color1 = new Color3(0.9,0.95,1.0);
                    ps.color2 = new Color3(0.5,0.7,1.0);
                }
                ps.colorDead = new Color3(0.1,0.2,0.4);
                ps.minSize = 0.05; ps.maxSize = 0.35;
                ps.minLifeTime = 0.3; ps.maxLifeTime = 0.8;
                ps.emitRate = 500;
                ps.direction1 = new Vector3(-0.5, 4, -0.5);
                ps.direction2 = new Vector3(0.5, 4, 0.5);
                ps.minEmitPower = 1; ps.maxEmitPower = 3;
                ps.updateSpeed = 0.02;
                ps.emitter = new Vector3(position.x, position.y + 0.2, position.z);
                ps.start();
                setTimeout(() => { ps.stop(); ps.dispose(); }, 400);
            });
        });
    },

    handleJumpPress() {
        if (this.isInWater) return; // No jumping in water yet
        const now = performance.now();
        const timeSinceGrounded = now - this.lastGroundedAt;
        const withinCoyote = timeSinceGrounded <= this.coyoteTimeMs;
        if (!this.isJumping && (withinCoyote || this.wasGrounded)) {
            this.isJumping = true;
            this.jumpStartTime = now;
            this.jumpHeld = true;
            this.verticalVelocity = this.initialJumpVelocity;
            this.wasGrounded = false;
        } else {
            this.jumpHeld = true; // allow continued hold even if already jumping
        }
    },

    handleJumpRelease() {
        this.jumpHeld = false;
    },

    updateJump(deltaTime) {
        if (!this.isJumping) return;
        const now = performance.now();
        const elapsed = now - this.jumpStartTime;
        if (this.jumpHeld && elapsed < this.jumpHoldMax) {
            const holdFactor = Math.min(1, elapsed / this.jumpHoldMax);
            this.verticalVelocity = this.initialJumpVelocity + this.additionalHoldBoost * holdFactor;
        } else {
            this.verticalVelocity += this.gravity * deltaTime;
        }
        this.playerCat.position.y += this.verticalVelocity * deltaTime;
        const groundY = this.zoneManager.getHeightAtPosition(this.playerCat.position.x, this.playerCat.position.z) + 1;
        if (this.playerCat.position.y <= groundY && this.verticalVelocity <= 0) {
            // Landing
            if (Math.abs(this.verticalVelocity) > 10) {
                this.spawnDust(this.playerCat.position.clone());
            }
            this.playerCat.position.y = groundY;
            this.isJumping = false;
            this.verticalVelocity = 0;
            this.lastGroundedAt = now;
            this.wasGrounded = true;
        }
    },

    applySlopeSlip(deltaTime) {
        if (!this.playerCat || this.isInWater || this.isJumping || !this.lastSlopeNormal) return;
        // Derive slope angle
        const norm = this.lastSlopeNormal;
        const slopeRad = Math.acos(Math.min(1, Math.max(-1, norm.y)));
        const slopeDeg = slopeRad * 180 / Math.PI;
        const threshold = this.slopeSlipThresholdDeg;
        if (slopeDeg <= threshold) return;
        // Compute downhill direction: project gravity onto plane
        const down = new Vector3(0, -1, 0);
        const downhill = down.subtract(norm.scale(Vector3.Dot(down, norm))).normalize();
        // Scale speed with how much above threshold
        const over = Math.min(1, (slopeDeg - threshold) / this.slopeSlipExtraDeg);
        const slideSpeed = this.slopeSlipSpeed * (0.3 + 0.7 * over);
        this.playerCat.position.addInPlace(downhill.scale(slideSpeed * deltaTime));
    },

    /**
     * Update character movement based on input
     */
    updateCharacterMovement(keys, deltaTime) {
        const movement = new Vector3(0, 0, 0);
        let isMoving = false;
        
        // WASD movement relative to character facing direction
        if (keys['w']) {
            movement.z += 1; // Forward
            isMoving = true;
        }
        if (keys['s']) {
            movement.z -= 1; // Backward
            isMoving = true;
        }
        if (keys['a']) {
            movement.x -= 1; // Strafe left
            isMoving = true;
        }
        if (keys['d']) {
            movement.x += 1; // Strafe right
            isMoving = true;
        }
        
        if (isMoving) {
            movement.normalize();
            
            // Apply camera rotation to movement - fix direction issues
            // In Babylon.js, positive Z is forward, camera alpha is rotation around Y
            const cameraDirection = this.camera ? this.camera.alpha : this.characterRotation;
            const rotatedMovement = new Vector3(
                movement.x * Math.cos(cameraDirection - Math.PI/2) - movement.z * Math.sin(cameraDirection - Math.PI/2),
                0,
                movement.x * Math.sin(cameraDirection - Math.PI/2) + movement.z * Math.cos(cameraDirection - Math.PI/2)
            );
            
            // Apply movement
            // Dynamic water drag with smooth speed transitions
            const targetSpeed = this.isInWater ? this.baseMoveSpeed * this.waterDragFactor : this.baseMoveSpeed;
            this.currentMoveSpeed += (targetSpeed - this.currentMoveSpeed) * this.waterAccelBlend;
            this.playerCat.position.addInPlace(rotatedMovement.scale(this.currentMoveSpeed * deltaTime));
            
            // If moving forward/backward, update character rotation to match camera (for turning while moving)
            if (keys['w'] || keys['s']) {
                // Smoothly rotate character to match camera direction when moving forward/back
                const targetRotation = this.camera.alpha;
                const rotationDiff = targetRotation - this.characterRotation;
                
                // Handle rotation wrap-around
                let adjustedDiff = rotationDiff;
                if (adjustedDiff > Math.PI) adjustedDiff -= 2 * Math.PI;
                if (adjustedDiff < -Math.PI) adjustedDiff += 2 * Math.PI;
                
                // Smooth rotation
                this.characterRotation += adjustedDiff * deltaTime * 5; // Rotation speed
                this.playerCat.rotation.y = this.characterRotation;
            }
            
            // Check water status and play appropriate animations
            this.checkWaterStatus();
            
            // Send position update
            this.sendPositionUpdate();
            return true;
        }
        return false;
    },

    /**
     * Update camera to follow character smoothly
     */
    updateCameraFollow() {
        if (!this.playerCat || !this.camera) return;
        
        // Smooth camera target following
        const targetPosition = this.playerCat.position.clone();
        targetPosition.y += 1; // Camera looks at a point slightly above the cat
        
        // Lerp camera target to character position
        this.camera.target = Vector3.Lerp(this.camera.target, targetPosition, 0.1);
    },

    /**
     * Check if cat is in water or on land
     */
    checkWaterStatus() {
        // Replaced by hysteresis-based logic
        this.updateWaterStateHysteresis();
    },

    /**
     * Hysteresis water state update to prevent rapid toggling at boundary
     */
    updateWaterStateHysteresis() {
        if (!this.playerCat) return;
    const waterLevel = this.constants.waterLevel;
    const enterThreshold = waterLevel + this.constants.waterEnterOffset;
    const exitThreshold = waterLevel + this.constants.waterExitOffset;
        const y = this.playerCat.position.y;
        const was = this.isInWater;
        let nowIn = was;
        if (!was && y <= enterThreshold) nowIn = true;
        else if (was && y >= exitThreshold) nowIn = false;

        if (nowIn !== was) {
            // State change
            this.isInWater = nowIn;
            if (nowIn) {
                this.spawnSplash(this.playerCat.position.clone(), true);
                this.playSwimAnimation();
                this.systemChat?.('You start swimming.');
            } else {
                this.spawnSplash(this.playerCat.position.clone(), false);
                this.playWalkAnimation();
                this.systemChat?.('You reach the shore.');
            }
        }

        // Surface snap only if in water and not jumping
        if (this.isInWater && !this.isJumping) {
            // Create a stable target height slightly above water level
            this.waterSurfaceTarget ||= waterLevel + 0.45;
            // Slowly blend target toward actual dynamic water level to follow waves without oscillation
            const dynamicSurface = waterLevel + 0.45; // (could include wave sample later)
            this.waterSurfaceTarget += (dynamicSurface - this.waterSurfaceTarget) * 0.02;
            // Gentle positional convergence
            this.playerCat.position.y += (this.waterSurfaceTarget - this.playerCat.position.y) * 0.08;
        } else {
            this.waterSurfaceTarget = undefined; // reset when on land or jumping
        }
        // Land correction occurs in applyGroundFollow
    },

    /**
     * Explicit ground follow (called every frame)
     */
    applyGroundFollow(deltaTime) {
        if (!this.playerCat) return;
        const terrainHeight = this.zoneManager.getHeightAtPosition(
            this.playerCat.position.x,
            this.playerCat.position.z
        );
        if (!this.isInWater && !this.isJumping) {
            const desiredY = terrainHeight + 1;
            const before = this.playerCat.position.y;
            // Gentle correction
            this.playerCat.position.y += (desiredY - this.playerCat.position.y) * Math.min(1, deltaTime * 5);
            const after = this.playerCat.position.y;
            if (Math.abs(after - desiredY) < 0.05) {
                this.lastGroundedAt = performance.now();
            }
            this.wasGrounded = true;
        } else if (!this.isInWater && this.isJumping) {
            this.wasGrounded = false;
        }
    },

    /**
     * Update animation state machine (idle / walk / run / swim)
     */
    updateAnimationState(velocity) {
        if (!this.animClips) return;
        let desired = this.animationState;
        if (this.isInWater) desired = 'swim';
        else if (velocity > 6) desired = 'run';
        else if (velocity > 0.5) desired = 'walk';
        else desired = 'idle';
        if (desired !== this.animationState) {
            this.animationState = desired;
            this.playAnimationState(desired);
        }
    },

    // Enhanced landing+slide dust effect
    spawnDust(position) {
        import('@babylonjs/core/Particles/particleSystem').then(({ ParticleSystem }) => {
            import('@babylonjs/core/Materials/Textures/texture').then(({ Texture }) => {
                const ps = new ParticleSystem('landingDust', 150, this.scene);
                ps.particleTexture = new Texture('https://assets.babylonjs.com/textures/flare.png', this.scene);
                ps.minEmitBox = new Vector3(-0.3, 0, -0.3);
                ps.maxEmitBox = new Vector3(0.3, 0.15, 0.3);
                ps.color1 = new Color3(0.6,0.5,0.4);
                ps.color2 = new Color3(0.4,0.35,0.3);
                ps.colorDead = new Color3(0.2,0.15,0.1);
                ps.minSize = 0.05; ps.maxSize = 0.25;
                ps.minLifeTime = 0.15; ps.maxLifeTime = 0.5;
                ps.emitRate = 600;
                ps.direction1 = new Vector3(-0.5, 2, -0.5);
                ps.direction2 = new Vector3(0.5, 2, 0.5);
                ps.minEmitPower = 0.6; ps.maxEmitPower = 1.5;
                ps.updateSpeed = 0.02;
                ps.emitter = new Vector3(position.x, position.y + 0.05, position.z);
                ps.start();
                setTimeout(() => { ps.stop(); ps.dispose(); }, 250);
            });
        });
    },

    mapAnimations(groups) {
        const buckets = {
            idle: ['idle','stand','rest'],
            walk: ['walk'],
            run: ['run','jog','sprint'],
            swim: ['swim','water']
        };
        const normName = n => n.toLowerCase();
        const entries = groups.map(g => ({ g, name: normName(g.name.split('|').pop()) }));
        const pick = (keywords) => {
            for (const kw of keywords) {
                const exact = entries.find(e => e.name === kw);
                if (exact) return exact.g;
            }
            for (const kw of keywords) {
                const partial = entries.find(e => e.name.includes(kw));
                if (partial) return partial.g;
            }
            return null;
        };
        const animClips = {};
        for (const role of Object.keys(buckets)) {
            animClips[role] = pick(buckets[role]);
        }
        // Fallback chaining
        animClips.walk ||= animClips.idle;
        animClips.run ||= animClips.walk || animClips.idle;
        animClips.swim ||= animClips.idle;
        this.animClips = animClips;
        console.log('Animation clips mapped:', Object.fromEntries(Object.entries(animClips).map(([k,v]) => [k, v?.name])));
    },

    playAnimationState(state) {
        if (!this.animClips) return;
        const target = this.animClips[state] || this.animClips.idle;
        if (!target) return;
        for (const g of Object.values(this.animClips)) g && g !== target && g.stop();
        target.stop();
        target.play(true);
        switch (state) {
            case 'run': target.speedRatio = 1.6; break;
            case 'walk': target.speedRatio = 1.0; break;
            case 'swim': target.speedRatio = 0.8; break;
            default: target.speedRatio = 1.0; break;
        }
    },

    applySlopeAlignment(deltaTime) {
        if (!this.playerCat || this.isInWater || this.isJumping) return;
        const sampleOffset = 1;
        const x = this.playerCat.position.x;
        const z = this.playerCat.position.z;
        const hL = this.zoneManager.getHeightAtPosition(x - sampleOffset, z);
        const hR = this.zoneManager.getHeightAtPosition(x + sampleOffset, z);
        const hF = this.zoneManager.getHeightAtPosition(x, z + sampleOffset);
        const hB = this.zoneManager.getHeightAtPosition(x, z - sampleOffset);
        const dx = new Vector3(2*sampleOffset, hR - hL, 0);
        const dz = new Vector3(0, hF - hB, 2*sampleOffset);
        let normal = Vector3.Cross(dx, dz).normalize();
        if (!isFinite(normal.x) || !isFinite(normal.y) || normal.y < 0.2) return;
        const smoothing = 0.15;
        if (this.smoothedNormal) {
            normal = new Vector3(
                this.smoothedNormal.x + (normal.x - this.smoothedNormal.x) * smoothing,
                this.smoothedNormal.y + (normal.y - this.smoothedNormal.y) * smoothing,
                this.smoothedNormal.z + (normal.z - this.smoothedNormal.z) * smoothing
            ).normalize();
        }
        this.smoothedNormal = normal.clone();
        const yaw = this.characterRotation;
        const forward = new Vector3(Math.sin(yaw), 0, Math.cos(yaw));
        const right = Vector3.Cross(forward, normal).normalize();
        const realForward = Vector3.Cross(normal, right).normalize();
        let mat = Matrix.FromXYZAxes(right, normal, realForward);
        let targetQ = Quaternion.FromRotationMatrix(mat);
        const maxTiltDeg = 25;
        const maxTilt = maxTiltDeg * Math.PI / 180;
        const tilt = Math.acos(Math.min(1, Math.max(-1, normal.y)));
        if (tilt > maxTilt) {
            const up = new Vector3(0,1,0);
            const blend = (tilt - maxTilt) / tilt;
            normal = new Vector3(
                normal.x + (up.x - normal.x) * blend,
                normal.y + (up.y - normal.y) * blend,
                normal.z + (up.z - normal.z) * blend
            ).normalize();
            const right2 = Vector3.Cross(forward, normal).normalize();
            const realForward2 = Vector3.Cross(normal, right2).normalize();
            mat = Matrix.FromXYZAxes(right2, normal, realForward2);
            targetQ = Quaternion.FromRotationMatrix(mat);
        }
        if (!this.playerCat.rotationQuaternion) {
            this.playerCat.rotationQuaternion = targetQ;
            return;
        }
        Quaternion.SlerpToRef(
            this.playerCat.rotationQuaternion,
            targetQ,
            Math.min(1, deltaTime * 5),
            this.playerCat.rotationQuaternion
        );
        this.lastSlopeNormal = normal;
    },

    initDebugOverlay() {
        if (this.debugOverlayEl) return;
        const el = document.createElement('div');
        el.style.position = 'absolute';
        el.style.top = '8px';
        el.style.right = '8px';
        el.style.background = 'rgba(0,0,0,0.45)';
        el.style.color = '#fff';
        el.style.font = '12px monospace';
        el.style.padding = '6px 8px';
        el.style.borderRadius = '4px';
        el.style.pointerEvents = 'none';
        el.style.zIndex = 20;
        el.innerText = 'Debug overlay init';
        this.el.parentElement?.appendChild(el);
        this.debugOverlayEl = el;
        this.debugOverlayAccum = 0;
    },

    updateDebugOverlay(deltaTime, velocity) {
        if (!this.debugOverlayEl) this.initDebugOverlay();
        this.debugOverlayAccum += deltaTime;
        if (this.debugOverlayAccum < 0.25) return; // throttle 4Hz
        this.debugOverlayAccum = 0;
        const pos = this.playerCat?.position;
        const terrainHeight = this.zoneManager.getHeightAtPosition(pos.x, pos.z);
        const norm = this.lastSlopeNormal || new Vector3(0,1,0);
        const slopeDeg = (Math.acos(Math.min(1, Math.max(-1, norm.y))) * 180 / Math.PI).toFixed(1);
        this.debugOverlayEl.innerText = `Anim: ${this.animationState}\nVel: ${velocity.toFixed(2)}\nPos: ${pos.x.toFixed(1)},${pos.y.toFixed(1)},${pos.z.toFixed(1)}\nTerrainY: ${terrainHeight.toFixed(2)}\nWater: ${this.isInWater ? 'yes':'no'}\nSlope: ${slopeDeg}°`;
    },

    /**
     * Load crater lake decorative mesh if available
     */
    async loadCraterLakeMesh() {
        try {
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            await import('@babylonjs/loaders/glTF');
            const candidates = [
                { root: '/models/', file: 'CraterLake_Mesh_0_0.glb' },
                { root: '/assets/models/', file: 'CraterLake_Mesh_0_0.glb' },
                { root: '/assets/', file: 'CraterLake_Mesh_0_0.glb' },
                { root: '/', file: 'CraterLake_Mesh_0_0.glb' }
            ];
            for (const c of candidates) {
                try {
                    const res = await SceneLoader.ImportMeshAsync('', c.root, c.file, this.scene);
                    if (res.meshes && res.meshes.length) {
                        const meshRoot = res.meshes[0];
                        meshRoot.name = 'CraterLakeMesh';
                        meshRoot.position = new Vector3(0, 0, 0);
                        meshRoot.scaling = new Vector3(1, 1, 1);
                        console.log(`CraterLake mesh loaded from ${c.root}${c.file}`);
                        break;
                    }
                } catch (e) {
                    // Suppress repetitive logging; only log final failure
                    if (c === candidates[candidates.length - 1]) {
                        console.warn('CraterLake mesh not found in any candidate path');
                    }
                }
            }
        } catch (err) {
            console.warn('Optional crater lake mesh load failed:', err.message || err);
        }
    },

    /**
     * Play swimming animation
     */
    playSwimAnimation() {
        if (this.catAnimations && this.catAnimations.length > 1) {
            this.catAnimations.forEach(anim => anim.stop());
            this.catAnimations[1]?.play(true); // Assume swimming is second animation
        }
    },

    /**
     * Play walking animation
     */
    playWalkAnimation() {
        if (this.catAnimations && this.catAnimations.length > 0) {
            this.catAnimations.forEach(anim => anim.stop());
            this.catAnimations[0]?.play(true); // Assume walking/idle is first animation
        }
    },

    /**
     * Create name tag above character
     */
    async createNameTag(mesh, username) {
        try {
            // Import GUI system
            const GUI = await import('@babylonjs/gui/2D');
            
            // Create name tag plane
            const nameTagPlane = MeshBuilder.CreatePlane('nameTag', { width: 2, height: 0.5 }, this.scene);
            nameTagPlane.parent = mesh;
            nameTagPlane.position.y = 2; // Above cat
            nameTagPlane.billboardMode = MeshBuilder.BILLBOARDMODE_Y;
            
            // Create GUI texture
            const nameTagTexture = GUI.AdvancedDynamicTexture.CreateForMesh(nameTagPlane);
            
            // Create text block
            const nameText = new GUI.TextBlock();
            nameText.text = username;
            nameText.color = "white";
            nameText.fontSize = 60;
            nameText.outlineWidth = 4;
            nameText.outlineColor = "black";
            
            nameTagTexture.addControl(nameText);
            
        } catch (error) {
            console.error('Failed to create name tag:', error);
        }
    },

    /**
     * Setup multiplayer system for other users
     */
    setupMultiplayerSystem() {
        console.log('Setting up multiplayer system...');
        
        // Initialize with current server users
        this.updateServerUsers(this.serverUsers);
    },

    /**
     * Update other users from server data
     */
    updateServerUsers(serverUsers) {
        const currentUsername = this.getCurrentUsername();
        
        for (const user of serverUsers) {
            if (user.username !== currentUsername) {
                if (!this.users.has(user.username)) {
                    // New user - create their avatar
                    this.createOtherUserAvatar(user);
                } else {
                    // Existing user - update position
                    this.updateOtherUserPosition(user);
                }
            }
        }
        
        // Remove users that are no longer present
        const serverUsernames = new Set(serverUsers.map(u => u.username));
        for (const [username, userData] of this.users.entries()) {
            if (!serverUsernames.has(username)) {
                this.removeOtherUser(username);
            }
        }
    },

    /**
     * Create avatar for another user
     */
    async createOtherUserAvatar(user) {
        try {
            // Load cat model for other user
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            const result = await SceneLoader.ImportMeshAsync("", "/", "cat1.gltf", this.scene);
            
            if (result.meshes.length > 0) {
                const otherCat = result.meshes[0];
                otherCat.position = new Vector3(user.position.x, user.position.y, user.position.z);
                otherCat.scaling = new Vector3(2, 2, 2);
                
                // Different color for other players
                const material = new StandardMaterial(`other_cat_${user.username}`, this.scene);
                material.diffuseColor = new Color3(
                    Math.random() * 0.5 + 0.5,
                    Math.random() * 0.5 + 0.5,
                    Math.random() * 0.5 + 0.5
                );
                otherCat.material = material;
                
                // Add name tag
                await this.createNameTag(otherCat, user.username);
                
                // Store user data
                this.users.set(user.username, {
                    mesh: otherCat,
                    animations: result.animationGroups,
                    position: user.position,
                    targetPosition: new Vector3(user.position.x, user.position.y, user.position.z),
                    lastUpdateAt: performance.now()
                });
                
                console.log(`Created avatar for user: ${user.username}`);
            }
        } catch (error) {
            console.error(`Failed to create avatar for ${user.username}:`, error);
        }
    },

    /**
     * Update position of another user
     */
    updateOtherUserPosition(user) {
        const userData = this.users.get(user.username);
        if (userData && userData.mesh) {
            if (!userData.targetPosition) {
                userData.targetPosition = new Vector3(user.position.x, user.position.y, user.position.z);
                userData.mesh.position.copyFrom(userData.targetPosition);
            } else {
                userData.targetPosition.set(user.position.x, user.position.y, user.position.z);
            }
            userData.lastUpdateAt = performance.now();
        }
    },

    interpolateRemoteUsers(deltaTime) {
        for (const [username, data] of this.users.entries()) {
            if (!data.mesh || !data.targetPosition) continue;
            const mesh = data.mesh;
            // Interpolation factor tuned for ~60fps, adjust for delta
            const factor = 1 - Math.pow(0.88, deltaTime * 60); // frame-rate independent smoothing
            mesh.position = Vector3.Lerp(mesh.position, data.targetPosition, factor);
        }
    },

    /**
     * Remove another user's avatar
     */
    removeOtherUser(username) {
        const userData = this.users.get(username);
        if (userData && userData.mesh) {
            userData.mesh.dispose();
            this.users.delete(username);
            console.log(`Removed avatar for user: ${username}`);
        }
    },

    /**
     * Setup chat event handling (UI should already be created)
     */
    setupChatEventHandling() {
        console.log('Setting up chat event handling...');
        
        // Register LiveView pushed event handler (preferred over global window events)
        if (typeof this.handleEvent === 'function') {
            this.handleEvent('chat_message', (payload) => {
                this.addChatMessage(payload);
            });
        } else {
            // Fallback to legacy window event if hook API unavailable
            window.addEventListener('phx:chat_message', (e) => this.addChatMessage(e.detail));
        }

        // Initial system notice (if not already shown)
        if (!this.chatInitialized) {
            this.systemChat('CraterLake chat ready. Type /loc for position.');
            this.chatInitialized = true;
        }
    },

    /**
     * Setup chat system (legacy method - calls both UI and event setup)
     */
    setupChatSystem() {
        console.log('Setting up chat system...');
        
        // Create chat UI
        this.createChatUI();
        this.setupChatEventHandling();
    },

    /**
     * Create chat UI overlay
     */
    createChatUI() {
        // Create chat container
        const chatContainer = document.createElement('div');
        chatContainer.id = 'chat-container';
        chatContainer.style.cssText = `
            position: fixed;
            bottom: 20px;
            left: 20px;
            width: 400px;
            height: 300px;
            background: rgba(0, 0, 0, 0.8);
            border-radius: 8px;
            border: 1px solid #444;
            display: flex;
            flex-direction: column;
            font-family: monospace;
            z-index: 1000;
        `;
        
        // Chat messages area
        const messagesArea = document.createElement('div');
        messagesArea.id = 'chat-messages';
        messagesArea.style.cssText = `
            flex: 1;
            overflow-y: auto;
            padding: 10px;
            color: white;
            font-size: 12px;
        `;
        
        // Chat input area
        const inputArea = document.createElement('div');
        inputArea.style.cssText = `
            padding: 10px;
            border-top: 1px solid #444;
            display: flex;
        `;
        
        const chatInput = document.createElement('input');
        chatInput.id = 'chat-input';
        chatInput.type = 'text';
        chatInput.placeholder = 'Type a message...';
        chatInput.style.cssText = `
            flex: 1;
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid #666;
            border-radius: 4px;
            padding: 8px;
            color: white;
            font-family: inherit;
        `;
        
        const sendButton = document.createElement('button');
        sendButton.textContent = 'Send';
        sendButton.style.cssText = `
            margin-left: 8px;
            padding: 8px 16px;
            background: #10B981;
            border: none;
            border-radius: 4px;
            color: white;
            cursor: pointer;
            font-family: inherit;
        `;
        
        // Event handlers
        const sendMessage = () => {
            const message = chatInput.value.trim();
            if (message) {
                this.sendChatMessage(message);
                chatInput.value = '';
            }
        };
        
        sendButton.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            sendMessage();
        });
        chatInput.addEventListener('keypress', (e) => {
            e.stopPropagation(); // Prevent bubbling
            e.stopImmediatePropagation();
            if (e.key === 'Enter') {
                e.preventDefault(); // Prevent form submission/page navigation
                sendMessage();
            }
        });
        
        // Assemble UI
        inputArea.appendChild(chatInput);
        inputArea.appendChild(sendButton);
        chatContainer.appendChild(messagesArea);
        chatContainer.appendChild(inputArea);
        
        // Add to page
        document.body.appendChild(chatContainer);
        
        this.chatContainer = chatContainer;
        this.messagesArea = messagesArea;
    },

    /**
     * Add chat message to UI
     */
    addChatMessage(messageData) {
        if (!this.messagesArea) return;
        
        const messageDiv = document.createElement('div');
        messageDiv.style.cssText = `
            margin-bottom: 8px;
            padding: 4px;
            border-radius: 4px;
            background: rgba(255, 255, 255, 0.05);
        `;
        
        const timestamp = new Date(messageData.timestamp || Date.now()).toLocaleTimeString();
        if (messageData.system) {
            messageDiv.innerHTML = `
                <span style="color: #666; font-size: 10px;">${timestamp}</span>
                <span style="color: #FBBF24; font-weight: bold;">[system]</span>
                <span style="color: #DDD; font-style: italic;">${messageData.message}</span>
            `;
        } else {
            messageDiv.innerHTML = `
                <span style="color: #888; font-size: 10px;">${timestamp}</span>
                <span style="color: #60A5FA; font-weight: bold;">${messageData.username}:</span>
                <span style="color: white;">${messageData.message}</span>
            `;
        }
        
        this.messagesArea.appendChild(messageDiv);
        this.messagesArea.scrollTop = this.messagesArea.scrollHeight;

        // Scrollback limit
        const limit = 300;
        const children = this.messagesArea.children;
        while (children.length > limit) {
            this.messagesArea.removeChild(children[0]);
        }
    },

    /**
     * Post a system (non-user) chat message
     */
    systemChat(message) {
        this.addChatMessage({
            username: '[system]',
            message,
            system: true,
            timestamp: Date.now()
        });
    },

    /**
     * Create chat message to server
     */
    sendChatMessage(message) {
        // Handle chat commands
        if (message.startsWith('/loc')) {
            if (this.playerCat) {
                const pos = this.playerCat.position;
                this.systemChat(`Position: ${pos.x.toFixed(1)}, ${pos.y.toFixed(1)}, ${pos.z.toFixed(1)}`);
            } else {
                this.systemChat('Position unavailable - character not loaded.');
            }
            return;
        }
        
        this.pushEventToPhoenix('send_chat_message', {
            message: message,
            username: this.getCurrentUsername(),
            position: this.playerCat ? {
                x: this.playerCat.position.x,
                y: this.playerCat.position.y,
                z: this.playerCat.position.z
            } : { x: 0, y: 0, z: 0 }
        });
    },

    /**
     * Send position update to server
     */
    sendPositionUpdate() {
        if (!this.playerCat) return;
        
        // Throttle position updates
        const now = Date.now();
        if (now - (this.lastPositionUpdate || 0) < 100) return; // 10 FPS max
        
        this.lastPositionUpdate = now;
        
        this.pushEventToPhoenix('update_position', {
            x: this.playerCat.position.x,
            y: this.playerCat.position.y,
            z: this.playerCat.position.z
        });
    },

    /**
     * Helper to push events to Phoenix LiveView
     */
    pushEventToPhoenix(eventName, data) {
        // Prefer hook API if available (Phoenix >= 1.7 provides pushEvent inside hooks)
        try {
            if (typeof this.pushEvent === 'function') {
                this.pushEvent(eventName, data);
                return;
            }
            // Fallback: legacy manual view lookup
            if (window.liveSocket) {
                const viewEl = document.querySelector('[data-phx-main]');
                if (viewEl && viewEl.__view__) {
                    viewEl.__view__.pushEvent(eventName, data);
                }
            }
        } catch (e) {
            console.warn('pushEventToPhoenix failed', e);
        }
    },

    /**
     * Get current username
     */
    getCurrentUsername() {
        return this.userData.username || 'Anonymous';
    },

    /**
     * Show loading indicator
     */
    showLoadingIndicator() {
        // Overlay removed – no-op retained for legacy callers
    },

    /**
     * Hide loading indicator
     */
    hideLoadingIndicator() {
        // No-op - overlay removed
    },

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Prevent all default key behaviors that could cause page reload
        document.addEventListener('keydown', (e) => {
            // Prevent space, arrow keys, page up/down, home/end from scrolling/navigating
            if ([' ', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'PageUp', 'PageDown', 'Home', 'End'].includes(e.key)) {
                e.preventDefault();
            }
            // Prevent common shortcut keys when canvas has focus
            if (document.activeElement === this.el) {
                e.preventDefault();
            }
        }, true);
        
        // Handle window events
        window.addEventListener('resize', () => {
            if (this.engine) {
                this.engine.resize();
            }
        });
        
        // Handle focus/blur for performance
        window.addEventListener('blur', () => {
            if (this.engine) {
                this.engine.stopRenderLoop();
            }
        });
        
        window.addEventListener('focus', () => {
            if (this.engine) {
                this.engine.runRenderLoop(() => {
                    this.scene.render();
                });
            }
        });
    },

    /**
     * Cleanup resources
     */
    cleanup() {
        console.log('Cleaning up open world lobby...');
        
        // Cleanup chat UI
        if (this.chatContainer) {
            this.chatContainer.remove();
        }
        
        // Cleanup zone manager
        if (this.zoneManager) {
            this.zoneManager.dispose();
        }
        
        // Cleanup Babylon.js
        if (this.scene) {
            this.scene.dispose();
        }
        
        if (this.engine) {
            this.engine.dispose();
        }
    }
};

/**
 * Custom heightmap provider for CraterLake
 */
class CraterLakeHeightmapProvider {
    constructor(options = {}) {
        this.heightmapData = null;
        this.options = {
            heightmapPath: '/assets/terrain/heightmaps/NewCratorProject_HeightMap_1024x1024_0_0.png',
            fallbackPaths: [
                '/models/NewCratorProject_HeightMap_1024x1024_0_0.png',
                '/assets/NewCratorProject_HeightMap_1024x1024_0_0.png'
            ],
            ...options
        };
    }
    
    setStreamingSystem(system) {
        this.streamingSystem = system;
    }
    
    async loadChunk(chunkCoords) {
        // Load the CraterLake heightmap data if not already loaded
        if (!this.heightmapData) {
            await this.loadCraterLakeHeightmap();
        }
        
        // Generate mesh from heightmap data for this chunk
        return this.generateChunkFromHeightmap(chunkCoords);
    }
    
    async loadCraterLakeHeightmap() {
        const candidatePaths = [
            this.options.heightmapPath,
            ...this.options.fallbackPaths
        ];
        
        for (const path of candidatePaths) {
            try {
                console.log(`Attempting to load heightmap from: ${path}`);
                
                // Create an image element to load the PNG heightmap
                const img = new Image();
                img.crossOrigin = 'anonymous';
                
                await new Promise((resolve, reject) => {
                    img.onload = () => resolve();
                    img.onerror = () => reject(new Error(`Failed to load image: ${path}`));
                    img.src = path;
                });
                
                // Create canvas to read pixel data
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');
                canvas.width = img.width;
                canvas.height = img.height;
                
                // Draw image to canvas
                ctx.drawImage(img, 0, 0);
                
                // Get image data
                const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                const pixels = imageData.data;
                
                // Convert pixel data to height values
                const numPixels = canvas.width * canvas.height;
                const heights = new Float32Array(numPixels);
                
                for (let i = 0; i < numPixels; i++) {
                    const pixelIndex = i * 4; // RGBA
                    // Use red channel for height (0-255) and convert to world height (0-200)
                    heights[i] = (pixels[pixelIndex] / 255) * 200;
                }
                
                this.heightmapData = {
                    width: canvas.width,
                    height: canvas.height,
                    heights: heights
                };
                
                console.log(`✅ CraterLake heightmap loaded successfully from ${path} (${canvas.width}x${canvas.height})`);
                return;
                
            } catch (error) {
                console.log(`Failed to load heightmap from ${path}:`, error.message);
                continue;
            }
        }
        
        // If all paths failed, create fallback
        console.warn('All heightmap paths failed, creating fallback flat terrain');
        this.heightmapData = {
            width: 1024,
            height: 1024,
            heights: new Float32Array(1024 * 1024).fill(50) // Flat at water level
        };
    }
    
    generateChunkFromHeightmap(chunkCoords) {
        // Implementation would extract the relevant portion of the heightmap
        // for this chunk and generate a mesh
        // This is a simplified version - the full implementation would be more complex
        
        const chunkSize = this.streamingSystem.options.chunkSize;
        const worldPos = this.streamingSystem.chunkToWorldCoords(chunkCoords);
        
        // Create simple terrain mesh for now
        const mesh = MeshBuilder.CreateGround(`craterlake_${chunkCoords.x}_${chunkCoords.y}`, {
            width: chunkSize,
            height: chunkSize,
            subdivisions: 32
        }, this.streamingSystem.scene);
        
        mesh.position.copyFrom(worldPos);
        
        // Apply crater lake material
        const material = new StandardMaterial(`craterlake_mat_${chunkCoords.x}_${chunkCoords.y}`, this.streamingSystem.scene);
        material.diffuseColor = new Color3(0.4, 0.3, 0.2); // Rocky crater color
        mesh.material = material;
        
        return {
            mesh: mesh,
            material: material,
            chunkCoords: chunkCoords,
            worldPosition: worldPos,
            type: 'craterlake_heightmap'
        };
    }
}