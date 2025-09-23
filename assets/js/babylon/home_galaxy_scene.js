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
        this.engine.runRenderLoop(() => {
            if (this.scene && this.scene.activeCamera) {
                this.scene.render();
            }
        });
    },

    /**
     * Handle window resize
     */
    handleResize() {
        window.addEventListener("resize", () => {
            if (this.engine) {
                this.engine.resize();
            }
        });
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