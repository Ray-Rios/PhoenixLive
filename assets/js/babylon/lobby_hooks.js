import { 
    Engine, Scene, Vector3, Vector2, Color3, Color4,
    FreeCamera, ArcRotateCamera, UniversalCamera,
    HemisphericLight, DirectionalLight,
    MeshBuilder, StandardMaterial, PBRMaterial,
    Animation, AnimationGroup,
    ActionManager, ExecuteCodeAction, PointerEventTypes
} from './babylon_imports';

// Import camera controls directly - needed for attachToCanvas method
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraPointersInput';
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraKeyboardMoveInput';
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraMouseWheelInput';

import { BabylonLazyLoader } from './lazy_loader';
import { ZoneManager } from './zone_manager';

/**
 * Lobby Scene Hook - 3D Character Selection & Desktop Interface
 */
export const LobbyScene = {
    mounted() {
        console.log('LobbyScene hook mounted');
        this.el._babylonHook = this;

        this.showLoadingIndicator();
        // Added: resolution integrity tracking + helpers
        this._lastDPR = window.devicePixelRatio || 1;
        this._lastCanvasClientW = 0;
        this._lastCanvasClientH = 0;
        this._framesSinceLastIntegrityCheck = 0;
        this.debouncedResize = (() => {
            let rafId = null;
            return () => {
                if (rafId) cancelAnimationFrame(rafId);
                rafId = requestAnimationFrame(() => {
                    if (this.engine) {
                        try {
                            this.engine.setHardwareScalingLevel(1 / (window.devicePixelRatio || 1));
                            this.engine.resize();
                        } catch (e) {
                            console.debug('Lobby resize failed (ignored):', e);
                        }
                    }
                });
            };
        })();
        this.visibilityHandler = () => {
            if (document.visibilityState === 'visible') {
                setTimeout(() => this.debouncedResize(), 60);
            }
        };
        document.addEventListener('visibilitychange', this.visibilityHandler);
        this.pageLoadingStopHandler = () => this.debouncedResize();
        window.addEventListener('phx:page-loading-stop', this.pageLoadingStopHandler);

        this.initializeLobbyScene()
            .then(() => {
                this.hideLoadingIndicator();
                this.setupEventListeners();
            })
            .catch(error => {
                this.hideLoadingIndicator();
                console.error('Failed to initialize lobby scene:', error);
            });
    },

    updated() {
        console.log('LobbyScene hook updated');
        this.handleServerUpdates();
    },

    destroyed() {
        console.log('LobbyScene hook destroyed');
        this.cleanup();
    },

    /**
     * Initialize the 3D lobby scene
     */
    async initializeLobbyScene() {
        // Canvas setup
        this.canvas = this.el;
        const container = this.canvas.parentElement;
        this.canvas.width = container.clientWidth;
        this.canvas.height = container.clientHeight;
        this._lastCanvasClientW = this.canvas.clientWidth;
        this._lastCanvasClientH = this.canvas.clientHeight;

        // Engine with optimized settings
        this.engine = new Engine(this.canvas, true, {
            preserveDrawingBuffer: true,
            stencil: true,
            antialias: true,
            adaptToDeviceRatio: true
        });

        // Create scene
        this.scene = new Scene(this.engine);
        this.babylon = { 
            Engine, Scene, Vector3, Vector2, Color3, Color4,
            FreeCamera, ArcRotateCamera, UniversalCamera,
            HemisphericLight, DirectionalLight,
            MeshBuilder, StandardMaterial, PBRMaterial,
            Animation, AnimationGroup, ActionManager, ExecuteCodeAction 
        };

        // Setup camera (first-person view for lobby)
        this.camera = new UniversalCamera("lobbyCamera", new Vector3(0, 1.6, -5), this.scene);
        this.camera.setTarget(Vector3.Zero());

        // Lighting
        this.light = new HemisphericLight("lobbyLight", new Vector3(1, 1, 0), this.scene);
        this.light.intensity = 0.7;

        // Initialize zone manager
        this.zoneManager = new ZoneManager(this);

        // Load character controller
        const { CharacterController } = await import('./character_controller');
        await this.zoneManager.loadZone('lobby');
        this.characterController = new CharacterController(this.scene, this.camera);

        // Start render loop with integrity checks
        const integrityEvery = 10;
        this.engine.runRenderLoop(() => {
            if (this.scene && this.scene.activeCamera) {
                if (++this._framesSinceLastIntegrityCheck >= integrityEvery) {
                    this._framesSinceLastIntegrityCheck = 0;
                    this.ensureResolutionIntegrity(this.canvas);
                }
                this.scene.render();
            }
        });

        // Debounced resize listener
        this.resizeHandler = () => this.debouncedResize();
        window.addEventListener('resize', this.resizeHandler);

        console.log('Lobby scene initialized with zone system');
    },

    // Added: resolution integrity
    ensureResolutionIntegrity(canvas) {
        if (!this.engine || !canvas) return;
        const dpr = window.devicePixelRatio || 1;
        const cw = canvas.clientWidth || this._lastCanvasClientW;
        const ch = canvas.clientHeight || this._lastCanvasClientH;
        const expectedW = Math.round(cw * dpr);
        const expectedH = Math.round(ch * dpr);
        const currentW = this.engine.getRenderWidth();
        const currentH = this.engine.getRenderHeight();
        let changed = false;
        if (dpr !== this._lastDPR) {
            this.engine.setHardwareScalingLevel(1 / dpr);
            this._lastDPR = dpr;
            changed = true;
        }
        if (cw !== this._lastCanvasClientW || ch !== this._lastCanvasClientH) {
            this._lastCanvasClientW = cw;
            this._lastCanvasClientH = ch;
            changed = true;
        }
        if (currentW !== expectedW || currentH !== expectedH) {
            changed = true;
        }
        if (changed) {
            try {
                this.engine.resize();
            } catch (e) {
                console.debug('Engine resize skipped (lobby transient):', e);
            }
        }
    },

    /**
     * Move character to specific position (used by zone manager)
     */
    moveCharacterTo(x, y, z) {
        if (this.characterController) {
            this.characterController.moveCharacterTo(x, y, z);
        }
    },

    /**
     * Show loading indicator
     */
    showLoadingIndicator(message = 'Loading...') {
        // Create or update loading overlay
        if (!this.loadingOverlay) {
            this.loadingOverlay = document.createElement('div');
            this.loadingOverlay.className = 'babylon-loading-overlay';
            this.loadingOverlay.style.cssText = `
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.8);
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
                font-family: Arial, sans-serif;
                z-index: 1000;
            `;
            this.loadingOverlay.innerHTML = `
                <div class="loading-content">
                    <div class="loading-spinner" style="
                        border: 4px solid #f3f3f3;
                        border-top: 4px solid #3498db;
                        border-radius: 50%;
                        width: 40px;
                        height: 40px;
                        animation: spin 2s linear infinite;
                        margin: 0 auto 20px;
                    "></div>
                    <div class="loading-text">${message}</div>
                </div>
            `;
            // Add CSS animation
            const style = document.createElement('style');
            style.textContent = `
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            `;
            document.head.appendChild(style);
            
            this.el.parentElement.appendChild(this.loadingOverlay);
        } else {
            this.loadingOverlay.querySelector('.loading-text').textContent = message;
            this.loadingOverlay.style.display = 'flex';
        }
    },

    /**
     * Hide loading indicator
     */
    hideLoadingIndicator() {
        if (this.loadingOverlay) {
            this.loadingOverlay.style.display = 'none';
        }
    },

    /**
     * Handle Phoenix server updates
     */
    handleServerUpdates() {
        // Handle any server-side updates here
        console.log('Handling server updates');
    },

    /**
     * Setup event listeners for Phoenix communication
     */
    setupEventListeners() {
        // Listen for zone change commands from server
        this.handleEvent('change_zone', (payload) => {
            this.zoneManager.loadZone(payload.zone, payload.spawn_point);
        });

        // Listen for other player movements (future multiplayer)
        this.handleEvent('player_moved', (payload) => {
            console.log('Other player moved:', payload);
        });
    },

    /**
     * Handle errors
     */
    handleError(type, data) {
        console.error(`Babylon error (${type}):`, data);
        
        // Send error to Phoenix
        this.pushEvent('babylon_error', {
            type: type,
            data: data,
            timestamp: Date.now()
        });
    },

    /**
     * Clean up resources
     */
    cleanup() {
        if (this.characterController) {
            this.characterController.dispose();
        }

        if (this.zoneManager) {
            // Clean up all loaded zones
            const zones = this.zoneManager.listAvailableZones();
            zones.forEach(zoneName => {
                if (this.zoneManager.loadedZones && this.zoneManager.loadedZones.has(zoneName)) {
                    this.zoneManager.unloadZone(zoneName);
                }
            });
        }

        if (this.scene) {
            this.scene.dispose();
        }

        if (this.engine) {
            this.engine.dispose();
        }

        if (this.loadingOverlay) {
            this.loadingOverlay.remove();
        }

        // Remove resize listener
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this.visibilityHandler) { document.removeEventListener('visibilitychange', this.visibilityHandler); this.visibilityHandler = null; }
        if (this.pageLoadingStopHandler) { window.removeEventListener('phx:page-loading-stop', this.pageLoadingStopHandler); this.pageLoadingStopHandler = null; }
    },

    // Handle presence updates from Phoenix
    handleEvent(event, payload) {
        if (event === "update_users") {
            this.updateUserPresence(payload.users);
        }
    },

    updateUserPresence(users) {
        // Clear existing user meshes
        if (this.userMeshes) {
            this.userMeshes.forEach(mesh => mesh.dispose());
        }
        this.userMeshes = [];

        // Create new user meshes with name labels
        users.forEach(user => {
            if (user.username && user.position) {
                this.createUserMesh(user);
            }
        });
    },

    createUserMesh(user) {
        const { MeshBuilder, StandardMaterial, Color3 } = this.babylon;
        
        // Create user representation (simple cylinder for now)
        const userMesh = MeshBuilder.CreateCylinder(`user_${user.username}`, {
            height: 1.8,
            diameter: 0.5
        }, this.scene);

        // Position the user
        userMesh.position.x = user.position.x;
        userMesh.position.y = user.position.y + 0.9; // Half height
        userMesh.position.z = user.position.z;

        // Create material
        const material = new StandardMaterial(`userMat_${user.username}`, this.scene);
        material.diffuseColor = new Color3(0.3, 0.6, 0.9);
        userMesh.material = material;

        // Create name label (using Babylon GUI)
        this.createNameLabel(user.username, userMesh);

        this.userMeshes.push(userMesh);
    },

    createNameLabel(username, mesh) {
        // TODO: Implement text labels above users
        // For now, we'll use console logging when players move
        console.log(`User ${username} is in the lobby`);
    },

    // Send position updates to Phoenix
    updatePlayerPosition(x, y, z) {
        this.pushEvent("update_position", { x, y, z });
    }
};