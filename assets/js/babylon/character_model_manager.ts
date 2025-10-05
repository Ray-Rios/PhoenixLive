// Consolidated Character Model Manager (strict load, dynamic manifest)
import '@babylonjs/loaders';
import { getBabylon, createVector3 } from './babylon_imports';

export interface CharacterModel {
  name: string; mesh: any; animationGroups: any[]; type: CharacterType; scale: { x: number; y: number; z: number }; boundingInfo?: any;
}
export type CharacterType = string;
export interface CharacterTypeConfig { name: string; type: CharacterType; scale: { x: number; y: number; z: number }; preferredFormat: 'gltf' | 'fbx'; fallbackFormat: 'gltf' | 'fbx'; animations?: Record<string,string>; fileName?: string; }

export class CharacterModelManager {
  private scene: any;
  private modelCache: Map<string, CharacterModel> = new Map();
  private availableCharacters: CharacterTypeConfig[] = [];
  private modelsBasePath = '/models/';
  private dynamicNames?: string[];
  private modelLoadPromises: Map<string, Promise<CharacterModel>> = new Map();

  constructor(scene: any, characterNames?: string[]) {
    this.scene = scene;
    this.dynamicNames = characterNames;
    this.initializeCharacterConfigs();
  }

  private initializeCharacterConfigs(): void {
    if (this.dynamicNames && this.dynamicNames.length) {
      this.availableCharacters = this.dynamicNames.map(name => ({
        name,
        type: name.trim().toLowerCase(),
        scale: { x: 1, y: 1, z: 1 },
        preferredFormat: 'gltf',
        fallbackFormat: 'fbx',
        animations: { idle: 'Idle', walk: 'Walk', run: 'Run' }
      }));
      console.log('[CharacterModelManager] Initialized from manifest:', this.availableCharacters.map(c => c.name));
      return;
    }
    this.availableCharacters = [
      { name: 'Eagle', type: 'eagle', scale: { x: 1.2, y: 1.2, z: 1.2 }, preferredFormat: 'gltf', fallbackFormat: 'fbx', animations: { idle: 'Idle', fly: 'Fly' } },
      { name: 'Fox', type: 'fox', scale: { x: 1.0, y: 1.0, z: 1.0 }, preferredFormat: 'gltf', fallbackFormat: 'fbx', animations: { idle: 'Idle', walk: 'Walk', run: 'Run' } },
      { name: 'HoneyBadger', type: 'honey_badger', scale: { x: 1.0, y: 1.0, z: 1.0 }, preferredFormat: 'gltf', fallbackFormat: 'fbx', animations: { idle: 'Idle', walk: 'Walk', run: 'Run' }, fileName: 'Honey Badger' }
    ];
  }

  /**
   * Get a random character type configuration
   */
  public getRandomCharacterConfig(): CharacterTypeConfig {
    const randomIndex = Math.floor(Math.random() * this.availableCharacters.length);
    return this.availableCharacters[randomIndex];
  }

  /**
   * Load a character model by type, with fallback support
   */
  public async loadCharacterModel(characterType: CharacterType): Promise<CharacterModel> {
    
    const cacheKey = characterType;
    
    // Return cached model if available
    if (this.modelCache.has(cacheKey)) {
      return this.cloneCharacterModel(this.modelCache.get(cacheKey)!);
    }

    const config = this.availableCharacters.find(c => c.type === characterType);
    if (!config) {
      throw new Error(`Character type '${characterType}' not found in configuration`);
    }

    let characterModel: CharacterModel;

    try {
      // Try preferred format first
      characterModel = await this.loadModelFromFile(config, config.preferredFormat);
    } catch (primaryError) {
      console.warn(`Failed to load ${config.name} in ${config.preferredFormat} format:`, primaryError);
      
      try {
        // Fallback to alternative format
        characterModel = await this.loadModelFromFile(config, config.fallbackFormat);
        console.log(`Successfully loaded ${config.name} using fallback format: ${config.fallbackFormat}`);
      } catch (fallbackError) {
        console.error(`Failed to load ${config.name} in both formats:`, fallbackError);
        throw new Error(`Could not load character model '${config.name}' in any format`);
      }
    }

    // Cache the loaded model
    this.modelCache.set(cacheKey, characterModel);
    
    // Return a clone for use
    return this.cloneCharacterModel(characterModel);
  }

  /**
   * Load model from specific file format
   */
  private async loadModelFromFile(config: CharacterTypeConfig, format: 'gltf' | 'fbx'): Promise<CharacterModel> {
    await this.ensureLoadersImported(format);
    
    const B = getBabylon();
    if (!B.SceneLoader || typeof B.SceneLoader.ImportMeshAsync !== 'function') {
      throw new Error('SceneLoader not available');
    }
    const fileName = format === 'gltf' ? `${config.fileName || config.name}.gltf` : `${config.fileName || config.name}.fbx`;
    const modelPath = `${this.modelsBasePath}${config.name}/`;
    console.log(`Loading ${config.name} from: ${modelPath}${fileName}`);
    const result = await B.SceneLoader.ImportMeshAsync('', modelPath, fileName, this.scene);
    
    if (!result.meshes || result.meshes.length === 0) {
      throw new Error(`No meshes found in ${fileName}`);
    }

    // Get the root mesh or combine all meshes
    let rootMesh: any;
    if (result.meshes.length === 1) {
      rootMesh = result.meshes[0];
    } else {
      // Create a parent mesh to hold all parts
      if (B.Mesh) {
        try { rootMesh = new B.Mesh(`${config.name}_root`, this.scene); } catch { rootMesh = result.meshes[0]; }
      } else if (B.TransformNode) {
        try { rootMesh = new B.TransformNode(`${config.name}_root`, this.scene); } catch { rootMesh = result.meshes[0]; }
      } else {
        rootMesh = result.meshes[0];
      }
      result.meshes.forEach((mesh: any) => {
        if (mesh !== rootMesh) {
          mesh.setParent(rootMesh);
        }
      });
    }

    // Ensure ALL meshes are visible and enabled
    result.meshes.forEach((mesh: any) => {
      mesh.isVisible = true;
      if (mesh.setEnabled) mesh.setEnabled(true);
      console.log(`📦 Mesh: ${mesh.name}, visible: ${mesh.isVisible}, enabled: ${mesh.isEnabled}`);
    });

    // Apply scaling
  rootMesh.scaling = createVector3(config.scale.x, config.scale.y, config.scale.z);
    
    // Set initial position
  rootMesh.position = createVector3(0, 0, 0);

    const characterModel: CharacterModel = {
      name: config.name,
      mesh: rootMesh,
      animationGroups: result.animationGroups || [],
      type: config.type,
      scale: { ...config.scale },
      boundingInfo: rootMesh.getBoundingInfo()
    };

    console.log(`✅ Successfully loaded ${config.name}:`, {
      meshes: result.meshes.length,
      animations: result.animationGroups.length,
      animationNames: result.animationGroups.map((ag: any) => ag.name),
      rootMeshName: rootMesh.name,
      rootMeshVisible: rootMesh.isVisible,
      rootMeshPosition: rootMesh.position,
      rootMeshScaling: rootMesh.scaling,
      allMeshNames: result.meshes.map((m: any) => `${m.name}(visible:${m.isVisible})`)
    });

    return characterModel;
  }

  /**
   * Ensure the necessary loaders are imported for the format
   */
  private async ensureLoadersImported(format: 'gltf' | 'fbx'): Promise<void> {
    // Loaders already imported at module top; retain method for interface symmetry.
    return;
  }

  /**
   * Clone a character model for independent use
   */
  private cloneCharacterModel(original: CharacterModel): CharacterModel {
    const clonedMesh = original.mesh.clone(`${original.name}_clone_${Date.now()}`);
    
    return {
      name: original.name,
      mesh: clonedMesh,
      animationGroups: original.animationGroups, // Animations can be shared
      type: original.type,
      scale: { ...original.scale },
      boundingInfo: clonedMesh.getBoundingInfo()
    };
  }

  /**
   * Get character configuration by type
   */
  public getCharacterConfig(type: CharacterType): CharacterTypeConfig | undefined {
    return this.availableCharacters.find(c => c.type === type);
  }

  /**
   * Get all available character types
   */
  public getAvailableCharacterTypes(): CharacterType[] {
    return this.availableCharacters.map(c => c.type);
  }

  /**
   * Cleanup and dispose of cached models
   */
  public dispose(): void {
    this.modelCache.forEach(model => {
      model.mesh.dispose();
      model.animationGroups.forEach((ag: any) => ag.dispose());
    });
    this.modelCache.clear();
  }

  /**
   * Preload all character models for faster access
   */
  public async preloadAllModels(): Promise<void> {
    console.log('Preloading all character models...');
    
    const loadPromises = this.availableCharacters.map(async (config) => {
      try {
        await this.loadCharacterModel(config.type);
        console.log(`✅ Preloaded ${config.name}`);
      } catch (error) {
        console.error(`❌ Failed to preload ${config.name}:`, error);
      }
    });

    await Promise.all(loadPromises);
    console.log('Character model preloading complete');
  }
}