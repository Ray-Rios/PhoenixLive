import { 
    Engine, Scene, Vector3, Color3, Color4,
    ArcRotateCamera,
    MeshBuilder, StandardMaterial
} from './babylon_imports';

// Don't import these for now to test if they're causing issues
// import '@babylonjs/core/Cameras/Inputs/arcRotateCameraPointersInput';
// import '@babylonjs/core/Cameras/Inputs/arcRotateCameraKeyboardMoveInput';
// import '@babylonjs/core/Cameras/Inputs/arcRotateCameraMouseWheelInput';

// Dynamic texture for procedural galaxy
// import { DynamicTexture } from '@babylonjs/core/Materials/Textures/dynamicTexture';

/**
 * Home Galaxy Scene Hook - Starfield Background for Welcome Page
 */
export const HomeGalaxyScene = {
    mounted() {
        console.log('HomeGalaxyScene hook mounted');
        this.el._babylonHook = this;

        const canvas = this.el.querySelector('canvas');
        if (!canvas) {
            console.error('Canvas not found for HomeGalaxyScene');
            return;
        }

        // Setup helpers before init
        this._lastDPR = window.devicePixelRatio || 1;
        this._lastCanvasClientW = canvas.clientWidth;
        this._lastCanvasClientH = canvas.clientHeight;
        this._framesSinceLastIntegrityCheck = 0;

        // Debounced resize (RAF based)
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
                            console.warn('Resize failure (ignored):', e);
                        }
                    }
                });
            };
        })();

        // Visibility handling (LiveView patches / tab switches)
        this.visibilityHandler = () => {
            if (document.visibilityState === 'visible') {
                // Slight delay to allow layout to settle
                setTimeout(() => this.debouncedResize(), 60);
            }
        };
        document.addEventListener('visibilitychange', this.visibilityHandler);

        // LiveView navigation stop event often signals DOM settled
        this.pageLoadingStopHandler = () => this.debouncedResize();
        window.addEventListener('phx:page-loading-stop', this.pageLoadingStopHandler);

        this.initializeGalaxyScene(canvas)
            .then(() => {
                console.log('Home Galaxy Scene initialized successfully');
            })
            .catch(error => {
                console.error('Failed to initialize Home Galaxy Scene:', error);
            });
    },

    updated() {
        // Resume animation if needed
        if (this.animationRunning !== undefined) {
            this.animationRunning = true;
        }
    },

    destroyed() {
        console.log('HomeGalaxyScene hook destroyed');
        this.cleanup();
    },

    /**
     * Initialize the galaxy scene
     */
    async initializeGalaxyScene(canvas) {
        try {
            // Create engine
            this.engine = new Engine(canvas, true, {
                preserveDrawingBuffer: true,
                stencil: true,
                antialias: true,
                alpha: true
            });

            // Create scene
            this.scene = new Scene(this.engine);
            this.scene.clearColor = new Color4(0, 0, 0, 1);

            await this.createCamera();
            await this.createSkybox();
            await this.createStarField();
            
            this.startRenderLoop();
            this.handleResize();
            
            return true;
        } catch (error) {
            console.error('Failed to initialize Home Galaxy Scene:', error);
            return false;
        }
    },

    /**
     * Create camera with auto-rotation
     */
    async createCamera() {
        // Create arc rotate camera for subtle movement
        this.camera = new ArcRotateCamera(
            "homeCamera", 
            0, 
            Math.PI / 3, 
            10, 
            Vector3.Zero(), 
            this.scene
        );
        
        // Disable camera controls - we want it to auto-rotate
        this.camera.setTarget(Vector3.Zero());
        // Skip attachToCanvas for now as it might require additional imports
        // this.camera.attachToCanvas(this.el.querySelector('canvas'), false);
        
        // Very slow auto-rotation
        this.scene.registerBeforeRender(() => {
            if (this.animationRunning) {
                this.camera.alpha += 0.001; // Slow rotation
            }
        });
    },

    /**
     * Create skybox with procedural galaxy texture
     */
    async createSkybox() {
        // Simplified skybox for debugging
        const skybox = MeshBuilder.CreateSphere("skyBox", {diameter: 100}, this.scene);
        const skyboxMaterial = new StandardMaterial("skyBox", this.scene);
        
        // Simple color instead of complex texture for now
        skyboxMaterial.diffuseColor = new Color3(0.1, 0.0, 0.2); // Dark purple
        skyboxMaterial.disableLighting = true;
        skyboxMaterial.backFaceCulling = false;
        
        skybox.material = skyboxMaterial;
        skybox.infiniteDistance = true;
    },

    /**
     * Generate procedural galaxy texture
     */
    generateGalaxyTexture(texture) {
        // Simplified version without DynamicTexture for now
        console.log('Galaxy texture generation skipped for debugging');
    },

    /**
     * Create animated star field
     */
    async createStarField() {
        // Create floating star particles for foreground
        const starCount = 200;
        this.stars = [];
        
        for (let i = 0; i < starCount; i++) {
            const star = MeshBuilder.CreateSphere(`star_${i}`, {diameter: 0.02 + Math.random() * 0.03}, this.scene);
            
            // Position stars randomly in a sphere around the camera
            const distance = 5 + Math.random() * 40;
            const phi = Math.random() * Math.PI * 2;
            const theta = Math.random() * Math.PI;
            
            star.position.x = distance * Math.sin(theta) * Math.cos(phi);
            star.position.y = distance * Math.sin(theta) * Math.sin(phi);
            star.position.z = distance * Math.cos(theta);
            
            // Create glowing material
            const starMaterial = new StandardMaterial(`starMat_${i}`, this.scene);
            starMaterial.emissiveColor = new Color3(
                0.8 + Math.random() * 0.2,  // White to slightly warm
                0.8 + Math.random() * 0.2,
                1
            );
            starMaterial.disableLighting = true;
            
            star.material = starMaterial;
            
            // Add subtle animation
            const animSpeed = 0.001 + Math.random() * 0.002;
            const animRadius = 0.1 + Math.random() * 0.2;
            const animOffset = Math.random() * Math.PI * 2;
            
            star.animationData = {
                speed: animSpeed,
                radius: animRadius,
                offset: animOffset,
                originalPosition: star.position.clone()
            };
            
            this.stars.push(star);
        }
        
        // Animate stars
        this.scene.registerBeforeRender(() => {
            if (this.animationRunning) {
                this.stars.forEach((star) => {
                    const data = star.animationData;
                    const time = performance.now() * data.speed + data.offset;
                    
                    star.position.x = data.originalPosition.x + Math.sin(time) * data.radius;
                    star.position.y = data.originalPosition.y + Math.cos(time * 0.7) * data.radius * 0.5;
                    
                    // Subtle pulsing
                    const scale = 1 + Math.sin(time * 2) * 0.2;
                    star.scaling = new Vector3(scale, scale, scale);
                });
            }
        });
    },

    /**
     * Start render loop
     */
    startRenderLoop() {
        this.animationRunning = true;
        const canvas = this.engine.getRenderingCanvas();
        const integrityEvery = 10; // Only run expensive checks every N frames

        this.engine.runRenderLoop(() => {
            if (this.scene && this.scene.activeCamera) {
                // Periodic integrity check to fight post-LiveView blur
                if (++this._framesSinceLastIntegrityCheck >= integrityEvery) {
                    this._framesSinceLastIntegrityCheck = 0;
                    this.ensureResolutionIntegrity(canvas);
                }
                this.scene.render();
            }
        });
    },

    /**
     * Ensure canvas / engine render size matches CSS size * DPR
     * (Fixes occasional blur after LiveView patch or tab restore)
     */
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

        // Detect client size changes (potential LiveView patch or layout shift)
        if (cw !== this._lastCanvasClientW || ch !== this._lastCanvasClientH) {
            this._lastCanvasClientW = cw;
            this._lastCanvasClientH = ch;
            changed = true;
        }

        // If internal buffer mismatch, trigger resize
        if (currentW !== expectedW || currentH !== expectedH) {
            changed = true;
        }

        if (changed) {
            try {
                this.engine.resize();
            } catch (e) {
                console.debug('Engine resize skipped (transient):', e);
            }
        }
    },

    /**
     * Handle window resize
     */
    handleResize() {
        this.windowResizeHandler = () => this.debouncedResize();
        window.addEventListener("resize", this.windowResizeHandler);
    },

    /**
     * Pause animation
     */
    pause() {
        this.animationRunning = false;
    },

    /**
     * Resume animation
     */
    resume() {
        this.animationRunning = true;
    },

    /**
     * Clean up resources
     */
    cleanup() {
        this.animationRunning = false;
        // Remove listeners
        if (this.windowResizeHandler) {
            window.removeEventListener('resize', this.windowResizeHandler);
            this.windowResizeHandler = null;
        }
        if (this.visibilityHandler) {
            document.removeEventListener('visibilitychange', this.visibilityHandler);
            this.visibilityHandler = null;
        }
        if (this.pageLoadingStopHandler) {
            window.removeEventListener('phx:page-loading-stop', this.pageLoadingStopHandler);
            this.pageLoadingStopHandler = null;
        }
        
        if (this.stars) {
            this.stars.forEach(star => star.dispose());
            this.stars = [];
        }
        
        if (this.scene) {
            this.scene.dispose();
        }
        
        if (this.engine) {
            this.engine.dispose();
        }
    }
};