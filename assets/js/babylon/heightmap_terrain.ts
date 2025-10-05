// Heightmap Terrain System - TypeScript version
import { Vector3, MeshBuilder, StandardMaterial, Color3, Ray } from './babylon_imports';
import { HeightmapTerrainInterface, TerrainOptions } from '../types/babylon-hooks';

export class HeightmapTerrain implements HeightmapTerrainInterface {
    public scene: any;
    public options: Required<TerrainOptions>;

    constructor(scene: any, options: TerrainOptions = {}) {
        this.scene = scene;
        this.options = {
            size: 100,
            subdivisions: 64,
            maxHeight: 10,
            ...options
        };
    }

    /**
     * Create terrain from heightmap image
     */
    async createFromImage(imagePath: string): Promise<any> {
        try {
            const heightData = await this.loadHeightmapImage(imagePath);
            return this.createTerrainMesh(heightData);
        } catch (error) {
            console.warn('Failed to load heightmap, creating flat terrain:', error);
            return this.createFlatTerrain();
        }
    }

    /**
     * Load heightmap from image
     */
    async loadHeightmapImage(imagePath: string): Promise<number[]> {
        return new Promise<number[]>((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = "anonymous";
            
            img.onload = () => {
                try {
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    
                    if (!ctx) {
                        reject(new Error('Could not get 2D context from canvas'));
                        return;
                    }
                    
                    canvas.width = this.options.subdivisions + 1;
                    canvas.height = this.options.subdivisions + 1;
                    
                    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                    
                    const heights: number[] = [];
                    for (let i = 0; i < imageData.data.length; i += 4) {
                        // Use red channel for height
                        const height = (imageData.data[i] / 255) * this.options.maxHeight;
                        heights.push(height);
                    }
                    
                    resolve(heights);
                } catch (error) {
                    reject(error);
                }
            };
            
            img.onerror = () => reject(new Error(`Failed to load heightmap: ${imagePath}`));
            img.src = imagePath;
        });
    }

    /**
     * Create terrain mesh from height data
     */
    createTerrainMesh(heights: number[]): any {
        const subdivisions = this.options.subdivisions;
        const size = this.options.size;
        
        // Create ground with custom heights
        const ground = MeshBuilder.CreateGround('heightmapTerrain', {
            width: size,
            height: size,
            subdivisions: subdivisions
        }, this.scene);
        
        // Modify vertices based on height data
        const positions = ground.getVerticesData('position'); // Use string instead of VertexData.PositionKind
        
        if (positions) {
            for (let i = 0; i < positions.length; i += 3) {
                const vertexIndex = Math.floor(i / 3);
                if (vertexIndex < heights.length) {
                    positions[i + 1] = heights[vertexIndex]; // Y coordinate
                }
            }
            
            ground.setVerticesData('position', positions); // Use string instead of VertexData.PositionKind
            ground.createNormals(true);
        }
        
        // Apply material
        const material = new StandardMaterial('terrainMaterial', this.scene);
        material.diffuseColor = new Color3(0.4, 0.6, 0.3);
        ground.material = material;
        
        ground.checkCollisions = true;
        
        return ground;
    }

    /**
     * Create flat terrain as fallback
     */
    createFlatTerrain(): any {
        const ground = MeshBuilder.CreateGround('flatTerrain', {
            width: this.options.size,
            height: this.options.size,
            subdivisions: 4
        }, this.scene);
        
        const material = new StandardMaterial('flatTerrainMaterial', this.scene);
        material.diffuseColor = new Color3(0.3, 0.5, 0.3);
        ground.material = material;
        
        ground.checkCollisions = true;
        
        return ground;
    }

    /**
     * Get height at world position
     */
    getHeightAtPosition(x: number, z: number, terrain: any): number {
        if (!terrain) return 0;
        
        // Simple height sampling - you could improve this with interpolation
        const ray = new Ray(new Vector3(x, 100, z), new Vector3(0, -1, 0));
        const hit = this.scene.pickWithRay(ray, (mesh: any) => mesh === terrain);
        
        return hit.hit ? hit.pickedPoint.y : 0;
    }
}