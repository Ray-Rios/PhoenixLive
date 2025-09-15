import * as BABYLON from '@babylonjs/core';
import '@babylonjs/loaders/glTF';
import * as GUI from '@babylonjs/gui/2D';
import HavokPhysics from '@babylonjs/havok';
import { BabylonAssetManager } from './babylon_asset_manager';
import { BabylonFallbackManager } from './babylon_fallbacks';
import { BabylonSceneLoader } from './babylon_scene_loader';

/**
 * Main Babylon.js LiveView Hook
 */
export const BabylonScene = {
    mounted() {
        console.log('BabylonScene hook mounted');
        this.el._babylonHook = this;

        // Show loading indicator
        this.showLoadingIndicator();

        this.initializeBabylonScene()
            .then(() => {
                this.hideLoadingIndicator();
                this.setupEventListeners();
            })
            .catch(error => {
                this.hideLoadingIndicator();
                console.error('Failed to initialize Babylon scene:', error);
                this.handleError('initialization_failed', error);
            });
    },

    updated() {
        console.log('BabylonScene hook updated');
        this.handleServerUpdates();
    },

    destroyed() {
        console.log('BabylonScene hook destroyed');
        this.cleanup();
    },

    /**
     * Initialize Babylon.js scene
     */
    async initializeBabylonScene() {
        if (!BabylonFallbackManager.checkWebGLSupport()) {
            this.renderFallback();
            return;
        }

        // Use the existing canvas element instead of creating a new one
        this.canvas = this.el;

        // Set canvas size to match container
        const container = this.canvas.parentElement;
        this.canvas.width = container.clientWidth;
        this.canvas.height = container.clientHeight;
        this.canvas.style.width = '100%';
        this.canvas.style.height = '100%';
        this.canvas.style.display = 'block';

        // Engine
        this.engine = new BABYLON.Engine(this.canvas, true, {
            preserveDrawingBuffer: true,
            stencil: true,
            antialias: true,
            adaptToDeviceRatio: true
        });

        // Scene
        this.scene = new BABYLON.Scene(this.engine);
        this.scene.useRightHandedSystem = true;

        // Asset manager
        this.assetManager = new BabylonAssetManager(this.scene);
        
        // Scene loader for editor scenes
        this.sceneLoader = new BabylonSceneLoader(this.scene);

        // Initialize physics
        await this.setupPhysics();

        // Default env + test assets
        this.setupDefaultEnvironment();
        this.createEnvironmentWalls();
        await this.loadInitialAssets();

        // Render loop
        this.startRenderLoop();

        // Show scene
        this.showScene();

        console.log('Babylon.js scene initialized successfully');

        // Resize handler
        this.resizeHandler = () => {
            if (this.engine && this.canvas) {
                const container = this.canvas.parentElement;
                this.canvas.width = container.clientWidth;
                this.canvas.height = container.clientHeight;
                this.engine.resize();
            }
        };
        window.addEventListener('resize', this.resizeHandler);
    },

    /**
     * Setup camera + lights
     */
    setupDefaultEnvironment() {
        console.log('Setting up camera and lights...');

        this.camera = new BABYLON.ArcRotateCamera(
            'camera',
            -Math.PI / 4,
            Math.PI / 3,
            10, // Closer to the cube
            new BABYLON.Vector3(0, 0, 0), // Look at origin where cube is
            this.scene
        );
        this.camera.lowerRadiusLimit = 3;
        this.camera.upperRadiusLimit = 20;
        this.camera.inertia = 0.8;
        this.camera.wheelDeltaPercentage = 0.01;

        const hemi = new BABYLON.HemisphericLight('hemi', new BABYLON.Vector3(0, 1, 0), this.scene);
        hemi.intensity = 0.7;

        const dir = new BABYLON.DirectionalLight('dir', new BABYLON.Vector3(-1, -1, -1), this.scene);
        dir.intensity = 0.5;
    },

    /**
     * Assets
     */
    async loadInitialAssets() {
        const assets = this.getAssets();
        if (assets.length > 0) {
            for (const asset of assets) {
                await this.assetManager.loadAsset(asset);
            }
        } else {
            this.createTestShapes();
        }
    },

    createTestShapes() {
        console.log('Creating test cube...');

        // Create a more visible cube
        const box = BABYLON.MeshBuilder.CreateBox('testCube', { size: 2 }, this.scene);
        box.position.y = 2; // Start above ground
        box.position.z = 0;

        // Create a bright material
        const mat = new BABYLON.StandardMaterial('boxMat', this.scene);
        mat.diffuseColor = new BABYLON.Color3(1, 0.2, 0.2); // Bright red
        mat.emissiveColor = new BABYLON.Color3(0.1, 0.1, 0.1); // Slight glow
        box.material = mat;

        // Make it interactive
        box.metadata = { interactive: true };
        box.isPickable = true;

        // Add physics
        if (this.scene.getPhysicsEngine()) {
            box.physicsImpostor = new BABYLON.PhysicsImpostor(box, BABYLON.PhysicsImpostor.BoxImpostor, {
                mass: 1, restitution: 0.7
            }, this.scene);
        }

        console.log('Test cube created at position:', box.position);
    },

    showScene() {
        // Canvas is already the element, no need to append
        if (this.camera) this.camera.attachControl(this.canvas, true);
    },

    /**
     * Loading indicator
     */
    showLoadingIndicator() {
        this.el.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: center; 
                        width: 100%; height: 100%; background: #000011; color: white;">
                <div style="text-align: center;">
                    <div style="width: 50px; height: 50px; border: 3px solid #333; 
                                border-top: 3px solid #fff; border-radius: 50%; 
                                animation: spin 1s linear infinite; margin: 0 auto 20px;"></div>
                    <div>Loading 3D Scene...</div>
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
     * Physics setup
     */
    async setupPhysics() {
        console.log('Setting up physics...');
        try {
            const havokInstance = await HavokPhysics();
            this.scene.enablePhysics(new BABYLON.Vector3(0, -9.81, 0), new BABYLON.HavokPlugin(true, havokInstance));
            console.log('Physics initialized successfully');
        } catch (error) {
            console.warn('Physics initialization failed, continuing without physics:', error);
        }
    },

    /**
     * Create environment walls for bouncing
     */
    createEnvironmentWalls() {
        console.log('Creating environment walls...');

        const wallSize = 20;
        const wallHeight = 10;
        const wallThickness = 1;

        // Floor
        const floor = BABYLON.MeshBuilder.CreateBox('floor', {
            width: wallSize, height: wallThickness, depth: wallSize
        }, this.scene);
        floor.position.y = -wallHeight / 2;

        // Walls
        const walls = [
            // Front wall
            { name: 'frontWall', pos: [0, 0, wallSize / 2], size: [wallSize, wallHeight, wallThickness] },
            // Back wall  
            { name: 'backWall', pos: [0, 0, -wallSize / 2], size: [wallSize, wallHeight, wallThickness] },
            // Left wall
            { name: 'leftWall', pos: [-wallSize / 2, 0, 0], size: [wallThickness, wallHeight, wallSize] },
            // Right wall
            { name: 'rightWall', pos: [wallSize / 2, 0, 0], size: [wallThickness, wallHeight, wallSize] },
            // Ceiling
            { name: 'ceiling', pos: [0, wallHeight / 2, 0], size: [wallSize, wallThickness, wallSize] }
        ];

        walls.forEach(wallConfig => {
            const wall = BABYLON.MeshBuilder.CreateBox(wallConfig.name, {
                width: wallConfig.size[0],
                height: wallConfig.size[1],
                depth: wallConfig.size[2]
            }, this.scene);
            wall.position.set(...wallConfig.pos);

            // Wall material
            const wallMat = new BABYLON.StandardMaterial(wallConfig.name + 'Mat', this.scene);
            wallMat.diffuseColor = new BABYLON.Color3(0.3, 0.3, 0.4);
            wallMat.specularColor = new BABYLON.Color3(0.1, 0.1, 0.1);
            wall.material = wallMat;

            // Physics
            if (this.scene.getPhysicsEngine()) {
                wall.physicsImpostor = new BABYLON.PhysicsImpostor(wall, BABYLON.PhysicsImpostor.BoxImpostor, {
                    mass: 0, restitution: 0.8
                }, this.scene);
            }
        });

        // Floor physics and material
        const floorMat = new BABYLON.StandardMaterial('floorMat', this.scene);
        floorMat.diffuseColor = new BABYLON.Color3(0.2, 0.2, 0.3);
        floor.material = floorMat;

        if (this.scene.getPhysicsEngine()) {
            floor.physicsImpostor = new BABYLON.PhysicsImpostor(floor, BABYLON.PhysicsImpostor.BoxImpostor, {
                mass: 0, restitution: 0.8
            }, this.scene);
        }
    },

    /**
     * Load a scene created with Babylon.js Editor
     * @param {string} scenePath - Path to scene file or project
     */
    async loadEditorScene(scenePath) {
        console.log('Loading editor scene:', scenePath);
        
        try {
            let loadedScene;
            
            if (scenePath.endsWith('.bjseditor')) {
                // Load editor project
                loadedScene = await this.sceneLoader.loadEditorProject(scenePath);
            } else {
                // Load scene file directly
                loadedScene = await this.sceneLoader.loadEditorScene(scenePath, {
                    enablePhysics: true,
                    enableInteractions: true
                });
            }
            
            console.log('Editor scene loaded successfully');
            return loadedScene;
            
        } catch (error) {
            console.error('Failed to load editor scene:', error);
            // Fallback to default scene
            this.createTestShapes();
        }
    },

    /**
     * Overlay HUD (GUI)
     */
    setupOverlayUI() {
        this.gui = GUI.AdvancedDynamicTexture.CreateFullscreenUI("UI");

        this.logPanel = new GUI.StackPanel();
        this.logPanel.width = "30%";
        this.logPanel.horizontalAlignment = GUI.Control.HORIZONTAL_ALIGNMENT_LEFT;
        this.logPanel.verticalAlignment = GUI.Control.VERTICAL_ALIGNMENT_TOP;
        this.logPanel.top = "20px";
        this.logPanel.left = "20px";
        this.gui.addControl(this.logPanel);

        this.uiLogs = [];
    },

    addUILog(log) {
        if (!this.logPanel) return;

        // Trim to last 5
        if (this.uiLogs.length >= 5) {
            const old = this.uiLogs.shift();
            this.logPanel.removeControl(old);
        }

        const text = new GUI.TextBlock();
        text.text = `[${log.type}] ${log.mesh || log.key || log.message || log.reason || ""}`;
        text.color = log.type === "error" ? "red" :
            log.type === "key" ? "lime" :
                log.type === "fallback" ? "yellow" : "cyan";
        text.fontSize = 18;
        text.textHorizontalAlignment = GUI.Control.HORIZONTAL_ALIGNMENT_LEFT;
        text.height = "24px";

        this.logPanel.addControl(text);
        this.uiLogs.push(text);
    },

    /**
     * Pointer + keyboard handlers
     */
    setupEventListeners() {
        if (!this.scene) return;

        this.scene.onPointerObservable.add((pi) => {
            if (pi.type === BABYLON.PointerEventTypes.POINTERUP && pi.pickInfo?.hit) {
                const mesh = pi.pickInfo.pickedMesh;

                // Apply physics impulse on click
                if (mesh && mesh.physicsImpostor && pi.pickInfo.pickedPoint) {
                    const clickPoint = pi.pickInfo.pickedPoint;
                    const meshCenter = mesh.getAbsolutePosition();

                    // Calculate direction from click point to mesh center (perpendicular push)
                    const direction = meshCenter.subtract(clickPoint).normalize();
                    const force = direction.scale(10); // Adjust force strength

                    mesh.physicsImpostor.applyImpulse(force, meshCenter);

                    console.log('Applied impulse to', mesh.name, 'with force:', force);
                }

                this.pushEvent("babylon_interaction", {
                    type: "click",
                    mesh: mesh?.name
                });
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

    startRenderLoop() {
        console.log('Starting render loop...');
        let frameCount = 0;

        this.engine.runRenderLoop(() => {
            if (this.scene && this.scene.activeCamera) {
                this.scene.render();

                // Log first few frames to confirm rendering
                if (frameCount < 5) {
                    frameCount++;
                    console.log(`Frame ${frameCount} rendered`);
                }
            }
        });
    },

    getAssets() {
        try {
            const assetsData = this.el.dataset.assets;
            return assetsData ? JSON.parse(assetsData) : [];
        } catch {
            return [];
        }
    },

    /**
     * Handle server updates from Phoenix LiveView
     */
    handleServerUpdates() {
        try {
            const newConfig = this.getSceneConfig();
            const newAssets = this.getAssets();

            // Update scene configuration if changed
            if (newConfig) {
                this.applySceneConfiguration(newConfig);
            }

            // Update assets if changed
            if (newAssets && newAssets.length > 0) {
                this.updateAssets(newAssets);
            }

        } catch (error) {
            console.error('Failed to handle server updates:', error);
            this.handleError('update_failed', error);
        }
    },

    /**
     * Get scene configuration from element data
     */
    getSceneConfig() {
        try {
            const configData = this.el.dataset.sceneConfig;
            return configData ? JSON.parse(configData) : {};
        } catch (error) {
            console.error('Failed to parse scene config:', error);
            return {};
        }
    },

    /**
     * Apply scene configuration from server
     */
    applySceneConfiguration(config) {
        if (!config || !this.scene || !this.camera) return;

        // Update camera position if specified
        if (config.camera) {
            if (config.camera.position) {
                this.camera.setPosition(new BABYLON.Vector3(
                    config.camera.position.x || 0,
                    config.camera.position.y || 5,
                    config.camera.position.z || 10
                ));
            }

            if (config.camera.target) {
                this.camera.setTarget(new BABYLON.Vector3(
                    config.camera.target.x || 0,
                    config.camera.target.y || 0,
                    config.camera.target.z || 0
                ));
            }
        }

        // Update lighting if specified
        if (config.lighting && this.scene.lights) {
            // Apply lighting configuration
            this.scene.lights.forEach(light => {
                if (config.lighting.ambient !== undefined) {
                    light.intensity = config.lighting.ambient;
                }
            });
        }
    },

    /**
     * Update assets based on server data
     */
    async updateAssets(newAssets) {
        if (!newAssets || !this.assetManager) return;

        for (const asset of newAssets) {
            try {
                await this.assetManager.loadAsset(asset);
            } catch (error) {
                console.error('Failed to load asset:', asset, error);
            }
        }
    },

    renderFallback() {
        BabylonFallbackManager.renderFallback(this.el, { message: "WebGL not supported." });
        this.pushEvent("babylon_fallback", { reason: "webgl_not_supported" });
    },

    handleError(type, error) {
        console.error("Babylon.js error:", error);
        this.pushEvent("babylon_error", { type, message: error.message || "Unknown error" });
    },

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
            this.assetManager?.cleanup();
        } catch (err) {
            console.error("Cleanup error:", err);
        }
    }
};
