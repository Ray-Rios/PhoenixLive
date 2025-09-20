import { Vector3, MeshBuilder, StandardMaterial, Color3 } from './babylon_imports';

/**
 * Babylon.js Scene Loader for Editor-created scenes
 * Handles loading scenes created with the Babylon.js Editor
 */
export class BabylonSceneLoader {
    constructor(scene) {
        this.scene = scene;
        this.loadedScenes = new Map();
    }

    /**
     * Load a scene created with Babylon.js Editor
     * @param {string} scenePath - Path to the .babylon scene file
     * @param {Object} options - Loading options
     * @returns {Promise} Promise that resolves when scene is loaded
     */
    async loadEditorScene(scenePath, options = {}) {
        console.log('Loading editor scene:', scenePath);

        try {
            const result = await SceneLoader.ImportMeshAsync(
                "", // meshNames - empty string loads all
                this.getBasePath(scenePath),
                this.getFileName(scenePath),
                this.scene
            );

            // Process loaded content
            const loadedScene = {
                meshes: result.meshes,
                particleSystems: result.particleSystems,
                skeletons: result.skeletons,
                animationGroups: result.animationGroups,
                transformNodes: result.transformNodes
            };

            // Apply any post-processing options
            if (options.enablePhysics) {
                this.enablePhysicsForMeshes(result.meshes);
            }

            if (options.enableInteractions) {
                this.enableInteractionsForMeshes(result.meshes);
            }

            // Store loaded scene
            this.loadedScenes.set(scenePath, loadedScene);

            console.log('Editor scene loaded successfully:', loadedScene);
            return loadedScene;

        } catch (error) {
            console.error('Failed to load editor scene:', error);
            throw error;
        }
    }

    /**
     * Load a scene project file (.bjseditor)
     * @param {string} projectPath - Path to the .bjseditor project file
     * @returns {Promise} Promise that resolves when project is loaded
     */
    async loadEditorProject(projectPath) {
        console.log('Loading editor project:', projectPath);

        try {
            // Load the project configuration
            const response = await fetch(projectPath);
            const projectData = await response.json();

            // Extract scene information
            const sceneFile = projectData.scene || 'scene.babylon';
            const scenePath = this.getBasePath(projectPath) + sceneFile;

            // Load the actual scene
            return await this.loadEditorScene(scenePath, {
                enablePhysics: projectData.physics?.enabled || false,
                enableInteractions: true
            });

        } catch (error) {
            console.error('Failed to load editor project:', error);
            throw error;
        }
    }

    /**
     * Enable physics for loaded meshes
     * @param {Array} meshes - Array of meshes to enable physics for
     */
    enablePhysicsForMeshes(meshes) {
        if (!this.scene.getPhysicsEngine()) {
            console.warn('Physics engine not available');
            return;
        }

        meshes.forEach(mesh => {
            if (mesh.name.startsWith('__root__')) return; // Skip root nodes

            // Check if mesh has physics metadata from editor
            const physicsData = mesh.metadata?.physics;
            
            if (physicsData || mesh.metadata?.enablePhysics) {
                const mass = physicsData?.mass || (mesh.name.includes('static') ? 0 : 1);
                const restitution = physicsData?.restitution || 0.7;
                
                mesh.physicsImpostor = new PhysicsImpostor(
                    mesh,
                    this.getPhysicsImpostorType(mesh),
                    { mass, restitution },
                    this.scene
                );

                console.log(`Physics enabled for ${mesh.name}:`, { mass, restitution });
            }
        });
    }

    /**
     * Enable interactions for loaded meshes
     * @param {Array} meshes - Array of meshes to enable interactions for
     */
    enableInteractionsForMeshes(meshes) {
        meshes.forEach(mesh => {
            if (mesh.name.startsWith('__root__')) return;

            // Check if mesh should be interactive
            const interactiveData = mesh.metadata?.interactive;
            
            if (interactiveData !== false) { // Default to interactive
                mesh.isPickable = true;
                mesh.metadata = {
                    ...mesh.metadata,
                    interactive: true,
                    clickable: true
                };
            }
        });
    }

    /**
     * Get appropriate physics impostor type for mesh
     * @param {BABYLON.Mesh} mesh - The mesh to analyze
     * @returns {number} Physics impostor type
     */
    getPhysicsImpostorType(mesh) {
        const name = mesh.name.toLowerCase();
        
        if (name.includes('sphere') || name.includes('ball')) {
            return PhysicsImpostor.SphereImpostor;
        } else if (name.includes('plane') || name.includes('ground') || name.includes('floor')) {
            return PhysicsImpostor.PlaneImpostor;
        } else if (name.includes('cylinder')) {
            return PhysicsImpostor.CylinderImpostor;
        } else {
            return PhysicsImpostor.BoxImpostor; // Default
        }
    }

    /**
     * Get base path from full path
     * @param {string} fullPath - Full file path
     * @returns {string} Base path
     */
    getBasePath(fullPath) {
        const lastSlash = fullPath.lastIndexOf('/');
        return lastSlash !== -1 ? fullPath.substring(0, lastSlash + 1) : '';
    }

    /**
     * Get filename from full path
     * @param {string} fullPath - Full file path
     * @returns {string} Filename
     */
    getFileName(fullPath) {
        const lastSlash = fullPath.lastIndexOf('/');
        return lastSlash !== -1 ? fullPath.substring(lastSlash + 1) : fullPath;
    }

    /**
     * Get loaded scene by path
     * @param {string} scenePath - Scene path
     * @returns {Object|null} Loaded scene or null
     */
    getLoadedScene(scenePath) {
        return this.loadedScenes.get(scenePath) || null;
    }

    /**
     * Remove loaded scene
     * @param {string} scenePath - Scene path to remove
     */
    removeScene(scenePath) {
        const scene = this.loadedScenes.get(scenePath);
        if (scene) {
            // Dispose of meshes
            scene.meshes.forEach(mesh => mesh.dispose());
            scene.particleSystems.forEach(ps => ps.dispose());
            
            this.loadedScenes.delete(scenePath);
        }
    }

    /**
     * Clear all loaded scenes
     */
    clearAllScenes() {
        this.loadedScenes.forEach((scene, path) => {
            this.removeScene(path);
        });
    }
}