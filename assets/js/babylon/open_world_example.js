// Open World Integration Example - How to use the seamless world system
import { BabylonScene } from './babylon_hooks';
import { SeamlessZoneManager } from './seamless_zone_manager';

/**
 * Example integration of the open world system with your existing Babylon.js setup
 * This shows how to replace the old zone manager with the new seamless streaming system
 */
export const OpenWorldExample = {
    
    /**
     * Enhanced Babylon Scene Hook with Open World Support
     */
    mounted() {
        console.log('Open World Babylon Scene mounted');
        this.el._babylonHook = this;
        
        // Show loading indicator
        this.showLoadingIndicator();
        
        // Initialize with open world system
        this.initializeOpenWorldScene()
            .then(() => {
                this.hideLoadingIndicator();
                this.setupEventListeners();
            })
            .catch(error => {
                this.hideLoadingIndicator();
                console.error('Failed to initialize open world scene:', error);
                this.handleError('initialization_failed', error);
            });
    },

    /**
     * Initialize the open world Babylon.js scene
     */
    async initializeOpenWorldScene() {
        console.log('Initializing open world scene...');
        
        // Initialize Babylon.js core (reuse existing code)
        await this.initializeBabylonScene();
        
        // Setup seamless zone manager instead of traditional zone manager
        this.zoneManager = new SeamlessZoneManager(this, {
            // World configuration
            worldSize: 5000,        // 5km x 5km world
            chunkSize: 256,         // 256 unit chunks
            loadRadius: 2,          // Load 2 chunks around player
            unloadRadius: 4,        // Unload chunks 4+ away
            
            // Performance settings
            maxConcurrentLoads: 3,
            lodEnabled: true,
            
            // Transition settings
            enableSeamlessTransitions: true,
            transitionDistance: 32
        });
        
        // Initialize the open world system
        await this.zoneManager.initialize();
        
        // Setup character controller with world awareness
        await this.setupCharacterWithOpenWorld();
        
        console.log('Open world scene ready!');
    },

    /**
     * Setup character controller with open world integration
     */
    async setupCharacterWithOpenWorld() {
        // Load character controller
        const { CharacterController } = await import('./character_controller');
        
        // Create character controller
        this.characterController = new CharacterController(this.scene, this.camera);
        
        // Connect character movement to world streaming
        const originalUpdateMovement = this.characterController.updateMovement;
        this.characterController.updateMovement = () => {
            // Call original movement update
            originalUpdateMovement.call(this.characterController);
            
            // Update zone manager with new position
            const playerPos = this.characterController.getCharacterPosition();
            this.zoneManager.setPlayerPosition(playerPos);
            
            // Adjust character to terrain height
            const terrainHeight = this.zoneManager.getHeightAtPosition(playerPos.x, playerPos.z);
            if (terrainHeight > playerPos.y - 1) {
                // Keep character above terrain
                const adjustedPos = playerPos.clone();
                adjustedPos.y = Math.max(terrainHeight + 1, adjustedPos.y);
                this.characterController.moveCharacterTo(adjustedPos.x, adjustedPos.y, adjustedPos.z);
            }
        };
    },

    /**
     * Legacy support - load zone by name (now uses seamless streaming)
     */
    async loadZone(zoneName, spawnPoint = null) {
        if (this.zoneManager) {
            await this.zoneManager.loadZone(zoneName, spawnPoint);
        } else {
            console.error('Zone manager not initialized');
        }
    },

    /**
     * Move character to specific world coordinates
     */
    moveCharacterTo(x, y, z) {
        if (this.zoneManager) {
            this.zoneManager.moveCharacterTo(x, y, z);
        }
    },

    /**
     * Get current streaming statistics (for debugging UI)
     */
    getWorldStats() {
        if (this.zoneManager) {
            return this.zoneManager.getStreamingStats();
        }
        return null;
    },

    /**
     * Handle server updates for world state
     */
    handleServerUpdates() {
        console.log('Handling server updates for open world');
        // Handle any server-side world updates (multiplayer sync, etc.)
    },

    /**
     * Enhanced cleanup with world systems
     */
    cleanup() {
        console.log('Cleaning up open world scene');
        
        // Cleanup zone manager
        if (this.zoneManager) {
            this.zoneManager.dispose();
        }
        
        // Cleanup character controller
        if (this.characterController) {
            this.characterController.dispose();
        }
        
        // Cleanup Babylon.js scene
        if (this.engine) {
            this.engine.dispose();
        }
    },

    // Include all the existing BabylonScene methods for compatibility
    ...BabylonScene
};

/**
 * Configuration examples for different world types
 */
export const WorldConfigurations = {
    
    /**
     * Small testing world (1km x 1km)
     */
    smallWorld: {
        worldSize: 1024,
        chunkSize: 128,
        loadRadius: 2,
        unloadRadius: 3,
        lodEnabled: false
    },
    
    /**
     * Medium MMO world (5km x 5km)
     */
    mmoWorld: {
        worldSize: 5120,
        chunkSize: 256,
        loadRadius: 3,
        unloadRadius: 5,
        lodEnabled: true,
        maxConcurrentLoads: 3
    },
    
    /**
     * Large open world (10km x 10km)
     */
    largeWorld: {
        worldSize: 10240,
        chunkSize: 512,
        loadRadius: 2,
        unloadRadius: 4,
        lodEnabled: true,
        maxConcurrentLoads: 2
    }
};

/**
 * Helper functions for working with the open world system
 */
export const OpenWorldHelpers = {
    
    /**
     * Create sample heightmaps for testing
     */
    async generateSampleHeightmaps() {
        console.log('Generating sample heightmaps...');
        
        // This would create sample PNG heightmap files
        // You can implement this based on your specific needs
        
        const sampleHeightmap = this.createProceduralHeightmap(256, 256);
        return sampleHeightmap;
    },
    
    /**
     * Create a simple procedural heightmap
     */
    createProceduralHeightmap(width, height) {
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        
        const ctx = canvas.getContext('2d');
        const imageData = ctx.createImageData(width, height);
        const data = imageData.data;
        
        // Generate simple noise-based heightmap
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const idx = (y * width + x) * 4;
                
                // Simple noise calculation
                const noise = (Math.sin(x * 0.02) + Math.cos(y * 0.03)) * 0.5 + 0.5;
                const heightValue = Math.floor(noise * 255);
                
                data[idx] = heightValue;     // R (height)
                data[idx + 1] = heightValue; // G
                data[idx + 2] = heightValue; // B
                data[idx + 3] = 255;         // A
            }
        }
        
        ctx.putImageData(imageData, 0, 0);
        return canvas.toDataURL('image/png');
    },
    
    /**
     * Debug function to visualize chunk boundaries
     */
    showChunkBoundaries(scene, worldSystem, streamingSystem) {
        const loadedChunks = streamingSystem.getLoadedChunks();
        
        for (const chunk of loadedChunks) {
            if (chunk.mesh) {
                // Add wireframe overlay to show chunk boundaries
                const wireframe = chunk.mesh.createInstance(`wireframe_${chunk.chunkCoords.x}_${chunk.chunkCoords.y}`);
                wireframe.material = new StandardMaterial(`wireframe_mat`, scene);
                wireframe.material.wireframe = true;
                wireframe.material.diffuseColor = new Color3(1, 0, 0);
            }
        }
    }
};