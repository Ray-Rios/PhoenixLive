// World Streaming System for Open-World Babylon.js Experience
import { Vector3, Vector2 } from './babylon_imports';

/**
 * Manages streaming of world chunks based on player position
 * Creates seamless open-world feeling by loading/unloading chunks dynamically
 */
export class WorldStreamingSystem {
    constructor(scene, options = {}) {
        this.scene = scene;
        this.options = {
            chunkSize: 256,           // Size of each terrain chunk (world units)
            loadRadius: 3,            // How many chunks to load around player (in chunk units)
            unloadRadius: 5,          // When to unload chunks (in chunk units)  
            maxConcurrentLoads: 2,    // Max chunks loading simultaneously
            heightmapResolution: 257, // Heightmap resolution (power of 2 + 1)
            ...options
        };

        // Chunk management
        this.loadedChunks = new Map();        // Currently loaded chunks
        this.loadingChunks = new Set();       // Chunks currently being loaded
        this.chunkProviders = new Map();      // Different data sources for chunks
        this.playerPosition = new Vector3(0, 0, 0);
        this.lastPlayerChunk = new Vector2(0, 0);
        
        // Performance tracking
        this.loadQueue = [];
        this.unloadQueue = [];
        this.isProcessing = false;
        
        this.setupChunkProviders();
    }

    /**
     * Register different data sources for terrain chunks
     */
    setupChunkProviders() {
        // Default heightmap provider
        this.addChunkProvider('heightmap', new HeightmapChunkProvider(this.options));
        
        // Mesh-based chunk provider for special areas
        this.addChunkProvider('mesh', new MeshChunkProvider(this.options));
        
        // Procedural chunk provider for infinite worlds
        this.addChunkProvider('procedural', new ProceduralChunkProvider(this.options));
    }

    addChunkProvider(name, provider) {
        this.chunkProviders.set(name, provider);
        provider.setStreamingSystem(this);
    }

    /**
     * Update streaming based on player position
     */
    updateStreaming(playerPosition) {
        this.playerPosition.copyFrom(playerPosition);
        
        const currentChunk = this.worldToChunkCoords(playerPosition);
        
        // Only process if player moved to new chunk
        if (!currentChunk.equals(this.lastPlayerChunk)) {
            this.lastPlayerChunk.copyFrom(currentChunk);
            this.processChunkStreaming(currentChunk);
        }
    }

    /**
     * Convert world coordinates to chunk coordinates
     */
    worldToChunkCoords(worldPos) {
        return new Vector2(
            Math.floor(worldPos.x / this.options.chunkSize),
            Math.floor(worldPos.z / this.options.chunkSize)
        );
    }

    /**
     * Convert chunk coordinates to world position
     */
    chunkToWorldCoords(chunkCoords) {
        return new Vector3(
            chunkCoords.x * this.options.chunkSize,
            0,
            chunkCoords.y * this.options.chunkSize
        );
    }

    /**
     * Process what chunks need loading/unloading
     */
    async processChunkStreaming(centerChunk) {
        if (this.isProcessing) return;
        this.isProcessing = true;

        try {
            // Determine chunks that should be loaded
            const chunksToLoad = this.getChunksInRadius(centerChunk, this.options.loadRadius);
            const chunksToUnload = [];

            // Check which loaded chunks are now too far
            for (const [chunkKey, chunk] of this.loadedChunks) {
                const chunkCoords = this.parseChunkKey(chunkKey);
                const distance = this.getChunkDistance(centerChunk, chunkCoords);
                
                if (distance > this.options.unloadRadius) {
                    chunksToUnload.push(chunkKey);
                }
            }

            // Queue unloads first to free memory
            for (const chunkKey of chunksToUnload) {
                await this.unloadChunk(chunkKey);
            }

            // Queue loads for missing chunks
            for (const chunkCoords of chunksToLoad) {
                const chunkKey = this.getChunkKey(chunkCoords);
                
                if (!this.loadedChunks.has(chunkKey) && !this.loadingChunks.has(chunkKey)) {
                    this.loadQueue.push({ chunkCoords, priority: this.getChunkDistance(centerChunk, chunkCoords) });
                }
            }

            // Sort load queue by priority (closer chunks first)
            this.loadQueue.sort((a, b) => a.priority - b.priority);

            // Process load queue
            await this.processLoadQueue();

        } finally {
            this.isProcessing = false;
        }
    }

    /**
     * Get all chunk coordinates within radius
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
        
        return chunks;
    }

    /**
     * Calculate distance between two chunks
     */
    getChunkDistance(chunk1, chunk2) {
        const dx = chunk1.x - chunk2.x;
        const dz = chunk1.y - chunk2.y;
        return Math.sqrt(dx * dx + dz * dz);
    }

    /**
     * Process the load queue with concurrency limits
     */
    async processLoadQueue() {
        const activeLoads = [];
        
        while (this.loadQueue.length > 0 && activeLoads.length < this.options.maxConcurrentLoads) {
            const { chunkCoords } = this.loadQueue.shift();
            const chunkKey = this.getChunkKey(chunkCoords);
            
            if (!this.loadingChunks.has(chunkKey)) {
                this.loadingChunks.add(chunkKey);
                const loadPromise = this.loadChunk(chunkCoords)
                    .finally(() => {
                        this.loadingChunks.delete(chunkKey);
                        const index = activeLoads.indexOf(loadPromise);
                        if (index > -1) activeLoads.splice(index, 1);
                    });
                
                activeLoads.push(loadPromise);
            }
        }
        
        // Wait for some loads to complete before processing more
        if (activeLoads.length > 0) {
            await Promise.race(activeLoads);
            // Recursively process remaining queue
            if (this.loadQueue.length > 0) {
                await this.processLoadQueue();
            }
        }
    }

    /**
     * Load a specific chunk
     */
    async loadChunk(chunkCoords) {
        const chunkKey = this.getChunkKey(chunkCoords);
        console.log(`Loading chunk: ${chunkKey}`);
        
        try {
            // Determine which provider to use for this chunk
            const provider = this.getProviderForChunk(chunkCoords);
            
            // Load the chunk data
            const chunkData = await provider.loadChunk(chunkCoords);
            
            if (chunkData) {
                this.loadedChunks.set(chunkKey, chunkData);
                console.log(`✅ Loaded chunk: ${chunkKey}`);
            }
            
        } catch (error) {
            console.error(`❌ Failed to load chunk ${chunkKey}:`, error);
        }
    }

    /**
     * Unload a specific chunk
     */
    async unloadChunk(chunkKey) {
        const chunk = this.loadedChunks.get(chunkKey);
        if (chunk) {
            console.log(`Unloading chunk: ${chunkKey}`);
            
            // Dispose of Babylon.js resources
            if (chunk.mesh) {
                chunk.mesh.dispose();
            }
            
            if (chunk.material) {
                chunk.material.dispose();
            }
            
            if (chunk.texture) {
                chunk.texture.dispose();
            }
            
            // Remove from loaded chunks
            this.loadedChunks.delete(chunkKey);
            console.log(`🗑️ Unloaded chunk: ${chunkKey}`);
        }
    }

    /**
     * Determine which provider should handle this chunk
     */
    getProviderForChunk(chunkCoords) {
        // You can implement logic here to choose different providers
        // based on chunk location, pre-defined zones, etc.
        
        // For now, use heightmap provider as default
        return this.chunkProviders.get('heightmap');
    }

    /**
     * Generate chunk key string
     */
    getChunkKey(chunkCoords) {
        return `${chunkCoords.x}_${chunkCoords.y}`;
    }

    /**
     * Parse chunk key back to coordinates
     */
    parseChunkKey(chunkKey) {
        const [x, z] = chunkKey.split('_').map(Number);
        return new Vector2(x, z);
    }

    /**
     * Get all currently loaded chunks
     */
    getLoadedChunks() {
        return Array.from(this.loadedChunks.values());
    }

    /**
     * Get chunk at specific coordinates
     */
    getChunk(chunkCoords) {
        const chunkKey = this.getChunkKey(chunkCoords);
        return this.loadedChunks.get(chunkKey);
    }

    /**
     * Force load a specific chunk (for debugging)
     */
    async forceLoadChunk(chunkCoords) {
        const chunkKey = this.getChunkKey(chunkCoords);
        if (!this.loadedChunks.has(chunkKey)) {
            await this.loadChunk(chunkCoords);
        }
        return this.loadedChunks.get(chunkKey);
    }

    /**
     * Get streaming statistics
     */
    getStats() {
        return {
            loadedChunks: this.loadedChunks.size,
            loadingChunks: this.loadingChunks.size,
            loadQueue: this.loadQueue.length,
            playerChunk: this.lastPlayerChunk,
            playerPosition: this.playerPosition
        };
    }

    /**
     * Cleanup all resources
     */
    dispose() {
        // Unload all chunks
        for (const chunkKey of this.loadedChunks.keys()) {
            this.unloadChunk(chunkKey);
        }
        
        this.loadedChunks.clear();
        this.loadingChunks.clear();
        this.loadQueue = [];
        this.unloadQueue = [];
    }
}

/**
 * Base class for chunk data providers
 */
class ChunkProvider {
    constructor(options) {
        this.options = options;
        this.streamingSystem = null;
    }

    setStreamingSystem(system) {
        this.streamingSystem = system;
    }

    async loadChunk(chunkCoords) {
        throw new Error('loadChunk must be implemented by subclass');
    }
}

/**
 * Heightmap-based chunk provider
 */
class HeightmapChunkProvider extends ChunkProvider {
    async loadChunk(chunkCoords) {
        // This will be implemented in the HeightmapTerrainGenerator
        const { HeightmapTerrainGenerator } = await import('./heightmap_terrain_generator');
        const generator = new HeightmapTerrainGenerator(this.streamingSystem.scene, this.options);
        
        return await generator.generateChunk(chunkCoords);
    }
}

/**
 * Pre-built mesh chunk provider
 */
class MeshChunkProvider extends ChunkProvider {
    async loadChunk(chunkCoords) {
        // Load pre-built .babylon or .glb files for special areas
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        const meshPath = `/assets/terrain/chunks/${chunkKey}.babylon`;
        
        try {
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            await import('@babylonjs/loaders/babylonFileLoader');
            
            const result = await SceneLoader.ImportMeshAsync("", "/assets/terrain/chunks/", `${chunkKey}.babylon`, this.streamingSystem.scene);
            
            return {
                mesh: result.meshes[0],
                meshes: result.meshes,
                chunkCoords: chunkCoords,
                worldPosition: this.streamingSystem.chunkToWorldCoords(chunkCoords)
            };
        } catch (error) {
            console.warn(`No mesh file found for chunk ${chunkKey}, falling back to heightmap`);
            return null;
        }
    }
}

/**
 * Procedural chunk provider for infinite worlds
 */
class ProceduralChunkProvider extends ChunkProvider {
    async loadChunk(chunkCoords) {
        // Generate procedural terrain using heightmap generator
        const { HeightmapTerrainGenerator } = await import('./heightmap_terrain_generator');
        const generator = new HeightmapTerrainGenerator(this.streamingSystem.scene, this.options);
        
        return await generator.generateChunk(chunkCoords);
    }
}