// Heightmap Terrain Generator for Seamless Open-World Terrain
import { Vector3, Vector2, Color3, MeshBuilder, StandardMaterial, VertexData, DynamicTexture } from './babylon_imports';

/**
 * Generates terrain meshes from heightmap data with seamless blending between chunks
 */
export class HeightmapTerrainGenerator {
    constructor(scene, options = {}) {
        this.scene = scene;
        this.options = {
            chunkSize: 256,           // World units
            heightmapResolution: 257, // Heightmap resolution (vertices per chunk edge)
            maxHeight: 50,            // Maximum terrain height
            textureResolution: 512,   // Terrain texture resolution
            subdivisions: 64,         // Mesh subdivisions (lower = better performance)
            seaLevel: 0,              // Sea level height
            blendWidth: 8,            // Width of blending area between chunks (vertices)
            ...options
        };
        
        // Heightmap cache to ensure seamless borders
        this.heightmapCache = new Map();
        this.noiseGenerator = new TerrainNoiseGenerator();
        this.materialCache = new Map();
    }

    /**
     * Generate a terrain chunk from heightmap data
     */
    async generateChunk(chunkCoords) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        console.log(`Generating heightmap terrain chunk: ${chunkKey}`);
        
        try {
            // Get or generate heightmap data for this chunk
            const heightmapData = await this.getHeightmapData(chunkCoords);
            
            // Create mesh from heightmap
            const mesh = this.createTerrainMesh(chunkCoords, heightmapData);
            
            // Apply materials and textures
            const material = await this.createTerrainMaterial(chunkCoords, heightmapData);
            mesh.material = material;
            
            // Position the mesh in world space
            const worldPos = this.chunkToWorldCoords(chunkCoords);
            mesh.position.copyFrom(worldPos);
            
            // Set up collision detection
            mesh.checkCollisions = true;
            
            const chunkData = {
                mesh: mesh,
                material: material,
                chunkCoords: chunkCoords,
                worldPosition: worldPos,
                heightmapData: heightmapData,
                type: 'heightmap'
            };
            
            console.log(`✅ Generated terrain chunk: ${chunkKey}`);
            return chunkData;
            
        } catch (error) {
            console.error(`❌ Failed to generate terrain chunk ${chunkKey}:`, error);
            return this.createFallbackChunk(chunkCoords);
        }
    }

    /**
     * Get or generate heightmap data for a chunk
     */
    async getHeightmapData(chunkCoords) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        
        // Check cache first
        if (this.heightmapCache.has(chunkKey)) {
            return this.heightmapCache.get(chunkKey);
        }
        
        // Try to load from file first
        const heightmapData = await this.loadHeightmapFromFile(chunkCoords) || 
                              await this.generateProceduralHeightmap(chunkCoords);
        
        // Cache the heightmap data
        this.heightmapCache.set(chunkKey, heightmapData);
        
        return heightmapData;
    }

    /**
     * Load heightmap from file (PNG, RAW, etc.)
     */
    async loadHeightmapFromFile(chunkCoords) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        const heightmapPath = `/assets/terrain/heightmaps/${chunkKey}.png`;
        
        try {
            return await this.loadPNGHeightmap(heightmapPath);
        } catch (error) {
            // Throttle missing heightmap logs to avoid spam
            if (!this.loggedMissingPaths) this.loggedMissingPaths = new Set();
            if (!this.loggedMissingPaths.has(heightmapPath)) {
                console.log(`No heightmap file found: ${heightmapPath}`);
                this.loggedMissingPaths.add(heightmapPath);
            }
            return null;
        }
    }

    /**
     * Load heightmap from PNG file
     */
    async loadPNGHeightmap(imagePath) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = "anonymous";
            
            img.onload = () => {
                try {
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    
                    canvas.width = this.options.heightmapResolution;
                    canvas.height = this.options.heightmapResolution;
                    
                    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                    
                    const heightData = this.extractHeightsFromImageData(imageData);
                    resolve(heightData);
                } catch (error) {
                    reject(error);
                }
            };
            
            img.onerror = () => reject(new Error(`Failed to load heightmap: ${imagePath}`));
            img.src = imagePath;
        });
    }

    /**
     * Extract height values from image data
     */
    extractHeightsFromImageData(imageData) {
        const resolution = this.options.heightmapResolution;
        const heights = new Float32Array(resolution * resolution);
        const data = imageData.data;
        
        for (let y = 0; y < resolution; y++) {
            for (let x = 0; x < resolution; x++) {
                const idx = (y * resolution + x) * 4;
                // Use red channel for height (0-255 -> 0-maxHeight)
                const heightValue = (data[idx] / 255) * this.options.maxHeight;
                heights[y * resolution + x] = heightValue;
            }
        }
        
        return {
            heights: heights,
            resolution: resolution,
            maxHeight: this.options.maxHeight
        };
    }

    /**
     * Generate procedural heightmap using noise
     */
    async generateProceduralHeightmap(chunkCoords) {
        const resolution = this.options.heightmapResolution;
        const heights = new Float32Array(resolution * resolution);
        
        // World coordinates for this chunk
        const worldX = chunkCoords.x * this.options.chunkSize;
        const worldZ = chunkCoords.y * this.options.chunkSize;
        
        // Generate heights using multiple octaves of noise
        for (let y = 0; y < resolution; y++) {
            for (let x = 0; x < resolution; x++) {
                const worldPosX = worldX + (x / (resolution - 1)) * this.options.chunkSize;
                const worldPosZ = worldZ + (y / (resolution - 1)) * this.options.chunkSize;
                
                let height = 0;
                
                // Multiple octaves for varied terrain
                height += this.noiseGenerator.noise(worldPosX * 0.005, worldPosZ * 0.005) * 30;  // Large features
                height += this.noiseGenerator.noise(worldPosX * 0.02, worldPosZ * 0.02) * 10;    // Medium features  
                height += this.noiseGenerator.noise(worldPosX * 0.1, worldPosZ * 0.1) * 2;       // Small details
                
                heights[y * resolution + x] = Math.max(this.options.seaLevel, height);
            }
        }
        
        return {
            heights: heights,
            resolution: resolution,
            maxHeight: this.options.maxHeight
        };
    }

    /**
     * Create terrain mesh from heightmap data
     */
    createTerrainMesh(chunkCoords, heightmapData) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        const resolution = heightmapData.resolution;
        const subdivisions = this.options.subdivisions;
        
        // Create custom mesh with heightmap-modified vertices
        const positions = [];
        const normals = [];
        const uvs = [];
        const indices = [];
        
        // Generate vertices
        for (let row = 0; row <= subdivisions; row++) {
            for (let col = 0; col <= subdivisions; col++) {
                // Position in chunk space (0 to chunkSize)
                const x = (col / subdivisions) * this.options.chunkSize;
                const z = (row / subdivisions) * this.options.chunkSize;
                
                // Get height from heightmap (with interpolation)
                const heightmapX = (col / subdivisions) * (resolution - 1);
                const heightmapZ = (row / subdivisions) * (resolution - 1);
                const height = this.sampleHeight(heightmapData.heights, heightmapX, heightmapZ, resolution);
                
                positions.push(x, height, z);
                uvs.push(col / subdivisions, row / subdivisions);
            }
        }
        
        // Generate indices for triangles
        for (let row = 0; row < subdivisions; row++) {
            for (let col = 0; col < subdivisions; col++) {
                const topLeft = row * (subdivisions + 1) + col;
                const topRight = topLeft + 1;
                const bottomLeft = (row + 1) * (subdivisions + 1) + col;
                const bottomRight = bottomLeft + 1;
                
                // Two triangles per quad
                indices.push(topLeft, bottomLeft, topRight);
                indices.push(topRight, bottomLeft, bottomRight);
            }
        }
        
        // Calculate normals
        VertexData.ComputeNormals(positions, indices, normals);
        
        // Create mesh
        const mesh = new MeshBuilder.CreateGround(`terrain_${chunkKey}`, {
            width: this.options.chunkSize,
            height: this.options.chunkSize,
            subdivisions: subdivisions
        }, this.scene);
        
        // Apply custom vertex data
        const vertexData = new VertexData();
        vertexData.positions = positions;
        vertexData.normals = normals;
        vertexData.uvs = uvs;
        vertexData.indices = indices;
        
        vertexData.applyToMesh(mesh);
        
        return mesh;
    }

    /**
     * Sample height from heightmap with bilinear interpolation
     */
    sampleHeight(heights, x, z, resolution) {
        // Clamp coordinates
        x = Math.max(0, Math.min(resolution - 1, x));
        z = Math.max(0, Math.min(resolution - 1, z));
        
        // Get integer and fractional parts
        const x0 = Math.floor(x);
        const x1 = Math.min(resolution - 1, x0 + 1);
        const z0 = Math.floor(z);
        const z1 = Math.min(resolution - 1, z0 + 1);
        
        const fx = x - x0;
        const fz = z - z0;
        
        // Sample four corner heights
        const h00 = heights[z0 * resolution + x0];
        const h10 = heights[z0 * resolution + x1];
        const h01 = heights[z1 * resolution + x0];
        const h11 = heights[z1 * resolution + x1];
        
        // Bilinear interpolation
        const h0 = h00 * (1 - fx) + h10 * fx;
        const h1 = h01 * (1 - fx) + h11 * fx;
        
        return h0 * (1 - fz) + h1 * fz;
    }

    /**
     * Create terrain material with texture splatting
     */
    async createTerrainMaterial(chunkCoords, heightmapData) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        
        // Check material cache
        if (this.materialCache.has(chunkKey)) {
            return this.materialCache.get(chunkKey);
        }
        
        const material = new StandardMaterial(`terrain_mat_${chunkKey}`, this.scene);
        
        // Basic texture based on height
        const texture = this.createHeightBasedTexture(heightmapData);
        material.diffuseTexture = texture;
        
        // Additional properties
        material.specularColor = new Color3(0.1, 0.1, 0.1);
        material.emissiveColor = new Color3(0.05, 0.05, 0.05);
        
        this.materialCache.set(chunkKey, material);
        
        return material;
    }

    /**
     * Create texture based on height information
     */
    createHeightBasedTexture(heightmapData) {
        // For now, create a simple procedural texture
        // You can expand this to use actual texture splatting with multiple terrain textures
        
        const canvas = document.createElement('canvas');
        canvas.width = this.options.textureResolution;
        canvas.height = this.options.textureResolution;
        
        const ctx = canvas.getContext('2d');
        const imageData = ctx.createImageData(canvas.width, canvas.height);
        const data = imageData.data;
        
        const resolution = heightmapData.resolution;
        
        for (let y = 0; y < canvas.height; y++) {
            for (let x = 0; x < canvas.width; x++) {
                // Sample height from heightmap
                const heightmapX = (x / canvas.width) * (resolution - 1);
                const heightmapY = (y / canvas.height) * (resolution - 1);
                const height = this.sampleHeight(heightmapData.heights, heightmapX, heightmapY, resolution);
                
                const idx = (y * canvas.width + x) * 4;
                
                // Color based on height
                if (height < this.options.seaLevel + 2) {
                    // Sand/shore
                    data[idx] = 194;     // R
                    data[idx + 1] = 178; // G  
                    data[idx + 2] = 128; // B
                } else if (height < 15) {
                    // Grass
                    data[idx] = 34;      // R
                    data[idx + 1] = 139; // G
                    data[idx + 2] = 34;  // B
                } else if (height < 35) {
                    // Rock
                    data[idx] = 105;     // R
                    data[idx + 1] = 105; // G
                    data[idx + 2] = 105; // B
                } else {
                    // Snow
                    data[idx] = 255;     // R
                    data[idx + 1] = 255; // G
                    data[idx + 2] = 255; // B
                }
                
                data[idx + 3] = 255; // A
            }
        }
        
        ctx.putImageData(imageData, 0, 0);
        
        // Create Babylon texture from canvas
        const texture = new DynamicTexture("terrainTexture", canvas, this.scene, false);
        // Clamp to avoid seams at edges when sampling
        if (texture.wrapU !== undefined) {
            texture.wrapU = 0; // CLAMP_ADDRESSMODE equivalent in Babylon core enums (0)
        }
        if (texture.wrapV !== undefined) {
            texture.wrapV = 0;
        }
        
        return texture;
    }

    /**
     * Create simple fallback chunk if generation fails
     */
    createFallbackChunk(chunkCoords) {
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        
        // Create simple flat ground
        const mesh = MeshBuilder.CreateGround(`fallback_${chunkKey}`, {
            width: this.options.chunkSize,
            height: this.options.chunkSize,
            subdivisions: 4
        }, this.scene);
        
        const material = new StandardMaterial(`fallback_mat_${chunkKey}`, this.scene);
        material.diffuseColor = new Color3(0.5, 0.5, 0.5);
        mesh.material = material;
        
        const worldPos = this.chunkToWorldCoords(chunkCoords);
        mesh.position.copyFrom(worldPos);
        
        return {
            mesh: mesh,
            material: material,
            chunkCoords: chunkCoords,
            worldPosition: worldPos,
            type: 'fallback'
        };
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
     * Get height at specific world coordinates (for character controllers)
     */
    getHeightAtWorldPosition(worldX, worldZ) {
        // Determine which chunk contains this position
        const chunkCoords = new Vector2(
            Math.floor(worldX / this.options.chunkSize),
            Math.floor(worldZ / this.options.chunkSize)
        );
        
        const chunkKey = `${chunkCoords.x}_${chunkCoords.y}`;
        const heightmapData = this.heightmapCache.get(chunkKey);
        
        if (!heightmapData) {
            return 0; // Default height if chunk not loaded
        }
        
        // Convert to local coordinates within the chunk
        const localX = worldX - (chunkCoords.x * this.options.chunkSize);
        const localZ = worldZ - (chunkCoords.y * this.options.chunkSize);
        
        // Convert to heightmap coordinates
        const heightmapX = (localX / this.options.chunkSize) * (heightmapData.resolution - 1);
        const heightmapZ = (localZ / this.options.chunkSize) * (heightmapData.resolution - 1);
        
        return this.sampleHeight(heightmapData.heights, heightmapX, heightmapZ, heightmapData.resolution);
    }
}

/**
 * Simple noise generator for procedural terrain
 */
class TerrainNoiseGenerator {
    constructor(seed = 1234) {
        this.seed = seed;
    }

    // Simple Perlin-like noise implementation
    noise(x, y) {
        const n = Math.sin(x * 12.9898 + y * 78.233 + this.seed) * 43758.5453;
        return n - Math.floor(n); // Return 0-1
    }
}