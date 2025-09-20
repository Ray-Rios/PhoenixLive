// Zone management system for EQ-style zone transitions
import { BabylonLazyLoader } from './lazy_loader';

export class ZoneManager {
    constructor(hook) {
        this.hook = hook;
        this.currentZone = null;
        this.loadedZones = new Map();
        this.zoneDefinitions = new Map();
        this.transitionCallbacks = new Map();
        
        this.setupDefaultZones();
    }

    setupDefaultZones() {
        // Define available zones
        this.zoneDefinitions.set('lobby', {
            name: 'Character Lobby',
            scenePath: '/assets/babylon/lobby_scene.babylon',
            spawnPoint: { x: 0, y: 1, z: 0 },
            zoneLines: [
                { name: 'tutorial', x: 10, z: 10, radius: 2, targetZone: 'tutorial' }
            ],
            requiresPhysics: false,
            requiresGUI: true
        });

        this.zoneDefinitions.set('tutorial', {
            name: 'Tutorial Zone',
            scenePath: '/assets/babylon/tutorial_scene.babylon',
            spawnPoint: { x: 0, y: 1, z: -10 },
            zoneLines: [
                { name: 'lobby', x: 0, z: -15, radius: 2, targetZone: 'lobby' }
            ],
            requiresPhysics: true,
            requiresGUI: false
        });
    }

    async loadZone(zoneName, spawnPoint = null) {
        console.log(`Loading zone: ${zoneName}`);
        
        if (!this.zoneDefinitions.has(zoneName)) {
            throw new Error(`Zone '${zoneName}' not found`);
        }

        const zoneConfig = this.zoneDefinitions.get(zoneName);
        
        // Show loading screen
        this.hook.showLoadingIndicator(`Loading ${zoneConfig.name}...`);

        try {
            // Unload current zone if exists
            if (this.currentZone) {
                await this.unloadZone(this.currentZone);
            }

            // Load required Babylon modules for this zone
            await this.loadZoneRequirements(zoneConfig);

            // Load the actual zone
            const zone = await this.loadZoneAssets(zoneName, zoneConfig);
            
            // Set spawn point
            const spawn = spawnPoint || zoneConfig.spawnPoint;
            this.hook.moveCharacterTo(spawn.x, spawn.y, spawn.z);

            // Setup zone lines
            this.setupZoneLines(zoneName, zoneConfig.zoneLines);

            this.currentZone = zoneName;
            this.loadedZones.set(zoneName, zone);

            console.log(`Zone '${zoneName}' loaded successfully`);
            this.hook.hideLoadingIndicator();

            // Notify Phoenix about zone change
            this.hook.pushEvent('zone_changed', { zone: zoneName, spawn });

        } catch (error) {
            console.error(`Failed to load zone '${zoneName}':`, error);
            this.hook.hideLoadingIndicator();
            this.hook.handleError('zone_load_failed', { zone: zoneName, error: error.message });
        }
    }

    async loadZoneRequirements(zoneConfig) {
        const promises = [];

        if (zoneConfig.requiresPhysics) {
            promises.push(BabylonLazyLoader.loadPhysics());
        }

        if (zoneConfig.requiresGUI) {
            promises.push(BabylonLazyLoader.loadGUI());
        }

        await Promise.all(promises);
    }

    async loadZoneAssets(zoneName, zoneConfig) {
        // Check if zone is already loaded
        if (this.loadedZones.has(zoneName)) {
            return this.loadedZones.get(zoneName);
        }

        // Load zone-specific assets
        const zone = {
            name: zoneName,
            config: zoneConfig,
            meshes: [],
            materials: [],
            animations: []
        };

        // Load the scene file if it exists
        if (zoneConfig.scenePath) {
            const sceneData = await this.loadSceneFile(zoneConfig.scenePath);
            zone.sceneData = sceneData;
        }

        return zone;
    }

    async loadSceneFile(scenePath) {
        try {
            // Use Babylon's scene loader for .babylon files
            const { SceneLoader } = await import('@babylonjs/core/Loading/sceneLoader');
            await import('@babylonjs/loaders/babylonFileLoader');
            
            return new Promise((resolve, reject) => {
                SceneLoader.ImportMesh("", "", scenePath, this.hook.scene, 
                    (meshes, particleSystems, skeletons, animationGroups) => {
                        resolve({ meshes, particleSystems, skeletons, animationGroups });
                    },
                    null, // progress callback
                    (scene, message) => {
                        reject(new Error(`Failed to load scene: ${message}`));
                    }
                );
            });
        } catch (error) {
            console.warn(`Scene file not found: ${scenePath}, creating default zone`);
            return this.createDefaultZone();
        }
    }

    createDefaultZone() {
        // Create a simple default zone with a ground plane
        const { MeshBuilder, StandardMaterial, Color3 } = this.hook.babylon;
        
        const ground = MeshBuilder.CreateGround("ground", { width: 20, height: 20 }, this.hook.scene);
        const groundMaterial = new StandardMaterial("groundMat", this.hook.scene);
        groundMaterial.diffuseColor = new Color3(0.2, 0.6, 0.2);
        ground.material = groundMaterial;

        return { meshes: [ground], particleSystems: [], skeletons: [], animationGroups: [] };
    }

    setupZoneLines(zoneName, zoneLines) {
        // Clear existing zone line triggers
        this.clearZoneLines();

        zoneLines.forEach(zoneLine => {
            this.createZoneLine(zoneLine);
        });
    }

    createZoneLine(zoneLine) {
        // Create invisible trigger mesh for zone transition
        const { MeshBuilder } = this.hook.babylon;
        
        const trigger = MeshBuilder.CreateSphere(`zoneline_${zoneLine.name}`, 
            { diameter: zoneLine.radius * 2 }, this.hook.scene);
        trigger.position.x = zoneLine.x;
        trigger.position.z = zoneLine.z;
        trigger.position.y = 0.5; // Slightly above ground
        trigger.isVisible = false; // Make it invisible
        
        // Store zone line data
        trigger.metadata = {
            type: 'zoneline',
            targetZone: zoneLine.targetZone,
            name: zoneLine.name
        };

        // Add to scene for collision detection
        this.hook.scene.registerBeforeRender(() => {
            if (this.hook.character) {
                const distance = trigger.position.subtract(this.hook.character.position).length();
                if (distance < zoneLine.radius) {
                    this.triggerZoneTransition(zoneLine.targetZone);
                }
            }
        });
    }

    clearZoneLines() {
        // Remove existing zone line meshes
        const meshesToRemove = this.hook.scene.meshes.filter(mesh => 
            mesh.metadata && mesh.metadata.type === 'zoneline'
        );
        
        meshesToRemove.forEach(mesh => {
            mesh.dispose();
        });
    }

    triggerZoneTransition(targetZone) {
        // Prevent rapid zone switching
        if (this.isTransitioning) return;
        
        this.isTransitioning = true;
        
        // Add small delay to prevent accidental transitions
        setTimeout(() => {
            this.loadZone(targetZone).finally(() => {
                this.isTransitioning = false;
            });
        }, 500);
    }

    async unloadZone(zoneName) {
        if (!this.loadedZones.has(zoneName)) return;

        const zone = this.loadedZones.get(zoneName);
        
        // Clean up meshes
        if (zone.sceneData && zone.sceneData.meshes) {
            zone.sceneData.meshes.forEach(mesh => {
                if (mesh && !mesh.isDisposed()) {
                    mesh.dispose();
                }
            });
        }

        // Clean up animations
        if (zone.sceneData && zone.sceneData.animationGroups) {
            zone.sceneData.animationGroups.forEach(group => {
                group.dispose();
            });
        }

        this.loadedZones.delete(zoneName);
        console.log(`Zone '${zoneName}' unloaded`);
    }

    getCurrentZone() {
        return this.currentZone;
    }

    getZoneConfig(zoneName) {
        return this.zoneDefinitions.get(zoneName);
    }

    addZone(zoneName, config) {
        this.zoneDefinitions.set(zoneName, config);
    }

    listAvailableZones() {
        return Array.from(this.zoneDefinitions.keys());
    }
}