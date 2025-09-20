import { 
    Engine, Scene, Vector3, Vector2, Color3, Color4,
    FreeCamera, ArcRotateCamera, UniversalCamera,
    HemisphericLight, DirectionalLight,
    MeshBuilder, StandardMaterial, PBRMaterial,
    Animation, AnimationGroup,
    ActionManager, ExecuteCodeAction
} from './babylon_imports';
import { BabylonLazyLoader } from './lazy_loader';
import { ZoneManager } from './zone_manager';

// Only load these when needed
let GUI = null;
let HavokPhysics = null;

/**
 * Lobby Scene Hook - 3D Character Selection & Desktop Interface
 */
export const LobbyScene = {
    mounted() {
        console.log('LobbyScene hook mounted');
        this.el._babylonHook = this;

        this.showLoadingIndicator();
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

        // Engine with optimized settings
        this.engine = new Engine(this.canvas, true, {
            preserveDrawingBuffer: true,
            stencil: true,
            antialias: true,
            adaptToDeviceRatio: true
        });

        // Create scene
        this.scene = new Scene(this.engine);
        this.babylon = { Engine, Scene, Vector3, Vector2, Color3, Color4,
            FreeCamera, ArcRotateCamera, UniversalCamera,
            HemisphericLight, DirectionalLight,
            MeshBuilder, StandardMaterial, PBRMaterial,
            Animation, AnimationGroup, ActionManager, ExecuteCodeAction };

        // Setup camera (third-person view for lobby)
        this.camera = new ArcRotateCamera("lobbyCamera", 
            -Math.PI / 2, Math.PI / 2.5, 8, Vector3.Zero(), this.scene);
        this.camera.setTarget(Vector3.Zero());
        this.camera.attachToCanvas(this.canvas, true);

        // Lighting
        this.light = new HemisphericLight("lobbyLight", new Vector3(1, 1, 0), this.scene);
        this.light.intensity = 0.7;

        // Initialize zone manager
        this.zoneManager = new ZoneManager(this);

        // Load character controller
        const { CharacterController } = await import('./character_controller');
        
        // Load default lobby zone
        await this.zoneManager.loadZone('lobby');

        // Create character controller
        this.characterController = new CharacterController(this.scene, this.camera);

        // Start render loop
        this.engine.runRenderLoop(() => {
            this.scene.render();
        });

        // Handle resize
        window.addEventListener('resize', () => {
            this.engine.resize();
        });

        console.log('Lobby scene initialized with zone system');
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
            this.loadingOverlay.innerHTML = `
                <div class="loading-content">
                    <div class="loading-spinner"></div>
                    <div class="loading-text">${message}</div>
                </div>
            `;
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
            this.zoneManager.listAvailableZones().forEach(zoneName => {
                this.zoneManager.unloadZone(zoneName);
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
        window.removeEventListener('resize', this.resizeHandler);
    }
};

            // Enable interactions for loaded meshes
            result.meshes.forEach(mesh => {
                if (mesh.metadata?.interactive) {
                    mesh.isPickable = true;
                }
            });

            return result;
        } catch (error) {
            console.error('Failed to load editor scene:', error);
            throw error;
        }
    },

    /**
     * Fallback environment when editor scene fails
     */
    setupFallbackEnvironment() {
        this.setupLobbyEnvironment();
        this.setupCharacterArea();
        this.setupDesktopArea();
    },

    /**
     * Setup the main lobby environment (fallback)
     */
    setupLobbyEnvironment() {
        console.log('Setting up lobby environment...');

        // Lighting
        const hemi = new BABYLON.HemisphericLight('hemi', new BABYLON.Vector3(0, 1, 0), this.scene);
        hemi.intensity = 0.6;

        const dir = new BABYLON.DirectionalLight('dir', new BABYLON.Vector3(-1, -1, -1), this.scene);
        dir.intensity = 0.8;

        // Main platform
        const platform = BABYLON.MeshBuilder.CreateCylinder('platform', {
            diameter: 20, height: 0.5
        }, this.scene);
        platform.position.y = -0.25;

        const platformMat = new BABYLON.StandardMaterial('platformMat', this.scene);
        platformMat.diffuseColor = new BABYLON.Color3(0.2, 0.3, 0.4);
        platformMat.specularColor = new BABYLON.Color3(0.1, 0.1, 0.1);
        platform.material = platformMat;

        // Skybox
        const skybox = BABYLON.MeshBuilder.CreateSphere('skybox', { diameter: 100 }, this.scene);
        const skyboxMat = new BABYLON.StandardMaterial('skyboxMat', this.scene);
        skyboxMat.diffuseColor = new BABYLON.Color3(0.1, 0.2, 0.4);
        skyboxMat.disableLighting = true;
        skyboxMat.backFaceCulling = false;
        skybox.material = skyboxMat;
        skybox.infiniteDistance = true;

        // Ambient particles for atmosphere
        this.createAmbientParticles();
    },

    /**
     * Setup character selection area
     */
    setupCharacterArea() {
        console.log('Setting up character area...');

        // Character pedestal
        const pedestal = BABYLON.MeshBuilder.CreateCylinder('character_pedestal', {
            diameter: 3, height: 0.3
        }, this.scene);
        pedestal.position.set(0, 0.15, -3);

        const pedestalMat = new BABYLON.StandardMaterial('pedestalMat', this.scene);
        pedestalMat.diffuseColor = new BABYLON.Color3(0.8, 0.8, 0.9);
        pedestalMat.emissiveColor = new BABYLON.Color3(0.1, 0.1, 0.2);
        pedestal.material = pedestalMat;

        // Trigger zone for character select
        const trigger = BABYLON.MeshBuilder.CreateBox('character_select_trigger', {
            width: 4, height: 3, depth: 4
        }, this.scene);
        trigger.position.set(0, 1.5, -3);
        trigger.visibility = 0.1; // Nearly invisible
        trigger.isPickable = true;
        trigger.metadata = { interactive: true };

        // Placeholder character (will be replaced with actual character model)
        this.createPlaceholderCharacter();
    },

    /**
     * Setup desktop/panel area
     */
    setupDesktopArea() {
        console.log('Setting up desktop area...');

        // Desktop platform
        const desktop = BABYLON.MeshBuilder.CreateBox('desktop_platform', {
            width: 12, height: 0.2, depth: 8
        }, this.scene);
        desktop.position.set(0, 0.1, 3);

        const desktopMat = new BABYLON.StandardMaterial('desktopMat', this.scene);
        desktopMat.diffuseColor = new BABYLON.Color3(0.1, 0.1, 0.2);
        desktopMat.emissiveColor = new BABYLON.Color3(0.05, 0.05, 0.1);
        desktop.material = desktopMat;

        // Desktop trigger
        const desktopTrigger = BABYLON.MeshBuilder.CreateBox('desktop_trigger', {
            width: 12, height: 2, depth: 8
        }, this.scene);
        desktopTrigger.position.set(0, 1, 3);
        desktopTrigger.visibility = 0.1;
        desktopTrigger.isPickable = true;
        desktopTrigger.metadata = { interactive: true };

        // Initialize panel system
        this.panels = new Map();
        this.setupPanelSystem();
    },

    /**
     * Create placeholder character
     */
    createPlaceholderCharacter() {
        // Simple character representation
        const body = BABYLON.MeshBuilder.CreateCylinder('character_body', {
            diameter: 0.8, height: 1.5
        }, this.scene);
        body.position.set(0, 0.9, -3);

        const head = BABYLON.MeshBuilder.CreateSphere('character_head', {
            diameter: 0.4
        }, this.scene);
        head.position.set(0, 1.8, -3);

        const charMat = new BABYLON.StandardMaterial('characterMat', this.scene);
        charMat.diffuseColor = new BABYLON.Color3(0.8, 0.6, 0.4); // Skin tone
        body.material = charMat;
        head.material = charMat;

        // Store character parts for customization
        this.characterParts = { body, head };
    },

    /**
     * Setup 3D panel system for LiveView content
     */
    setupPanelSystem() {
        console.log('Setting up panel system...');

        // This will create 3D panels that can display LiveView content
        this.panelMaterial = new BABYLON.StandardMaterial('panelMat', this.scene);
        this.panelMaterial.diffuseColor = new BABYLON.Color3(0.9, 0.9, 0.9);
        this.panelMaterial.emissiveColor = new BABYLON.Color3(0.1, 0.1, 0.1);
        this.panelMaterial.backFaceCulling = false;
    },

    /**
     * Create a 3D panel for LiveView content
     */
    createPanel(panelData) {
        console.log('Creating panel:', panelData.id);

        const panel = BABYLON.MeshBuilder.CreatePlane(`panel_${panelData.id}`, {
            width: 4, height: 3
        }, this.scene);

        panel.position.set(
            panelData.position.x,
            panelData.position.y,
            panelData.position.z
        );

        // Create dynamic texture for LiveView content
        const dynamicTexture = new BABYLON.DynamicTexture(`panelTexture_${panelData.id}`, {
            width: 800, height: 600
        }, this.scene);

        const panelMat = this.panelMaterial.clone(`panelMat_${panelData.id}`);
        panelMat.diffuseTexture = dynamicTexture;
        panel.material = panelMat;

        // Make panel interactive
        panel.isPickable = true;
        panel.metadata = {
            interactive: true,
            panelId: panelData.id,
            panelData: panelData
        };

        // Store panel reference
        this.panels.set(panelData.id, {
            mesh: panel,
            texture: dynamicTexture,
            data: panelData
        });

        // Start capturing LiveView content
        this.captureIframeContent(panelData.id);

        return panel;
    },

    /**
     * Capture iframe content and render to 3D panel
     */
    captureIframeContent(panelId) {
        const iframe = document.getElementById(`panel-content-${panelId}`);
        const panel = this.panels.get(panelId);

        if (!iframe || !panel) return;

        // Use html2canvas or similar to capture iframe content
        // For now, we'll create a placeholder texture
        const ctx = panel.texture.getContext();
        ctx.fillStyle = '#1a1a2e';
        ctx.fillRect(0, 0, 800, 600);

        ctx.fillStyle = '#16213e';
        ctx.fillRect(20, 20, 760, 560);

        ctx.fillStyle = '#ffffff';
        ctx.font = '24px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(panel.data.title, 400, 300);

        ctx.font = '16px Arial';
        ctx.fillText('LiveView Content Here', 400, 340);
        ctx.fillText(`Route: ${panel.data.route}`, 400, 370);

        panel.texture.update();
    },

    /**
     * Create ambient particles
     */
    createAmbientParticles() {
        const particleSystem = new BABYLON.ParticleSystem('ambient', 2000, this.scene);
        particleSystem.particleTexture = new BABYLON.Texture('https://playground.babylonjs.com/textures/flare.png', this.scene);

        particleSystem.emitter = BABYLON.Vector3.Zero();
        particleSystem.minEmitBox = new BABYLON.Vector3(-10, 0, -10);
        particleSystem.maxEmitBox = new BABYLON.Vector3(10, 5, 10);

        particleSystem.color1 = new BABYLON.Color4(0.7, 0.8, 1.0, 0.1);
        particleSystem.color2 = new BABYLON.Color4(0.2, 0.5, 1.0, 0.1);
        particleSystem.colorDead = new BABYLON.Color4(0, 0, 0.2, 0.0);

        particleSystem.minSize = 0.1;
        particleSystem.maxSize = 0.5;
        particleSystem.minLifeTime = 5;
        particleSystem.maxLifeTime = 10;
        particleSystem.emitRate = 100;

        particleSystem.direction1 = new BABYLON.Vector3(-1, 1, -1);
        particleSystem.direction2 = new BABYLON.Vector3(1, 1, 1);
        particleSystem.minEmitPower = 0.2;
        particleSystem.maxEmitPower = 0.6;

        particleSystem.start();
    },

    /**
     * Setup camera controls and transitions
     */
    setupCameraControls() {
        this.camera = new BABYLON.ArcRotateCamera(
            'camera',
            -Math.PI / 2,
            Math.PI / 3,
            8,
            new BABYLON.Vector3(0, 0, 0),
            this.scene
        );

        this.camera.lowerRadiusLimit = 3;
        this.camera.upperRadiusLimit = 20;
        
        // Optimize camera settings to prevent blur
        this.camera.inertia = 0.9; // Smooth movement
        this.camera.angularSensibilityX = 1000;
        this.camera.angularSensibilityY = 1000;
        this.camera.wheelPrecision = 50;
        this.camera.pinchPrecision = 200;
        
        // Attach controls with no preventDefault to avoid conflicts
        this.camera.attachControl(this.canvas, false);

        // Smooth camera transitions
        this.cameraAnimations = new Map();
    },

    /**
     * Animate camera to position
     */
    animateCameraTo(position, target, duration = 1000) {
        const startPos = this.camera.position.clone();
        const startTarget = this.camera.target.clone();

        const targetPos = new BABYLON.Vector3(position.x, position.y, position.z);
        const targetTarget = new BABYLON.Vector3(target.x, target.y, target.z);

        const animationPos = BABYLON.Animation.CreateAndStartAnimation(
            'cameraPos', this.camera, 'position', 30, duration / 1000 * 30,
            startPos, targetPos, BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );

        const animationTarget = BABYLON.Animation.CreateAndStartAnimation(
            'cameraTarget', this.camera, 'target', 30, duration / 1000 * 30,
            startTarget, targetTarget, BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );
    },

    /**
     * Handle server updates
     */
    handleServerUpdates() {
        const sceneConfig = this.getSceneConfig();
        const userData = this.getUserData();
        const panelsData = this.getPanelsData();

        // Update camera based on mode
        if (sceneConfig.camera) {
            this.handleCameraUpdate(sceneConfig.camera);
        }

        // Update character customization
        if (userData.customization) {
            this.updateCharacterAppearance(userData.customization);
        }

        // Update panels
        if (panelsData) {
            this.updatePanels(panelsData);
        }
    },

    /**
     * Handle camera updates from server
     */
    handleCameraUpdate(cameraConfig) {
        const mode = cameraConfig.mode;
        const position = cameraConfig.position;
        const target = cameraConfig.target || { x: 0, y: 0, z: 0 };

        switch (mode) {
            case 'lobby':
                this.animateCameraTo({ x: 0, y: 2, z: 8 }, { x: 0, y: 0, z: 0 });
                break;
            case 'character_select':
                this.animateCameraTo({ x: 0, y: 1.5, z: 0 }, { x: 0, y: 1, z: -3 });
                break;
            case 'desktop':
                this.animateCameraTo({ x: 0, y: 1, z: 8 }, { x: 0, y: 1, z: 3 });
                break;
        }
    },

    /**
     * Update character appearance
     */
    updateCharacterAppearance(customization) {
        if (!this.characterParts) return;

        // Update skin tone
        const skinColors = {
            light: new BABYLON.Color3(0.9, 0.7, 0.6),
            medium: new BABYLON.Color3(0.8, 0.6, 0.4),
            dark: new BABYLON.Color3(0.6, 0.4, 0.3)
        };

        const skinColor = skinColors[customization.skin_tone] || skinColors.medium;
        this.characterParts.body.material.diffuseColor = skinColor;
        this.characterParts.head.material.diffuseColor = skinColor;
    },

    /**
     * Update 3D panels
     */
    updatePanels(panelsData) {
        // Remove panels that are no longer active
        this.panels.forEach((panel, panelId) => {
            const stillActive = panelsData.some(p => p.id === panelId);
            if (!stillActive) {
                panel.mesh.dispose();
                panel.texture.dispose();
                this.panels.delete(panelId);
            }
        });

        // Create new panels
        panelsData.forEach(panelData => {
            if (!this.panels.has(panelData.id)) {
                this.createPanel(panelData);
            } else {
                // Update existing panel content
                this.captureIframeContent(panelData.id);
            }
        });
    },

    /**
     * Event listeners
     */
    setupEventListeners() {
        if (!this.scene) return;

        this.scene.onPointerObservable.add((pi) => {
            if (pi.type === BABYLON.PointerEventTypes.POINTERUP && pi.pickInfo?.hit) {
                const mesh = pi.pickInfo.pickedMesh;

                if (mesh && mesh.metadata?.interactive) {
                    this.pushEvent("babylon_interaction", {
                        type: "click",
                        mesh: mesh.name,
                        panelId: mesh.metadata.panelId
                    });
                }
            }
        });

        this.scene.actionManager = new BABYLON.ActionManager(this.scene);
        this.scene.actionManager.registerAction(
            new BABYLON.ExecuteCodeAction(
                BABYLON.ActionManager.OnKeyDownTrigger,
                (evt) => {
                    this.pushEvent("babylon_key", { key: evt.sourceEvent.key });
                }
            )
        );
    },

    /**
     * Render loop with optimization
     */
    startRenderLoop() {
        let lastTime = 0;
        const targetFPS = 60;
        const frameTime = 1000 / targetFPS;
        
        this.engine.runRenderLoop(() => {
            const currentTime = performance.now();
            
            if (this.scene && this.scene.activeCamera) {
                // Throttle rendering to prevent blur during rapid updates
                if (currentTime - lastTime >= frameTime) {
                    this.scene.render();
                    lastTime = currentTime;
                } else {
                    // Still render but less frequently during camera movement
                    this.scene.render();
                }
            }
        });
    },

    /**
     * Loading indicator
     */
    showLoadingIndicator() {
        this.el.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: center; 
                        width: 100%; height: 100%; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
                <div style="text-align: center;">
                    <div style="width: 60px; height: 60px; border: 4px solid rgba(255,255,255,0.3); 
                                border-top: 4px solid #fff; border-radius: 50%; 
                                animation: spin 1s linear infinite; margin: 0 auto 30px;"></div>
                    <div style="font-size: 24px; margin-bottom: 10px;">Entering the Lobby</div>
                    <div style="font-size: 14px; opacity: 0.8;">Initializing 3D environment...</div>
                </div>
            </div>
            <style>
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            </style>
        `;
    },

    hideLoadingIndicator() {
        this.el.innerHTML = '';
    },

    /**
     * Data getters
     */
    getSceneConfig() {
        try {
            return JSON.parse(this.el.dataset.sceneConfig || '{}');
        } catch {
            return {};
        }
    },

    getUserData() {
        try {
            return JSON.parse(this.el.dataset.user || '{}');
        } catch {
            return {};
        }
    },

    getPanelsData() {
        try {
            return JSON.parse(this.el.dataset.panels || '[]');
        } catch {
            return [];
        }
    },

    /**
     * Cleanup
     */
    cleanup() {
        try {
            if (this.resizeHandler) {
                window.removeEventListener('resize', this.resizeHandler);
            }
            if (this.engine) {
                this.engine.stopRenderLoop();
                this.engine.dispose();
            }
            this.scene?.dispose();
            this.panels?.forEach(panel => {
                panel.mesh.dispose();
                panel.texture.dispose();
            });
        } catch (err) {
            console.error("Cleanup error:", err);
        }
    }
};