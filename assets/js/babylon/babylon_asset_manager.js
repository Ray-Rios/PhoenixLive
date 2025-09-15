import * as BABYLON from '@babylonjs/core';

/**
 * Asset Manager for Babylon.js
 * Handles loading, caching, and management of 3D assets
 */
export class BabylonAssetManager {
  constructor(scene) {
    this.scene = scene;
    this.loadedAssets = new Map();
    this.loadingPromises = new Map();
    this.cache = new Map();
  }

  /**
   * Load a 3D asset
   * @param {Object} asset - Asset configuration object
   * @returns {Promise} Promise that resolves when asset is loaded
   */
  async loadAsset(asset) {
    const assetKey = this.getAssetKey(asset);

    // Check if already loaded
    if (this.loadedAssets.has(assetKey)) {
      return this.loadedAssets.get(assetKey);
    }

    // Check if currently loading
    if (this.loadingPromises.has(assetKey)) {
      return this.loadingPromises.get(assetKey);
    }

    // Start loading
    const loadPromise = this.performAssetLoad(asset);
    this.loadingPromises.set(assetKey, loadPromise);

    try {
      const loadedAsset = await loadPromise;
      this.loadedAssets.set(assetKey, loadedAsset);
      this.loadingPromises.delete(assetKey);
      return loadedAsset;
    } catch (error) {
      this.loadingPromises.delete(assetKey);
      throw error;
    }
  }

  /**
   * Perform the actual asset loading
   * @param {Object} asset - Asset configuration
   * @returns {Promise} Loading promise
   */
  async performAssetLoad(asset) {
    switch (asset.type) {
      case 'model':
        return this.loadModel(asset);
      case 'texture':
        return this.loadTexture(asset);
      case 'material':
        return this.loadMaterial(asset);
      case 'animation':
        return this.loadAnimation(asset);
      default:
        throw new Error(`Unknown asset type: ${asset.type}`);
    }
  }

  /**
   * Load a 3D model
   * @param {Object} asset - Model asset configuration
   * @returns {Promise} Promise that resolves with loaded model data
   */
  async loadModel(asset) {
    return new Promise((resolve, reject) => {
      const { url, name, position, rotation, scale } = asset;

      BABYLON.SceneLoader.ImportMesh(
        '',
        this.getBaseUrl(url),
        this.getFileName(url),
        this.scene,
        (meshes, particleSystems, skeletons, animationGroups) => {
          try {
            // Process loaded meshes
            const processedMeshes = this.processMeshes(meshes, asset);

            // Apply transformations
            if (position) {
              processedMeshes.forEach(mesh => {
                mesh.position = new BABYLON.Vector3(
                  position.x || 0,
                  position.y || 0,
                  position.z || 0
                );
              });
            }

            if (rotation) {
              processedMeshes.forEach(mesh => {
                mesh.rotation = new BABYLON.Vector3(
                  rotation.x || 0,
                  rotation.y || 0,
                  rotation.z || 0
                );
              });
            }

            if (scale) {
              processedMeshes.forEach(mesh => {
                mesh.scaling = new BABYLON.Vector3(
                  scale.x || 1,
                  scale.y || 1,
                  scale.z || 1
                );
              });
            }

            const loadedAsset = {
              type: 'model',
              name: name || 'unnamed_model',
              meshes: processedMeshes,
              particleSystems,
              skeletons,
              animationGroups,
              url
            };

            resolve(loadedAsset);

          } catch (error) {
            reject(new Error(`Failed to process model: ${error.message}`));
          }
        },
        (progress) => {
          // Report loading progress
          this.reportProgress(asset, progress);
        },
        (scene, message, exception) => {
          reject(new Error(`Failed to load model ${url}: ${message}`));
        }
      );
    });
  }

  /**
   * Load a texture
   * @param {Object} asset - Texture asset configuration
   * @returns {Promise} Promise that resolves with loaded texture
   */
  async loadTexture(asset) {
    return new Promise((resolve, reject) => {
      const { url, name } = asset;

      const texture = new BABYLON.Texture(
        url,
        this.scene,
        false, // noMipmap
        true,  // invertY
        BABYLON.Texture.TRILINEAR_SAMPLINGMODE,
        () => {
          // Success callback
          resolve({
            type: 'texture',
            name: name || 'unnamed_texture',
            texture,
            url
          });
        },
        (message, exception) => {
          // Error callback
          reject(new Error(`Failed to load texture ${url}: ${message}`));
        }
      );
    });
  }

  /**
   * Load a material
   * @param {Object} asset - Material asset configuration
   * @returns {Promise} Promise that resolves with created material
   */
  async loadMaterial(asset) {
    const { name, type, properties } = asset;

    let material;

    switch (type) {
      case 'standard':
        material = new BABYLON.StandardMaterial(name, this.scene);
        break;
      case 'pbr':
        material = new BABYLON.PBRMaterial(name, this.scene);
        break;
      default:
        throw new Error(`Unknown material type: ${type}`);
    }

    // Apply material properties
    if (properties) {
      Object.keys(properties).forEach(key => {
        if (material[key] !== undefined) {
          material[key] = properties[key];
        }
      });
    }

    return {
      type: 'material',
      name,
      material
    };
  }

  /**
   * Load animations
   * @param {Object} asset - Animation asset configuration
   * @returns {Promise} Promise that resolves with animation data
   */
  async loadAnimation(asset) {
    // Implementation for loading animations
    // This would depend on your specific animation format
    return {
      type: 'animation',
      name: asset.name,
      // animation data
    };
  }

  /**
   * Process loaded meshes
   * @param {Array} meshes - Array of loaded meshes
   * @param {Object} asset - Asset configuration
   * @returns {Array} Processed meshes
   */
  processMeshes(meshes, asset) {
    return meshes.map(mesh => {
      // Set metadata for interaction handling
      mesh.metadata = {
        assetId: asset.id,
        assetName: asset.name,
        interactive: asset.interactive || false,
        ...asset.metadata
      };

      // Enable picking if interactive
      if (asset.interactive) {
        mesh.isPickable = true;
      }

      // Apply any mesh-specific configurations
      if (asset.meshConfig) {
        Object.keys(asset.meshConfig).forEach(key => {
          if (mesh[key] !== undefined) {
            mesh[key] = asset.meshConfig[key];
          }
        });
      }

      return mesh;
    });
  }

  /**
   * Report loading progress
   * @param {Object} asset - Asset being loaded
   * @param {Object} progress - Progress information
   */
  reportProgress(asset, progress) {
    const progressEvent = new CustomEvent('babylon-asset-progress', {
      detail: {
        asset: asset.name || asset.url,
        loaded: progress.loaded || 0,
        total: progress.total || 0,
        lengthComputable: progress.lengthComputable || false
      }
    });

    document.dispatchEvent(progressEvent);
  }

  /**
   * Get asset cache key
   * @param {Object} asset - Asset configuration
   * @returns {string} Cache key
   */
  getAssetKey(asset) {
    return `${asset.type}_${asset.url || asset.name}`;
  }

  /**
   * Get base URL from full URL
   * @param {string} url - Full URL
   * @returns {string} Base URL
   */
  getBaseUrl(url) {
    const lastSlash = url.lastIndexOf('/');
    return lastSlash !== -1 ? url.substring(0, lastSlash + 1) : '';
  }

  /**
   * Get filename from full URL
   * @param {string} url - Full URL
   * @returns {string} Filename
   */
  getFileName(url) {
    const lastSlash = url.lastIndexOf('/');
    return lastSlash !== -1 ? url.substring(lastSlash + 1) : url;
  }

  /**
   * Remove an asset from the scene
   * @param {string} assetKey - Asset key to remove
   */
  removeAsset(assetKey) {
    const asset = this.loadedAssets.get(assetKey);
    if (asset) {
      // Dispose of Babylon.js resources
      if (asset.meshes) {
        asset.meshes.forEach(mesh => mesh.dispose());
      }
      if (asset.texture) {
        asset.texture.dispose();
      }
      if (asset.material) {
        asset.material.dispose();
      }

      this.loadedAssets.delete(assetKey);
    }
  }

  /**
   * Get loaded asset
   * @param {string} assetKey - Asset key
   * @returns {Object|null} Loaded asset or null
   */
  getAsset(assetKey) {
    return this.loadedAssets.get(assetKey) || null;
  }

  /**
   * Check if asset is loaded
   * @param {string} assetKey - Asset key
   * @returns {boolean} True if loaded
   */
  isAssetLoaded(assetKey) {
    return this.loadedAssets.has(assetKey);
  }

  /**
   * Get all loaded assets
   * @returns {Map} Map of loaded assets
   */
  getAllAssets() {
    return new Map(this.loadedAssets);
  }

  /**
   * Clear all assets
   */
  clearAssets() {
    this.loadedAssets.forEach((asset, key) => {
      this.removeAsset(key);
    });
    this.loadedAssets.clear();
    this.loadingPromises.clear();
  }

  /**
   * Cleanup resources
   */
  cleanup() {
    this.clearAssets();
    this.cache.clear();
  }
}