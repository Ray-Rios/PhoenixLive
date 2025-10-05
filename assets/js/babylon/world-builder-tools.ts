// World Builder Material Library
// Provides materials for infinite world building

import { StandardMaterial, Color3, MeshBuilder, initializeBabylonExports, getBabylon } from './babylon_imports';

export class MaterialLibrary {
    scene: any;
    materials: Map<string, any>;

    constructor(scene: any) {
        this.scene = scene;
        this.materials = new Map();
        this.initializeMaterials();
    }

    initializeMaterials() {
        // Grass Material
        const grassMat = new StandardMaterial('grass', this.scene);
        grassMat.diffuseColor = new Color3(0.3, 0.7, 0.2);
        grassMat.specularColor = new Color3(0.1, 0.1, 0.1);
        this.materials.set('grass', {
            material: grassMat,
            name: 'Grass',
            icon: '🌱',
            category: 'terrain'
        });

        // Stone Material
        const stoneMat = new StandardMaterial('stone', this.scene);
        stoneMat.diffuseColor = new Color3(0.5, 0.5, 0.5);
        stoneMat.specularColor = new Color3(0.2, 0.2, 0.2);
        this.materials.set('stone', {
            material: stoneMat,
            name: 'Stone',
            icon: '🪨',
            category: 'terrain'
        });

        // Sand Material
        const sandMat = new StandardMaterial('sand', this.scene);
        sandMat.diffuseColor = new Color3(0.8, 0.7, 0.5);
        sandMat.specularColor = new Color3(0.1, 0.1, 0.1);
        this.materials.set('sand', {
            material: sandMat,
            name: 'Sand',
            icon: '🏖️',
            category: 'terrain'
        });

        // Dirt Material
        const dirtMat = new StandardMaterial('dirt', this.scene);
        dirtMat.diffuseColor = new Color3(0.4, 0.3, 0.2);
        dirtMat.specularColor = new Color3(0.05, 0.05, 0.05);
        this.materials.set('dirt', {
            material: dirtMat,
            name: 'Dirt',
            icon: '🟤',
            category: 'terrain'
        });

        // Wood Material
        const woodMat = new StandardMaterial('wood', this.scene);
        woodMat.diffuseColor = new Color3(0.6, 0.4, 0.2);
        woodMat.specularColor = new Color3(0.1, 0.1, 0.1);
        this.materials.set('wood', {
            material: woodMat,
            name: 'Wood',
            icon: '🪵',
            category: 'building'
        });

        // Metal Material
        const metalMat = new StandardMaterial('metal', this.scene);
        metalMat.diffuseColor = new Color3(0.7, 0.7, 0.8);
        metalMat.specularColor = new Color3(0.9, 0.9, 0.9);
        this.materials.set('metal', {
            material: metalMat,
            name: 'Metal',
            icon: '⚙️',
            category: 'building'
        });

        // Crystal Material
        const crystalMat = new StandardMaterial('crystal', this.scene);
        crystalMat.diffuseColor = new Color3(0.8, 0.2, 0.8);
        crystalMat.specularColor = new Color3(1.0, 1.0, 1.0);
        crystalMat.alpha = 0.8;
        this.materials.set('crystal', {
            material: crystalMat,
            name: 'Crystal',
            icon: '💎',
            category: 'special'
        });

        console.log('🎨 Material library initialized with', this.materials.size, 'materials');
    }

    getMaterial(name: string) {
        return this.materials.get(name);
    }

    getAllMaterials() {
        return Array.from(this.materials.values());
    }

    getMaterialsByCategory(category: string) {
        return Array.from(this.materials.values()).filter(mat => mat.category === category);
    }

    getCategories() {
        const categories = new Set();
        this.materials.forEach(mat => categories.add(mat.category));
        return Array.from(categories);
    }
}

// World Building Tool System
export class WorldBuilderTools {
    private scene: any;
    private materialLibrary: MaterialLibrary;
    private currentTool: string;
    private currentMaterial: string;
    private brushSize: number;
    private brushStrength: number;
    private selectedObjects: any[];

    constructor(scene: any, materialLibrary: MaterialLibrary) {
        this.scene = scene;
        this.materialLibrary = materialLibrary;
        this.currentTool = 'raise'; // raise, lower, paint, place
        this.currentMaterial = 'grass';
        this.brushSize = 5;
        this.brushStrength = 1;
        this.selectedObjects = [];
        // Build mode flag will be read from global Hook instance if available
        
        this.setupEventHandlers();
    }

    setupEventHandlers() {
        // Handle terrain editing via pointer events
        this.scene.onPointerObservable.add((eventData: any) => {
            // Use event type constants directly - POINTERDOWN = 1
            if (eventData.type === 1) { // POINTERDOWN
                this.handleTerrainEdit(eventData);
            }
        });
    }

    handleTerrainEdit(eventData: any) {
        // Respect build mode flag: only allow if OpenWorldLobbySceneHook.buildMode true
        try {
            const hook = (window as any).OpenWorldLobbySceneHook;
            if (hook && hook.buildMode === false) {
                return; // editing disabled
            }
            // Block edits if pointer currently over UI panels (sliders, buttons, etc.)
            if (hook && hook.pointerOverUI) {
                return;
            }
        } catch (_) { /* ignore */ }
        const pickInfo = this.scene.pick(this.scene.pointerX, this.scene.pointerY);
        
        if (pickInfo.hit && pickInfo.pickedMesh) {
            const position = pickInfo.pickedPoint;
            
            switch (this.currentTool) {
                case 'raise':
                    this.raiseTerrain(position);
                    break;
                case 'lower':
                    this.lowerTerrain(position);
                    break;
                case 'paint':
                    this.paintTerrain(pickInfo.pickedMesh, position);
                    break;
                case 'place':
                    this.placeObject(position);
                    break;
            }
        }
    }

    raiseTerrain(position: any) {
        try {
            const hook = (window as any).OpenWorldLobbySceneHook;
            if (hook && !hook.buildMode) return;
        } catch(_) {}
        // Create a small hill at the position
        const hill = MeshBuilder.CreateSphere('hill', {diameter: this.brushSize * 2}, this.scene);
        hill.position = position.clone();
        hill.position.y += this.brushStrength;
        
        const material = this.materialLibrary.getMaterial(this.currentMaterial);
        if (material) {
            hill.material = material.material;
        }
        
        console.log('⬆️ Raised terrain at', position);
    }

    lowerTerrain(position: any) {
        try {
            const hook = (window as any).OpenWorldLobbySceneHook;
            if (hook && !hook.buildMode) return;
        } catch(_) {}
        // Create a small depression (inverse hill)
        const depression = MeshBuilder.CreateSphere('depression', {diameter: this.brushSize * 2}, this.scene);
        depression.position = position.clone();
        depression.position.y -= this.brushStrength;
        
        const material = this.materialLibrary.getMaterial('dirt');
        if (material) {
            depression.material = material.material;
        }
        
        console.log('⬇️ Lowered terrain at', position);
    }

    paintTerrain(mesh: any, position: any) {
        try {
            const hook = (window as any).OpenWorldLobbySceneHook;
            if (hook && !hook.buildMode) return;
        } catch(_) {}
        // Change the material of the picked mesh
        const material = this.materialLibrary.getMaterial(this.currentMaterial);
        if (material && mesh) {
            mesh.material = material.material;
            console.log('🎨 Painted terrain with', this.currentMaterial);
        }
    }

    placeObject(position: any) {
        try {
            const hook = (window as any).OpenWorldLobbySceneHook;
            if (hook && !hook.buildMode) return;
        } catch(_) {}
        // Place a basic object at the position
        const obj = MeshBuilder.CreateBox('placedObject', {size: 2}, this.scene);
        obj.position = position.clone();
        obj.position.y += 1; // Place above surface
        
        const material = this.materialLibrary.getMaterial(this.currentMaterial);
        if (material) {
            obj.material = material.material;
        }
        
        this.selectedObjects.push(obj);
        console.log('📦 Placed object at', position);
    }

    setTool(toolName: string) {
        this.currentTool = toolName;
        console.log('🔧 Tool changed to:', toolName);
    }

    setMaterial(materialName: string) {
        this.currentMaterial = materialName;
        console.log('🎨 Material changed to:', materialName);
    }

    setBrushSize(size: number) {
        this.brushSize = Math.max(1, Math.min(20, size));
        console.log('🖌️ Brush size:', this.brushSize);
    }

    setBrushStrength(strength: number) {
        this.brushStrength = Math.max(0.1, Math.min(10, strength));
        console.log('💪 Brush strength:', this.brushStrength);
    }

    deleteSelected() {
        this.selectedObjects.forEach(obj => {
            if (obj.dispose) {
                obj.dispose();
            }
        });
        this.selectedObjects = [];
        console.log('🗑️ Deleted selected objects');
    }

    clearAll() {
        // Clear all user-created objects (keep terrain and water)
        this.scene.meshes.forEach((mesh: any) => {
            if (mesh.name.includes('hill') || 
                mesh.name.includes('depression') || 
                mesh.name.includes('placedObject')) {
                mesh.dispose();
            }
        });
        this.selectedObjects = [];
        console.log('🧹 Cleared all user objects');
    }
}

export { StandardMaterial, Color3, MeshBuilder } from './babylon_imports';