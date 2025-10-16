// Character Model Manager - Replaces Babylon.js character system
import * as THREE from "three";
import { FBXLoader } from "three/examples/jsm/loaders/FBXLoader.js";
import type { 
  PlayerCharacter, 
  CreatureNPC, 
  LoadedModel, 
  ModelLoadOptions 
} from '../types';

export class CharacterModelManager {
  private loadedModels: Map<string, LoadedModel> = new Map();
  private characters: Map<string, PlayerCharacter> = new Map();
  private creatures: Map<string, CreatureNPC> = new Map();

  constructor() {
    console.log('🎭 CharacterModelManager initialized');
  }

  // Load FBX character models
  async loadCharacterModel(
    modelPath: string, 
    characterType: string,
    options: Partial<ModelLoadOptions> = {}
  ): Promise<LoadedModel> {
    const cacheKey = `${characterType}_${modelPath}`;
    
    if (this.loadedModels.has(cacheKey)) {
      return this.loadedModels.get(cacheKey)!;
    }

    console.log(`🔄 Loading character model: ${characterType} from ${modelPath}`);

    try {
      // This would normally use FBXLoader
      const model = await this.loadFBXModel(modelPath, options);
      this.loadedModels.set(cacheKey, model);
      
      console.log(`✅ Character model loaded: ${characterType}`);
      return model;
    } catch (error) {
      console.error(`❌ Failed to load character model ${characterType}:`, error);
      throw error;
    }
  }

  // Create player character instance
  async createPlayerCharacter(
    id: string,
    name: string,
    characterType: string,
    position: { x: number; y: number; z: number } = { x: 0, y: 0, z: 0 },
    isLocalPlayer: boolean = false
  ): Promise<PlayerCharacter> {
    // Get the model path based on character type
    const modelPath = this.getCharacterModelPath(characterType);
    
    // Load the model if not already loaded
    const loadedModel = await this.loadCharacterModel(modelPath, characterType);
    
    // Clone the model for this character instance
    const characterMesh = this.cloneModel(loadedModel);
    characterMesh.position.set(position.x, position.y, position.z);

    // Create animation mixer
    const mixer = loadedModel.animations.length > 0 
      ? new THREE.AnimationMixer(characterMesh) 
      : null;

    // Setup animations
    const animations = new Map();
    if (mixer && loadedModel.animations.length > 0) {
      loadedModel.animations.forEach((animation, index) => {
        const actionName = this.getAnimationName(index);
        const action = mixer.clipAction(animation);
        animations.set(actionName, action);
      });
    }

    const character: PlayerCharacter = {
      id,
      name,
      mesh: characterMesh,
      mixer,
      animations,
      position: new THREE.Vector3(position.x, position.y, position.z),
      rotation: new THREE.Euler(0, 0, 0),
      stats: {
        level: 1,
        health: 100,
        maxHealth: 100,
        mana: 50,
        maxMana: 50,
        experience: 0,
        strength: 10,
        dexterity: 10,
        intelligence: 10,
        constitution: 10
      },
      equipment: {
        helmet: null,
        armor: null,
        weapon: null,
        shield: null,
        boots: null,
        gloves: null
      },
      isMoving: false,
      isLocalPlayer
    };

    this.characters.set(id, character);
    
    // Add to scene
    if (window.ThreeJSMMO?.scene?.scene) {
      window.ThreeJSMMO.scene.scene.add(characterMesh);
    }

    console.log(`✅ Player character created: ${name} (${characterType})`);
    return character;
  }

  // Create creature/NPC instance  
  async createCreature(
    id: string,
    creatureType: string,
    name: string,
    position: { x: number; y: number; z: number } = { x: 0, y: 0, z: 0 }
  ): Promise<CreatureNPC> {
    const modelPath = this.getCreatureModelPath(creatureType);
    const loadedModel = await this.loadCharacterModel(modelPath, creatureType);
    
    const creatureMesh = this.cloneModel(loadedModel);
    creatureMesh.position.set(position.x, position.y, position.z);

    const mixer = loadedModel.animations.length > 0 
      ? new THREE.AnimationMixer(creatureMesh) 
      : null;

    const animations = new Map();
    if (mixer && loadedModel.animations.length > 0) {
      loadedModel.animations.forEach((animation, index) => {
        const actionName = this.getAnimationName(index);
        const action = mixer.clipAction(animation);
        animations.set(actionName, action);
      });
    }

    const creature: CreatureNPC = {
      id,
      type: creatureType,
      name,
      mesh: creatureMesh,
      mixer,
      animations,
      position: new THREE.Vector3(position.x, position.y, position.z),
      rotation: new THREE.Euler(0, 0, 0),
      stats: this.getCreatureStats(creatureType),
      aiState: 'idle',
      isHostile: this.isCreatureHostile(creatureType)
    };

    this.creatures.set(id, creature);
    
    // Add to scene
    if (window.ThreeJSMMO?.scene?.scene) {
      window.ThreeJSMMO.scene.scene.add(creatureMesh);
    }

    console.log(`✅ Creature created: ${name} (${creatureType})`);
    return creature;
  }

  // Play character animation
  playCharacterAnimation(characterId: string, animationName: string, loop: boolean = true): void {
    const character = this.characters.get(characterId);
    if (!character || !character.animations.has(animationName)) {
      console.warn(`Animation ${animationName} not found for character ${characterId}`);
      return;
    }

    // Stop current animations
    character.animations.forEach(action => action.stop());

    // Play new animation
    const action = character.animations.get(animationName)!;
    action.reset();
    if (loop) {
      action.setLoop(2, Infinity); // THREE.LoopRepeat
    }
    action.play();

    console.log(`🎬 Playing animation ${animationName} for character ${characterId}`);
  }

  // Update character position
  updateCharacterPosition(
    characterId: string, 
    position: { x: number; y: number; z: number },
    rotation?: { x: number; y: number; z: number }
  ): void {
    const character = this.characters.get(characterId);
    if (!character) return;

    character.mesh.position.set(position.x, position.y, position.z);
    character.position.set(position.x, position.y, position.z);

    if (rotation) {
      character.mesh.rotation.set(rotation.x, rotation.y, rotation.z);
      character.rotation.set(rotation.x, rotation.y, rotation.z);
    }
  }

  // Remove character
  removeCharacter(characterId: string): void {
    const character = this.characters.get(characterId);
    if (character) {
      // Remove from scene
      if (window.ThreeJSMMO?.scene?.scene) {
        window.ThreeJSMMO.scene.scene.remove(character.mesh);
      }
      
      // Dispose resources
      this.disposeCharacterMesh(character.mesh);
      
      this.characters.delete(characterId);
      console.log(`🗑️ Character removed: ${characterId}`);
    }
  }

  // Remove creature
  removeCreature(creatureId: string): void {
    const creature = this.creatures.get(creatureId);
    if (creature) {
      // Remove from scene
      if (window.ThreeJSMMO?.scene?.scene) {
        window.ThreeJSMMO.scene.scene.remove(creature.mesh);
      }
      
      // Dispose resources
      this.disposeCharacterMesh(creature.mesh);
      
      this.creatures.delete(creatureId);
      console.log(`🗑️ Creature removed: ${creatureId}`);
    }
  }

  // Get all characters
  getAllCharacters(): Map<string, PlayerCharacter> {
    return this.characters;
  }

  // Get all creatures
  getAllCreatures(): Map<string, CreatureNPC> {
    return this.creatures;
  }

  // Private helper methods
  private async loadFBXModel(modelPath: string, options: Partial<ModelLoadOptions>): Promise<LoadedModel> {
    // Use the FBXLoader from the bundle
    return new Promise((resolve, reject) => {
      const loader = new FBXLoader();
      loader.load(
        modelPath,
        (fbx: any) => {
          // Apply options
          if (options.scale) {
            fbx.scale.setScalar(options.scale);
          }
          if (options.position) {
            fbx.position.set(options.position.x, options.position.y, options.position.z);
          }
          if (options.rotation) {
            fbx.rotation.set(options.rotation.x, options.rotation.y, options.rotation.z);
          }
          if (options.castShadow) {
            fbx.traverse((child: any) => {
              if (child.isMesh) child.castShadow = true;
            });
          }
          if (options.receiveShadow) {
            fbx.traverse((child: any) => {
              if (child.isMesh) child.receiveShadow = true;
            });
          }

          const model: LoadedModel = {
            name: modelPath.split('/').pop() || 'unknown',
            mesh: fbx,
            animations: fbx.animations || [],
            mixer: null,
            boundingBox: { 
              min: new THREE.Vector3(-1, 0, -1), 
              max: new THREE.Vector3(1, 4, 1) 
            },
            triangleCount: 100 // Placeholder
          };

          resolve(model);
        },
        (progress: any) => {
          // Progress callback
        },
        (error: any) => {
          console.error('FBX loading error:', error);
          reject(error);
        }
      );
    });
  }

  private cloneModel(loadedModel: LoadedModel): any {
    // Clone the Three.js group/mesh
    return loadedModel.mesh.clone();
  }

  private getCharacterModelPath(characterType: string): string {
    const modelPaths: Record<string, string> = {
      'human_male': '/models/characters/human/male/human_male_base.fbx',
      'human_female': '/models/characters/human/female/human_female_base.fbx',
      'elf_male': '/models/characters/elf/male/elf_male_base.fbx',
      'elf_female': '/models/characters/elf/female/elf_female_base.fbx',
      'dwarf_male': '/models/characters/dwarf/male/dwarf_male_base.fbx',
      'dwarf_female': '/models/characters/dwarf/female/dwarf_female_base.fbx'
    };

    return modelPaths[characterType] || modelPaths['human_male'];
  }

  private getCreatureModelPath(creatureType: string): string {
    const modelPaths: Record<string, string> = {
      'skeleton': '/models/creatures/skeleton/skeleton_warrior.fbx',
      'orc': '/models/creatures/orc/orc_warrior.fbx',
      'spider': '/models/creatures/spider/giant_spider.fbx',
      'wolf': '/models/creatures/wolf/dire_wolf.fbx',
      'goblin': '/models/creatures/goblin/goblin_warrior.fbx'
    };

    return modelPaths[creatureType] || modelPaths['skeleton'];
  }

  private getAnimationName(index: number): string {
    const animationNames = [
      'idle', 'walk', 'run', 'attack', 'cast', 'death', 'jump', 'crouch'
    ];
    return animationNames[index] || `animation_${index}`;
  }

  private getCreatureStats(creatureType: string): any {
    const creatureStats: Record<string, any> = {
      'skeleton': { level: 5, health: 50, maxHealth: 50, damage: 15, defense: 5, speed: 1.0 },
      'orc': { level: 8, health: 80, maxHealth: 80, damage: 20, defense: 10, speed: 0.8 },
      'spider': { level: 3, health: 30, maxHealth: 30, damage: 10, defense: 2, speed: 1.5 },
      'wolf': { level: 6, health: 60, maxHealth: 60, damage: 18, defense: 8, speed: 1.2 },
      'goblin': { level: 4, health: 40, maxHealth: 40, damage: 12, defense: 6, speed: 1.1 }
    };

    return creatureStats[creatureType] || creatureStats['skeleton'];
  }

  private isCreatureHostile(creatureType: string): boolean {
    const hostileCreatures = ['skeleton', 'orc', 'spider', 'wolf', 'goblin'];
    return hostileCreatures.includes(creatureType);
  }

  private disposeCharacterMesh(mesh: any): void {
    // Recursively dispose of geometries and materials
    mesh.traverse((child: any) => {
      if (child.geometry) {
        child.geometry.dispose();
      }
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach((material: any) => material.dispose());
        } else {
          child.material.dispose();
        }
      }
    });
  }

  // Cleanup all resources
  dispose(): void {
    // Remove all characters
    this.characters.forEach((_, id) => this.removeCharacter(id));
    
    // Remove all creatures
    this.creatures.forEach((_, id) => this.removeCreature(id));
    
    // Clear caches
    this.loadedModels.clear();
    
    console.log('✅ CharacterModelManager disposed');
  }
}

export default CharacterModelManager;