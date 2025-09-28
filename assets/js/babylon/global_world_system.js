// Global World Coordinate System for Seamless Open-World Experience
import { Vector3, Vector2 } from './babylon_imports';

/**
 * Manages a global coordinate system that seamlessly connects different terrain types
 * Handles coordinate transformations between chunks, zones, and world positions
 */
export class GlobalWorldSystem {
    constructor(options = {}) {
        this.options = {
            worldSize: 10000,        // Total world size in units (10km x 10km default)
            chunkSize: 256,          // Size of each chunk
            zoneSize: 2048,          // Size of each zone (8x8 chunks)
            seaLevel: 0,             // Global sea level
            worldOrigin: { x: 0, y: 0, z: 0 }, // World center point
            coordinateSystem: 'centered', // 'centered' or 'positive'
            ...options
        };
        
        // World structure
        this.worldRegions = new Map();     // Different biomes/regions
        this.zoneDefinitions = new Map();  // Zone templates and configs
        this.heightmapSources = new Map(); // Different heightmap sources
        this.biomeRules = new Map();       // Rules for biome generation
        
        // Coordinate helpers
        this.coordinateCache = new Map();
        
        this.initializeWorldSystem();
    }

    /**
     * Initialize the world coordinate system
     */
    initializeWorldSystem() {
        console.log('Initializing Global World System');
        
        // Setup default regions and biomes
        this.setupDefaultRegions();
        
        // Setup coordinate system boundaries
        this.calculateWorldBounds();
        
        console.log(`World System: ${this.options.worldSize}x${this.options.worldSize} units`);
        console.log(`Chunk System: ${this.options.chunkSize} units per chunk`);
        console.log(`Zone System: ${this.options.zoneSize} units per zone`);
    }

    /**
     * Setup default world regions and biomes
     */
    setupDefaultRegions() {
        // Define different biome regions
        this.addWorldRegion('grasslands', {
            center: { x: 0, z: 0 },
            radius: 1000,
            heightRange: { min: 0, max: 30 },
            terrainType: 'heightmap',
            biome: 'temperate',
            heightmapSource: 'procedural_plains'
        });
        
        this.addWorldRegion('mountains', {
            center: { x: 2000, z: 1000 },
            radius: 800,
            heightRange: { min: 20, max: 100 },
            terrainType: 'heightmap',
            biome: 'alpine',
            heightmapSource: 'procedural_mountains'
        });
        
        this.addWorldRegion('desert', {
            center: { x: -1500, z: 1500 },
            radius: 600,
            heightRange: { min: 0, max: 20 },
            terrainType: 'heightmap',
            biome: 'arid',
            heightmapSource: 'procedural_desert'
        });
        
        this.addWorldRegion('forest', {
            center: { x: -1000, z: -1000 },
            radius: 700,
            heightRange: { min: 0, max: 40 },
            terrainType: 'heightmap',
            biome: 'forest',
            heightmapSource: 'procedural_forest'
        });
        
        // Special handcrafted areas
        this.addWorldRegion('starting_area', {
            center: { x: 0, z: 0 },
            radius: 200,
            heightRange: { min: 0, max: 15 },
            terrainType: 'mesh',
            biome: 'starter',
            meshSource: '/assets/terrain/special/starting_area.babylon'
        });
    }

    /**
     * Add a world region definition
     */
    addWorldRegion(name, config) {
        this.worldRegions.set(name, {
            name: name,
            center: new Vector2(config.center.x, config.center.z),
            radius: config.radius,
            heightRange: config.heightRange,
            terrainType: config.terrainType,
            biome: config.biome,
            heightmapSource: config.heightmapSource,
            meshSource: config.meshSource,
            priority: config.priority || 0 // Higher priority regions override lower ones
        });
    }

    /**
     * Calculate world boundaries and coordinate limits
     */
    calculateWorldBounds() {
        const halfWorld = this.options.worldSize / 2;
        
        if (this.options.coordinateSystem === 'centered') {
            this.worldBounds = {
                minX: -halfWorld,
                maxX: halfWorld,
                minZ: -halfWorld,
                maxZ: halfWorld
            };
        } else {
            this.worldBounds = {
                minX: 0,
                maxX: this.options.worldSize,
                minZ: 0,
                maxZ: this.options.worldSize
            };
        }
        
        // Calculate chunk and zone counts
        this.chunksPerAxis = Math.ceil(this.options.worldSize / this.options.chunkSize);
        this.zonesPerAxis = Math.ceil(this.options.worldSize / this.options.zoneSize);
        
        console.log(`World bounds: ${this.worldBounds.minX},${this.worldBounds.minZ} to ${this.worldBounds.maxX},${this.worldBounds.maxZ}`);
        console.log(`Chunks per axis: ${this.chunksPerAxis}, Zones per axis: ${this.zonesPerAxis}`);
    }

    /**
     * Convert world coordinates to chunk coordinates
     */
    worldToChunkCoords(worldPos) {
        const chunkX = Math.floor((worldPos.x - this.worldBounds.minX) / this.options.chunkSize);
        const chunkZ = Math.floor((worldPos.z - this.worldBounds.minZ) / this.options.chunkSize);
        
        return new Vector2(chunkX, chunkZ);
    }

    /**
     * Convert chunk coordinates to world position (chunk center)
     */
    chunkToWorldCoords(chunkCoords) {
        const worldX = this.worldBounds.minX + (chunkCoords.x * this.options.chunkSize) + (this.options.chunkSize / 2);
        const worldZ = this.worldBounds.minZ + (chunkCoords.y * this.options.chunkSize) + (this.options.chunkSize / 2);
        
        return new Vector3(worldX, 0, worldZ);
    }

    /**
     * Convert world coordinates to zone coordinates
     */
    worldToZoneCoords(worldPos) {
        const zoneX = Math.floor((worldPos.x - this.worldBounds.minX) / this.options.zoneSize);
        const zoneZ = Math.floor((worldPos.z - this.worldBounds.minZ) / this.options.zoneSize);
        
        return new Vector2(zoneX, zoneZ);
    }

    /**
     * Convert zone coordinates to world position (zone center)
     */
    zoneToWorldCoords(zoneCoords) {
        const worldX = this.worldBounds.minX + (zoneCoords.x * this.options.zoneSize) + (this.options.zoneSize / 2);
        const worldZ = this.worldBounds.minZ + (zoneCoords.y * this.options.zoneSize) + (this.options.zoneSize / 2);
        
        return new Vector3(worldX, 0, worldZ);
    }

    /**
     * Get chunk coordinates within a zone
     */
    getChunksInZone(zoneCoords) {
        const chunksPerZone = this.options.zoneSize / this.options.chunkSize;
        const chunks = [];
        
        const startChunkX = zoneCoords.x * chunksPerZone;
        const startChunkZ = zoneCoords.y * chunksPerZone;
        
        for (let x = 0; x < chunksPerZone; x++) {
            for (let z = 0; z < chunksPerZone; z++) {
                chunks.push(new Vector2(startChunkX + x, startChunkZ + z));
            }
        }
        
        return chunks;
    }

    /**
     * Determine which region(s) influence a specific world position
     */
    getRegionsForPosition(worldPos) {
        const regions = [];
        
        for (const [name, region] of this.worldRegions) {
            const distance = Vector2.Distance(
                new Vector2(worldPos.x, worldPos.z),
                region.center
            );
            
            if (distance <= region.radius) {
                regions.push({
                    region: region,
                    distance: distance,
                    influence: Math.max(0, 1 - (distance / region.radius)) // 1 = full influence, 0 = no influence
                });
            }
        }
        
        // Sort by priority, then by influence
        regions.sort((a, b) => {
            if (a.region.priority !== b.region.priority) {
                return b.region.priority - a.region.priority;
            }
            return b.influence - a.influence;
        });
        
        return regions;
    }

    /**
     * Get the primary terrain type for a chunk
     */
    getTerrainTypeForChunk(chunkCoords) {
        const worldPos = this.chunkToWorldCoords(chunkCoords);
        const regions = this.getRegionsForPosition(worldPos);
        
        if (regions.length > 0) {
            return {
                type: regions[0].region.terrainType,
                source: regions[0].region.heightmapSource || regions[0].region.meshSource,
                biome: regions[0].region.biome,
                regions: regions
            };
        }
        
        // Default fallback
        return {
            type: 'heightmap',
            source: 'procedural_default',
            biome: 'temperate',
            regions: []
        };
    }

    /**
     * Generate heightmap parameters for a chunk based on its world position and regions
     */
    getHeightmapConfigForChunk(chunkCoords) {
        const worldPos = this.chunkToWorldCoords(chunkCoords);
        const regions = this.getRegionsForPosition(worldPos);
        
        let config = {
            heightScale: 1.0,
            noiseScale: 1.0,
            octaves: 4,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: 1234,
            heightOffset: this.options.seaLevel
        };
        
        // Blend configurations from influencing regions
        if (regions.length > 0) {
            let totalInfluence = 0;
            let blendedHeight = 0;
            let blendedScale = 0;
            
            regions.forEach(regionInfo => {
                const region = regionInfo.region;
                const influence = regionInfo.influence;
                
                totalInfluence += influence;
                
                // Blend height ranges
                const avgHeight = (region.heightRange.min + region.heightRange.max) / 2;
                blendedHeight += avgHeight * influence;
                
                // Adjust noise scale based on terrain type
                if (region.biome === 'mountains') {
                    blendedScale += 2.0 * influence;
                } else if (region.biome === 'plains') {
                    blendedScale += 0.5 * influence;
                } else {
                    blendedScale += 1.0 * influence;
                }
            });
            
            if (totalInfluence > 0) {
                config.heightOffset = blendedHeight / totalInfluence;
                config.heightScale = blendedScale / totalInfluence;
            }
        }
        
        return config;
    }

    /**
     * Check if world coordinates are valid
     */
    isValidWorldPosition(worldPos) {
        return worldPos.x >= this.worldBounds.minX && 
               worldPos.x <= this.worldBounds.maxX &&
               worldPos.z >= this.worldBounds.minZ && 
               worldPos.z <= this.worldBounds.maxZ;
    }

    /**
     * Clamp world coordinates to valid bounds
     */
    clampToWorldBounds(worldPos) {
        return new Vector3(
            Math.max(this.worldBounds.minX, Math.min(this.worldBounds.maxX, worldPos.x)),
            worldPos.y,
            Math.max(this.worldBounds.minZ, Math.min(this.worldBounds.maxZ, worldPos.z))
        );
    }

    /**
     * Get distance to nearest world boundary
     */
    getDistanceToWorldBoundary(worldPos) {
        const distanceToEdges = [
            worldPos.x - this.worldBounds.minX,    // Distance to left edge
            this.worldBounds.maxX - worldPos.x,    // Distance to right edge
            worldPos.z - this.worldBounds.minZ,    // Distance to front edge
            this.worldBounds.maxZ - worldPos.z     // Distance to back edge
        ];
        
        return Math.min(...distanceToEdges);
    }

    /**
     * Generate a world map overview (for minimap/debugging)
     */
    generateWorldMap(resolution = 256) {
        const map = {
            size: resolution,
            data: new Uint8Array(resolution * resolution * 4), // RGBA
            regions: []
        };
        
        const scale = this.options.worldSize / resolution;
        
        for (let y = 0; y < resolution; y++) {
            for (let x = 0; x < resolution; x++) {
                const worldX = this.worldBounds.minX + (x * scale);
                const worldZ = this.worldBounds.minZ + (y * scale);
                const worldPos = new Vector3(worldX, 0, worldZ);
                
                const regions = this.getRegionsForPosition(worldPos);
                const idx = (y * resolution + x) * 4;
                
                if (regions.length > 0) {
                    const color = this.getBiomeColor(regions[0].region.biome);
                    map.data[idx] = color.r;     // R
                    map.data[idx + 1] = color.g; // G
                    map.data[idx + 2] = color.b; // B
                    map.data[idx + 3] = 255;     // A
                } else {
                    // Default ocean/void color
                    map.data[idx] = 50;      // R
                    map.data[idx + 1] = 100; // G
                    map.data[idx + 2] = 150; // B
                    map.data[idx + 3] = 255; // A
                }
            }
        }
        
        return map;
    }

    /**
     * Get representative color for biome type
     */
    getBiomeColor(biome) {
        const colors = {
            temperate: { r: 100, g: 200, b: 100 },
            alpine: { r: 200, g: 200, b: 200 },
            arid: { r: 200, g: 180, b: 100 },
            forest: { r: 50, g: 150, b: 50 },
            starter: { r: 150, g: 150, b: 255 },
            ocean: { r: 50, g: 100, b: 200 }
        };
        
        return colors[biome] || colors.temperate;
    }

    /**
     * Get world system statistics
     */
    getWorldStats() {
        return {
            worldSize: this.options.worldSize,
            chunkSize: this.options.chunkSize,
            zoneSize: this.options.zoneSize,
            totalChunks: this.chunksPerAxis * this.chunksPerAxis,
            totalZones: this.zonesPerAxis * this.zonesPerAxis,
            regions: Array.from(this.worldRegions.keys()),
            bounds: this.worldBounds
        };
    }

    /**
     * Update world system configuration
     */
    updateConfiguration(newOptions) {
        this.options = { ...this.options, ...newOptions };
        this.calculateWorldBounds();
        
        console.log('World system configuration updated:', this.options);
    }

    /**
     * Add or update heightmap source
     */
    addHeightmapSource(name, source) {
        this.heightmapSources.set(name, source);
    }

    /**
     * Get heightmap source configuration
     */
    getHeightmapSource(name) {
        return this.heightmapSources.get(name);
    }

    /**
     * Cleanup world system
     */
    dispose() {
        this.worldRegions.clear();
        this.zoneDefinitions.clear();
        this.heightmapSources.clear();
        this.biomeRules.clear();
        this.coordinateCache.clear();
    }
}