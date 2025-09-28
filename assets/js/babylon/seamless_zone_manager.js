// Enhanced Zone Manager with Seamless World Streaming
import { Vector3, Vector2 } from './babylon_imports';
import { WorldStreamingSystem } from './world_streaming_system';
import { GlobalWorldSystem } from './global_world_system';
import { TerrainLODSystem } from './terrain_lod_system';

/**
 * Enhanced Zone Manager that provides seamless world streaming
 * Replaces traditional zone-line transitions with continuous chunk-based loading
 */
export class SeamlessZoneManager {
    constructor(hook, options = {}) {
        this.hook = hook;
        this.options = {
            // World streaming options
            chunkSize: 256,
            loadRadius: 3,
            unloadRadius: 5,
            worldSize: 10000,
            
            // Transition options
            enableSeamlessTransitions: true,
            transitionDistance: 32,        // Distance from chunk edge to start transition
            loadingIndicatorThreshold: 2000, // Show loading only for long loads
            
            // Performance options
            maxConcurrentLoads: 2,
            lodEnabled: true,
            
            ...options
        };
        
        // Core systems
        this.worldSystem = new GlobalWorldSystem({
            worldSize: this.options.worldSize,
            chunkSize: this.options.chunkSize
        });
        
        this.streamingSystem = new WorldStreamingSystem(hook.scene, {
            chunkSize: this.options.chunkSize,
            loadRadius: this.options.loadRadius,
            unloadRadius: this.options.unloadRadius,
            maxConcurrentLoads: this.options.maxConcurrentLoads
        });
        
        this.lodSystem = this.options.lodEnabled ? 
            new TerrainLODSystem(this.streamingSystem) : null;
        
        // State tracking
        this.playerPosition = new Vector3(0, 1, 0);
        this.currentZone = null;
        this.isLoading = false;
        this.transitionCallbacks = new Map();
        
        // Legacy zone support
        this.legacyZones = new Map();
        this.setupLegacyZoneSupport();
        
        console.log('Seamless Zone Manager initialized');
    }

    /**
     * Setup support for legacy zone definitions
     */
    setupLegacyZoneSupport() {
        // Import existing zone definitions from the old zone manager
        this.legacyZones.set('lobby', {
            name: 'Character Lobby',
            worldPosition: new Vector3(0, 0, 0),
            radius: 128,
            type: 'special', // Special zones use pre-built meshes
            scenePath: '/assets/babylon/lobby_scene.babylon',
            requiresPhysics: false,
            requiresGUI: true
        });
        
        this.legacyZones.set('tutorial', {
            name: 'Tutorial Zone',
            worldPosition: new Vector3(500, 0, 0),
            radius: 256,
            type: 'special',
            scenePath: '/assets/babylon/tutorial_scene.babylon',
            requiresPhysics: true,
            requiresGUI: false
        });
        
        // Add these as special regions to the world system
        for (const [zoneName, zoneConfig] of this.legacyZones) {
            this.worldSystem.addWorldRegion(`legacy_${zoneName}`, {
                center: { x: zoneConfig.worldPosition.x, z: zoneConfig.worldPosition.z },
                radius: zoneConfig.radius,
                heightRange: { min: 0, max: 10 },
                terrainType: 'mesh',
                biome: 'special',
                meshSource: zoneConfig.scenePath,
                priority: 10 // High priority for legacy zones
            });
        }
    }

    /**
     * Initialize the seamless world system
     */
    async initialize(spawnPosition = null) {
        console.log('Initializing seamless world system...');
        
        try {
            // Set initial player position
            const startPos = spawnPosition || new Vector3(0, 1, 0);
            this.setPlayerPosition(startPos);
            
            // Start streaming system
            this.startStreamingUpdates();
            
            // Load initial chunks around spawn position
            await this.loadInitialArea(startPos);
            
            console.log('✅ Seamless world system ready');
            
        } catch (error) {
            console.error('❌ Failed to initialize seamless world:', error);
            throw error;
        }
    }

    /**
     * Load initial chunks around spawn position
     */
    async loadInitialArea(position) {
        console.log('Loading initial area around:', position);
        
        this.showLoadingIndicator('Loading world...');
        
        try {
            // Force load chunks in load radius
            const chunkCoords = this.worldSystem.worldToChunkCoords(position);
            const chunksToLoad = this.getChunksInRadius(chunkCoords, this.options.loadRadius);
            
            // Load chunks in order of distance (closest first)
            const loadPromises = [];
            for (const chunkPos of chunksToLoad) {
                const promise = this.streamingSystem.forceLoadChunk(chunkPos);
                loadPromises.push(promise);
                
                // Limit concurrent loads
                if (loadPromises.length >= this.options.maxConcurrentLoads) {
                    await Promise.all(loadPromises);
                    loadPromises.length = 0;
                }
            }
            
            // Wait for any remaining loads
            if (loadPromises.length > 0) {
                await Promise.all(loadPromises);
            }
            
        } finally {
            this.hideLoadingIndicator();
        }
    }

    /**
     * Get chunks within radius of center chunk
     */
    getChunksInRadius(centerChunk, radius) {
        const chunks = [];
        
        for (let x = centerChunk.x - radius; x <= centerChunk.x + radius; x++) {
            for (let z = centerChunk.y - radius; z <= centerChunk.y + radius; z++) {
                const chunkCoords = new Vector2(x, z);
                const distance = this.getChunkDistance(centerChunk, chunkCoords);
                
                if (distance <= radius) {
                    chunks.push(chunkCoords);
                }
            }
        }
        
        // Sort by distance (closest first)
        chunks.sort((a, b) => {
            const distA = this.getChunkDistance(centerChunk, a);
            const distB = this.getChunkDistance(centerChunk, b);
            return distA - distB;
        });
        
        return chunks;
    }

    /**
     * Calculate distance between chunks
     */
    getChunkDistance(chunk1, chunk2) {
        const dx = chunk1.x - chunk2.x;
        const dz = chunk1.y - chunk2.y;
        return Math.sqrt(dx * dx + dz * dz);
    }

    /**
     * Start the streaming update loop
     */
    startStreamingUpdates() {
        const updateStreaming = () => {
            // Update streaming system with current player position
            this.streamingSystem.updateStreaming(this.playerPosition);
            
            // Update LOD system if enabled
            if (this.lodSystem) {
                this.lodSystem.updatePlayerPosition(this.playerPosition);
            }
            
            // Check for zone transitions
            this.checkZoneTransitions();
            
            requestAnimationFrame(updateStreaming);
        };
        
        updateStreaming();
    }

    /**
     * Update player position (called by character controller)
     */
    setPlayerPosition(position) {
        this.playerPosition.copyFrom(position);
        
        // Clamp to world bounds
        const clampedPos = this.worldSystem.clampToWorldBounds(this.playerPosition);
        if (!clampedPos.equals(this.playerPosition)) {
            this.playerPosition.copyFrom(clampedPos);
            console.log('Player position clamped to world bounds:', this.playerPosition);
        }
    }

    /**
     * Check for zone transitions based on current position
     */
    checkZoneTransitions() {
        // Check if we're near any special legacy zones
        const currentZone = this.getCurrentZone();
        
        if (currentZone !== this.currentZone) {
            this.handleZoneTransition(this.currentZone, currentZone);
            this.currentZone = currentZone;
        }
        
        // Check if we need to trigger any zone-specific loading
        this.checkProximityLoading();
    }

    /**
     * Get the current zone based on player position
     */
    getCurrentZone() {
        const regions = this.worldSystem.getRegionsForPosition(this.playerPosition);
        
        // Look for legacy zones first (highest priority)
        for (const regionInfo of regions) {
            const regionName = regionInfo.region.name;
            if (regionName.startsWith('legacy_')) {
                const zoneName = regionName.replace('legacy_', '');
                if (this.legacyZones.has(zoneName)) {
                    return zoneName;
                }
            }
        }
        
        // Default to 'overworld' for procedural areas
        return 'overworld';
    }

    /**
     * Handle transition between zones
     */
    async handleZoneTransition(fromZone, toZone) {
        console.log(`Zone transition: ${fromZone || 'none'} → ${toZone}`);
        
        // Call any registered transition callbacks
        const callbackKey = `${fromZone}_to_${toZone}`;
        if (this.transitionCallbacks.has(callbackKey)) {
            try {
                await this.transitionCallbacks.get(callbackKey)(fromZone, toZone);
            } catch (error) {
                console.error('Zone transition callback failed:', error);
            }
        }
        
        // Handle special zone requirements
        if (this.legacyZones.has(toZone)) {
            const zoneConfig = this.legacyZones.get(toZone);
            await this.handleLegacyZoneRequirements(toZone, zoneConfig);
        }
    }

    /**
     * Handle requirements for legacy zones (physics, GUI, etc.)
     */
    async handleLegacyZoneRequirements(zoneName, zoneConfig) {
        // Enable physics if required
        if (zoneConfig.requiresPhysics && !this.hook.scene.getPhysicsEngine()) {
            console.log(`Enabling physics for zone: ${zoneName}`);
            await this.hook.setupPhysics();
        }
        
        // Enable GUI if required
        if (zoneConfig.requiresGUI) {
            console.log(`Setting up GUI for zone: ${zoneName}`);
            if (this.hook && typeof this.hook.setupOverlayUI === 'function') {
                try {
                    await this.hook.setupOverlayUI();
                } catch (err) {
                    console.warn('setupOverlayUI failed (continuing without GUI):', err);
                }
            } else {
                console.log('GUI setup skipped: hook.setupOverlayUI not defined');
            }
        }
    }

    /**
     * Check if we need special loading based on proximity to POIs
     */
    checkProximityLoading() {
        // Check distance to world boundaries
        const distanceToBoundary = this.worldSystem.getDistanceToWorldBoundary(this.playerPosition);
        
        if (distanceToBoundary < this.options.transitionDistance) {
            // Close to world edge - might want to show boundary effects
            this.handleWorldBoundaryProximity(distanceToBoundary);
        }
    }

    /**
     * Handle proximity to world boundaries
     */
    handleWorldBoundaryProximity(distance) {
        // Add visual effects, warning messages, or invisible walls
        // This is where you'd implement world edge behavior
        console.log(`Near world boundary, distance: ${distance.toFixed(1)}`);
    }

    /**
     * Legacy compatibility: Load zone by name
     */
    async loadZone(zoneName, spawnPoint = null) {
        console.log(`Loading zone (legacy): ${zoneName}`);
        
        if (this.legacyZones.has(zoneName)) {
            const zoneConfig = this.legacyZones.get(zoneName);
            
            // Move player to zone position
            const targetPosition = spawnPoint || zoneConfig.worldPosition.clone();
            targetPosition.y = 1; // Ensure proper height
            
            // Show loading if needed
            this.showLoadingIndicator(`Entering ${zoneConfig.name}...`);
            
            try {
                // Set position and let streaming system handle loading
                this.setPlayerPosition(targetPosition);
                
                // Wait for area to load
                await this.loadInitialArea(targetPosition);
                
                // Move character if character controller exists
                if (this.hook.characterController) {
                    this.hook.characterController.moveCharacterTo(
                        targetPosition.x, 
                        targetPosition.y, 
                        targetPosition.z
                    );
                }
                
                console.log(`✅ Loaded zone: ${zoneName}`);
                
            } finally {
                this.hideLoadingIndicator();
            }
        } else {
            console.error(`Zone '${zoneName}' not found`);
        }
    }

    /**
     * Register zone transition callback
     */
    onZoneTransition(fromZone, toZone, callback) {
        const key = `${fromZone}_to_${toZone}`;
        this.transitionCallbacks.set(key, callback);
    }

    /**
     * Get streaming system statistics
     */
    getStreamingStats() {
        const streamingStats = this.streamingSystem.getStats();
        const lodStats = this.lodSystem ? this.lodSystem.getLODStats() : null;
        
        return {
            currentZone: this.currentZone,
            playerPosition: this.playerPosition,
            playerChunk: this.worldSystem.worldToChunkCoords(this.playerPosition),
            streaming: streamingStats,
            lod: lodStats,
            worldBounds: this.worldSystem.worldBounds
        };
    }

    /**
     * Force load specific chunks (for debugging)
     */
    async forceLoadChunks(chunkCoordsList) {
        const promises = [];
        for (const chunkCoords of chunkCoordsList) {
            promises.push(this.streamingSystem.forceLoadChunk(chunkCoords));
        }
        await Promise.all(promises);
    }

    /**
     * Enable/disable LOD system
     */
    setLODEnabled(enabled) {
        if (enabled && !this.lodSystem) {
            this.lodSystem = new TerrainLODSystem(this.streamingSystem);
        } else if (!enabled && this.lodSystem) {
            this.lodSystem.dispose();
            this.lodSystem = null;
        }
        
        console.log(`LOD system ${enabled ? 'enabled' : 'disabled'}`);
    }

    /**
     * Show loading indicator
     */
    showLoadingIndicator(message = 'Loading...') {
        if (this.hook.showLoadingIndicator) {
            this.hook.showLoadingIndicator(message);
        }
        this.isLoading = true;
    }

    /**
     * Hide loading indicator
     */
    hideLoadingIndicator() {
        if (this.hook.hideLoadingIndicator) {
            this.hook.hideLoadingIndicator();
        }
        this.isLoading = false;
    }

    /**
     * Get height at world position (for character controllers)
     */
    getHeightAtPosition(worldX, worldZ) {
        // First try to get from loaded heightmap chunks
        const terrainGenerator = this.streamingSystem.chunkProviders.get('heightmap');
        if (terrainGenerator && terrainGenerator.getHeightAtWorldPosition) {
            return terrainGenerator.getHeightAtWorldPosition(worldX, worldZ);
        }
        
        // Fallback to sea level
        return this.worldSystem.options.seaLevel;
    }

    /**
     * Move character to world position (legacy compatibility)
     */
    moveCharacterTo(x, y, z) {
        const targetPos = new Vector3(x, y, z);
        this.setPlayerPosition(targetPos);
        
        if (this.hook.characterController) {
            this.hook.characterController.moveCharacterTo(x, y, z);
        }
    }

    /**
     * Cleanup systems
     */
    dispose() {
        console.log('Disposing seamless zone manager...');
        
        if (this.lodSystem) {
            this.lodSystem.dispose();
        }
        
        this.streamingSystem.dispose();
        this.worldSystem.dispose();
        
        this.transitionCallbacks.clear();
        this.legacyZones.clear();
    }
}

// Export for backward compatibility with existing zone manager
export { SeamlessZoneManager as ZoneManager };