// Level-of-Detail System for Open-World Terrain
import { Vector3, Vector2, MeshBuilder, StandardMaterial, Color3 } from './babylon_imports';

/**
 * Manages different levels of detail for terrain chunks based on distance from player
 * Provides smooth performance scaling for large open worlds
 */
export class TerrainLODSystem {
    constructor(worldStreamingSystem, options = {}) {
        this.streamingSystem = worldStreamingSystem;
        this.scene = worldStreamingSystem.scene;
        
        this.options = {
            lodLevels: [
                { distance: 0,   subdivisions: 64,  textureRes: 512, name: 'high' },    // Close detail
                { distance: 1,   subdivisions: 32,  textureRes: 256, name: 'medium' },  // Medium distance
                { distance: 2,   subdivisions: 16,  textureRes: 128, name: 'low' },     // Far distance
                { distance: 4,   subdivisions: 4,   textureRes: 64,  name: 'ultra_low' } // Very far
            ],
            transitionDistance: 0.5,  // Chunk distances for smooth transitions
            updateInterval: 1000,     // How often to check for LOD updates (ms)
            morphingEnabled: true,    // Enable vertex morphing between LOD levels
            ...options
        };
        
        this.chunkLODs = new Map();     // Track LOD level for each chunk
        this.morphTargets = new Map();  // Store morph targets for transitions
        this.lastUpdateTime = 0;
        this.playerPosition = new Vector3(0, 0, 0);
        
        this.setupLODSystem();
    }

    /**
     * Initialize the LOD system
     */
    setupLODSystem() {
        console.log('Setting up terrain LOD system');
        
        // Sort LOD levels by distance
        this.options.lodLevels.sort((a, b) => a.distance - b.distance);
        
        // Start update loop
        this.startLODUpdateLoop();
    }

    /**
     * Start the LOD update loop
     */
    startLODUpdateLoop() {
        const updateLODs = () => {
            const currentTime = Date.now();
            
            if (currentTime - this.lastUpdateTime > this.options.updateInterval) {
                this.updateChunkLODs();
                this.lastUpdateTime = currentTime;
            }
            
            requestAnimationFrame(updateLODs);
        };
        
        updateLODs();
    }

    /**
     * Update player position (called by character controller)
     */
    updatePlayerPosition(position) {
        this.playerPosition.copyFrom(position);
    }

    /**
     * Update LOD levels for all loaded chunks
     */
    updateChunkLODs() {
        const playerChunkCoords = this.streamingSystem.worldToChunkCoords(this.playerPosition);
        
        // Check all loaded chunks
        for (const [chunkKey, chunkData] of this.streamingSystem.loadedChunks) {
            const chunkCoords = this.streamingSystem.parseChunkKey(chunkKey);
            const distance = this.getChunkDistance(playerChunkCoords, chunkCoords);
            
            const currentLOD = this.chunkLODs.get(chunkKey);
            const targetLOD = this.getLODForDistance(distance);
            
            // Update LOD if it changed
            if (currentLOD !== targetLOD) {
                this.updateChunkLOD(chunkKey, chunkData, currentLOD, targetLOD);
                this.chunkLODs.set(chunkKey, targetLOD);
            }
        }
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
     * Determine appropriate LOD level for distance
     */
    getLODForDistance(distance) {
        for (let i = this.options.lodLevels.length - 1; i >= 0; i--) {
            if (distance >= this.options.lodLevels[i].distance) {
                return this.options.lodLevels[i];
            }
        }
        return this.options.lodLevels[0]; // Default to highest LOD
    }

    /**
     * Update a specific chunk's LOD level
     */
    async updateChunkLOD(chunkKey, chunkData, fromLOD, toLOD) {
        if (fromLOD === toLOD) return;
        
        console.log(`Updating chunk ${chunkKey} LOD: ${fromLOD?.name || 'initial'} → ${toLOD.name}`);
        
        try {
            // Create new mesh with target LOD settings
            const newMesh = await this.createLODMesh(chunkData, toLOD);
            
            if (this.options.morphingEnabled && fromLOD && chunkData.mesh) {
                // Smooth transition between LOD levels
                await this.morphBetweenLODs(chunkData.mesh, newMesh, 500); // 500ms transition
            }
            
            // Replace the old mesh
            if (chunkData.mesh) {
                chunkData.mesh.dispose();
            }
            
            chunkData.mesh = newMesh;
            chunkData.currentLOD = toLOD;
            
        } catch (error) {
            console.error(`Failed to update LOD for chunk ${chunkKey}:`, error);
        }
    }

    /**
     * Create a mesh with specific LOD settings
     */
    async createLODMesh(chunkData, lodLevel) {
        const chunkKey = `${chunkData.chunkCoords.x}_${chunkData.chunkCoords.y}`;
        
        // Different mesh generation based on chunk type
        switch (chunkData.type) {
            case 'heightmap':
                return await this.createHeightmapLODMesh(chunkData, lodLevel);
            case 'mesh':
                return await this.createMeshLODMesh(chunkData, lodLevel);
            default:
                return this.createFallbackLODMesh(chunkData, lodLevel);
        }
    }

    /**
     * Create LOD mesh for heightmap terrain
     */
    async createHeightmapLODMesh(chunkData, lodLevel) {
        const chunkKey = `${chunkData.chunkCoords.x}_${chunkData.chunkCoords.y}`;
        
        // Use the heightmap terrain generator with LOD-specific settings
        const { HeightmapTerrainGenerator } = await import('./heightmap_terrain_generator');
        const generator = new HeightmapTerrainGenerator(this.scene, {
            ...this.streamingSystem.options,
            subdivisions: lodLevel.subdivisions,
            textureResolution: lodLevel.textureRes
        });
        
        // Reuse existing heightmap data if available
        const mesh = generator.createTerrainMesh(chunkData.chunkCoords, chunkData.heightmapData);
        
        // Apply LOD-appropriate material
        const material = await this.createLODMaterial(chunkData, lodLevel);
        mesh.material = material;
        
        // Position the mesh
        mesh.position.copyFrom(chunkData.worldPosition);
        
        return mesh;
    }

    /**
     * Create LOD mesh for imported mesh terrain
     */
    async createMeshLODMesh(chunkData, lodLevel) {
        // For imported meshes, we can use Babylon's built-in LOD system
        const baseMesh = chunkData.meshes[0];
        
        if (baseMesh && baseMesh.addLODLevel) {
            // Create simplified versions of the mesh for different LOD levels
            const lodMesh = baseMesh.createInstance(`${baseMesh.name}_lod_${lodLevel.name}`);
            
            // Adjust material quality for this LOD level
            const material = await this.createLODMaterial(chunkData, lodLevel);
            lodMesh.material = material;
            
            return lodMesh;
        }
        
        // Fallback if LOD system not supported
        return chunkData.meshes[0];
    }

    /**
     * Create fallback LOD mesh
     */
    createFallbackLODMesh(chunkData, lodLevel) {
        const chunkKey = `${chunkData.chunkCoords.x}_${chunkData.chunkCoords.y}`;
        
        const mesh = MeshBuilder.CreateGround(`lod_fallback_${chunkKey}_${lodLevel.name}`, {
            width: this.streamingSystem.options.chunkSize,
            height: this.streamingSystem.options.chunkSize,
            subdivisions: lodLevel.subdivisions
        }, this.scene);
        
        mesh.position.copyFrom(chunkData.worldPosition);
        
        return mesh;
    }

    /**
     * Create material appropriate for LOD level
     */
    async createLODMaterial(chunkData, lodLevel) {
        const chunkKey = `${chunkData.chunkCoords.x}_${chunkData.chunkCoords.y}`;
        const materialKey = `${chunkKey}_lod_${lodLevel.name}`;
        
        const material = new StandardMaterial(materialKey, this.scene);
        
        // Adjust material quality based on LOD level
        switch (lodLevel.name) {
            case 'high':
                material.specularColor = new Color3(0.2, 0.2, 0.2);
                material.emissiveColor = new Color3(0.05, 0.05, 0.05);
                break;
                
            case 'medium':
                material.specularColor = new Color3(0.1, 0.1, 0.1);
                material.emissiveColor = new Color3(0.02, 0.02, 0.02);
                break;
                
            case 'low':
            case 'ultra_low':
                material.specularColor = new Color3(0.05, 0.05, 0.05);
                material.emissiveColor = new Color3(0.01, 0.01, 0.01);
                // Disable expensive features for distant terrain
                material.freeze(); // Optimize material for static use
                break;
        }
        
        // Use cached texture if available, otherwise create simplified one
        if (chunkData.material && chunkData.material.diffuseTexture) {
            // For lower LODs, we might want to create downscaled textures
            material.diffuseTexture = chunkData.material.diffuseTexture;
        } else {
            // Create simple solid color for ultra-low LOD
            const baseColor = this.getTerrainBaseColor(chunkData);
            material.diffuseColor = baseColor;
        }
        
        return material;
    }

    /**
     * Get base color for terrain based on height or biome
     */
    getTerrainBaseColor(chunkData) {
        // Default terrain color - could be enhanced with biome data
        if (chunkData.heightmapData) {
            const avgHeight = this.getAverageHeight(chunkData.heightmapData);
            
            if (avgHeight < 5) {
                return new Color3(0.2, 0.6, 0.2); // Green for low areas
            } else if (avgHeight < 25) {
                return new Color3(0.4, 0.3, 0.2); // Brown for mid areas
            } else {
                return new Color3(0.8, 0.8, 0.8); // Gray for high areas
            }
        }
        
        return new Color3(0.5, 0.5, 0.5); // Default gray
    }

    /**
     * Calculate average height from heightmap data
     */
    getAverageHeight(heightmapData) {
        const heights = heightmapData.heights;
        let total = 0;
        
        for (let i = 0; i < heights.length; i++) {
            total += heights[i];
        }
        
        return total / heights.length;
    }

    /**
     * Smooth morphing between LOD levels
     */
    async morphBetweenLODs(fromMesh, toMesh, duration) {
        if (!fromMesh || !toMesh) return;
        
        return new Promise((resolve) => {
            const startTime = Date.now();
            let animationId;
            
            const animate = () => {
                const elapsed = Date.now() - startTime;
                const progress = Math.min(elapsed / duration, 1);
                
                // Simple alpha blending during transition
                fromMesh.visibility = 1 - progress;
                toMesh.visibility = progress;
                
                if (progress < 1) {
                    animationId = requestAnimationFrame(animate);
                } else {
                    // Cleanup
                    fromMesh.visibility = 0;
                    toMesh.visibility = 1;
                    resolve();
                }
            };
            
            // Start with new mesh invisible
            toMesh.visibility = 0;
            animate();
        });
    }

    /**
     * Force LOD level for a specific chunk (for debugging)
     */
    forceChunkLOD(chunkKey, lodLevelName) {
        const lodLevel = this.options.lodLevels.find(lod => lod.name === lodLevelName);
        if (!lodLevel) {
            console.error(`LOD level '${lodLevelName}' not found`);
            return;
        }
        
        const chunkData = this.streamingSystem.loadedChunks.get(chunkKey);
        if (!chunkData) {
            console.error(`Chunk '${chunkKey}' not loaded`);
            return;
        }
        
        const currentLOD = this.chunkLODs.get(chunkKey);
        this.updateChunkLOD(chunkKey, chunkData, currentLOD, lodLevel);
        this.chunkLODs.set(chunkKey, lodLevel);
    }

    /**
     * Get LOD statistics
     */
    getLODStats() {
        const stats = {
            totalChunks: this.streamingSystem.loadedChunks.size,
            lodBreakdown: {}
        };
        
        // Initialize counters
        this.options.lodLevels.forEach(lod => {
            stats.lodBreakdown[lod.name] = 0;
        });
        
        // Count chunks by LOD level
        for (const [chunkKey, lodLevel] of this.chunkLODs) {
            if (lodLevel && stats.lodBreakdown[lodLevel.name] !== undefined) {
                stats.lodBreakdown[lodLevel.name]++;
            }
        }
        
        return stats;
    }

    /**
     * Configure LOD levels (for runtime adjustment)
     */
    configureLODLevels(newLodLevels) {
        this.options.lodLevels = newLodLevels.sort((a, b) => a.distance - b.distance);
        console.log('LOD levels reconfigured:', this.options.lodLevels);
        
        // Force update of all chunks
        this.chunkLODs.clear();
        this.updateChunkLODs();
    }

    /**
     * Enable/disable morphing transitions
     */
    setMorphingEnabled(enabled) {
        this.options.morphingEnabled = enabled;
        console.log(`LOD morphing ${enabled ? 'enabled' : 'disabled'}`);
    }

    /**
     * Cleanup LOD system
     */
    dispose() {
        // Clear all morph targets
        for (const [key, morphTarget] of this.morphTargets) {
            if (morphTarget.dispose) {
                morphTarget.dispose();
            }
        }
        
        this.chunkLODs.clear();
        this.morphTargets.clear();
    }
}