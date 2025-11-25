// RAW Heightmap Terrain Loader for EverQuest-style worlds
import * as THREE from 'three';

export interface HeightmapConfig {
  width: number;
  height: number;
  depth: number;
  segments: number;
  heightScale: number;
  textureRepeat: number;
}

export class HeightmapTerrainLoader {
  private terrain: THREE.Mesh | null = null;
  private heightData: Uint8Array | null = null;
  private config: HeightmapConfig;

  constructor(config: Partial<HeightmapConfig> = {}) {
    this.config = {
      width: config.width || 512,
      height: config.height || 512,
      depth: config.depth || 100,
      segments: config.segments || 255,
      heightScale: config.heightScale || 50,
      textureRepeat: config.textureRepeat || 20
    };
  }

  /**
   * Load a .raw heightmap file (8-bit grayscale heightmap)
   * CraterLake.raw is expected to be 512x512 8-bit unsigned
   */
  async loadRAWHeightmap(url: string): Promise<THREE.Mesh> {
    console.log(`🗺️ Loading RAW heightmap from: ${url}`);

    try {
      // Fetch the raw file
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Failed to fetch heightmap: ${response.statusText}`);
      }

      const arrayBuffer = await response.arrayBuffer();
      this.heightData = new Uint8Array(arrayBuffer);

      console.log(`✅ Loaded ${this.heightData.length} bytes of heightmap data`);

      // Create terrain mesh
      this.terrain = this.createTerrainMesh();

      return this.terrain;
    } catch (error) {
      console.error('❌ Failed to load RAW heightmap:', error);
      throw error;
    }
  }

  /**
   * Create terrain mesh from loaded heightmap data
   */
  private createTerrainMesh(): THREE.Mesh {
    if (!this.heightData) {
      throw new Error('No heightmap data loaded');
    }

    const { width, height, segments, heightScale, textureRepeat } = this.config;

    // Create plane geometry
    const geometry = new THREE.PlaneGeometry(
      width,
      height,
      segments,
      segments
    );

    // Rotate to be horizontal
    geometry.rotateX(-Math.PI / 2);

    // Apply heightmap data to vertices
    const vertices = geometry.attributes.position.array as Float32Array;

    for (let i = 0; i < segments + 1; i++) {
      for (let j = 0; j < segments + 1; j++) {
        const index = (i * (segments + 1) + j) * 3;
        
        // Sample heightmap (normalized coordinates)
        const u = Math.floor((j / segments) * Math.sqrt(this.heightData.length));
        const v = Math.floor((i / segments) * Math.sqrt(this.heightData.length));
        const heightIndex = v * Math.sqrt(this.heightData.length) + u;
        
        // Get height value (0-255) and normalize
        const heightValue = this.heightData[Math.floor(heightIndex)] || 0;
        const normalizedHeight = (heightValue / 255) * heightScale;

        // Set Y coordinate (was Z before rotation)
        vertices[index + 1] = normalizedHeight;
      }
    }

    // Recalculate normals for proper lighting
    geometry.computeVertexNormals();

    // Create material with grass texture
    const material = new THREE.MeshStandardMaterial({
      color: 0x567d46,
      roughness: 0.8,
      metalness: 0.2,
      wireframe: false
    });

    // Try to load terrain texture
    const textureLoader = new THREE.TextureLoader();
    textureLoader.load(
      '/images/textures/grass.jpg',
      (texture) => {
        texture.wrapS = THREE.RepeatWrapping;
        texture.wrapT = THREE.RepeatWrapping;
        texture.repeat.set(textureRepeat, textureRepeat);
        material.map = texture;
        material.needsUpdate = true;
      },
      undefined,
      () => {
        console.warn('⚠️ Failed to load grass texture, using color instead');
      }
    );

    const mesh = new THREE.Mesh(geometry, material);
    mesh.receiveShadow = true;
    mesh.castShadow = false;
    mesh.name = 'terrain';

    console.log(`✅ Created terrain mesh: ${segments}x${segments} vertices`);

    return mesh;
  }

  /**
   * Get height at world position (for character placement)
   */
  getHeightAt(x: number, z: number): number {
    if (!this.heightData || !this.terrain) {
      return 0;
    }

    const { width, height, segments, heightScale } = this.config;

    // Convert world coordinates to heightmap coordinates
    const u = ((x + width / 2) / width) * segments;
    const v = ((z + height / 2) / height) * segments;

    // Clamp to valid range
    const uClamped = Math.max(0, Math.min(segments, Math.floor(u)));
    const vClamped = Math.max(0, Math.min(segments, Math.floor(v)));

    // Get heightmap data size
    const dataSize = Math.sqrt(this.heightData.length);
    const heightIndex = Math.floor(vClamped * (dataSize / segments) * dataSize + uClamped * (dataSize / segments));

    if (heightIndex < 0 || heightIndex >= this.heightData.length) {
      return 0;
    }

    const heightValue = this.heightData[heightIndex];
    return (heightValue / 255) * heightScale;
  }

  /**
   * Dispose terrain resources
   */
  dispose(): void {
    if (this.terrain) {
      this.terrain.geometry.dispose();
      if (Array.isArray(this.terrain.material)) {
        this.terrain.material.forEach(mat => mat.dispose());
      } else {
        this.terrain.material.dispose();
      }
      this.terrain = null;
    }
    this.heightData = null;
  }

  getTerrain(): THREE.Mesh | null {
    return this.terrain;
  }
}

export default HeightmapTerrainLoader;
