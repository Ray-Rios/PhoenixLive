// Three.js Phoenix LiveView Hooks
import ThreeSceneManager from './core/scene-manager';
import { CharacterModelManager } from './characters/model-manager';
import { HomeGalaxyScene } from './galaxy-scene';
import { NebulaScene } from './scenes/nebula-scene';
import { StarfieldScene } from './scenes/starfield-scene';
import { VoidScene } from './scenes/void-scene';

// Main Three.js Scene Hook
export const ThreeJSScene = {
  el: null as any,
  threeSceneManager: null as any,
  characterManager: null as any,
  pushEvent: null as any,
  
  mounted(this: any) {
    // Defensive check for element existence
    if (!this.el) {
      console.error('❌ ThreeJS Scene hook mounted but element is null');
      return;
    }
    
    console.log('🚀 ThreeJS Scene hook mounted', this.el.id);
    this.el._threeJSHook = this;
    
    try {
      this.threeSceneManager = new ThreeSceneManager(this.el);
      this.characterManager = new CharacterModelManager();
      
      this.threeSceneManager.mounted();
      this.handleServerUpdates();
    } catch (error) {
      console.error('❌ Failed to initialize ThreeJS Scene:', error);
    }
  },

  updated(this: any) {
    console.log('🔄 ThreeJS Scene hook updated');
    if (this.threeSceneManager) {
      this.threeSceneManager.updated();
    }
    this.handleServerUpdates();
  },

  destroyed(this: any) {
    console.log('🗑️ ThreeJS Scene hook destroyed');
    if (this.threeSceneManager) {
      this.threeSceneManager.destroyed();
    }
    if (this.characterManager) {
      this.characterManager.dispose();
    }
    this.cleanup();
  },

  // Handle updates from Phoenix LiveView
  handleServerUpdates(this: any) {
    try {
      const userData = this.getUserData();
      const chatData = this.getChatData();
      const worldData = this.getWorldData();

      if (userData) this.handleUserUpdate(userData);
      if (chatData) this.handleChatUpdate(chatData);
      if (worldData) this.handleWorldUpdate(worldData);
    } catch (error) {
      console.error('Error handling server updates:', error);
    }
  },

  // User management
  async handleUserUpdate(this: any, userData: any) {
    if (!this.characterManager || !userData) return;
    
    try {
      // Update player character
      if (userData.currentUser) {
        await this.characterManager.createOrUpdateCharacter(
          userData.currentUser.id.toString(),
          userData.currentUser,
          true // isPlayer
        );
      }
      
      // Update other players
      if (userData.otherPlayers) {
        for (const player of userData.otherPlayers) {
          await this.characterManager.createOrUpdateCharacter(
            player.id.toString(),
            player,
            false // isPlayer
          );
        }
      }
    } catch (error) {
      console.error('Error updating user data:', error);
    }
  },

  // Chat system
  handleChatUpdate(this: any, chatData: any) {
    // Handle chat updates for the 3D world
    if (chatData.newMessages) {
      chatData.newMessages.forEach((message: any) => {
        console.log('New chat message in 3D world:', message);
        // Could add 3D floating text or user indicators here
      });
    }
  },

  // World updates (creatures, environment, etc.)
  async handleWorldUpdate(this: any, worldData: any) {
    if (!this.characterManager || !worldData) return;
    
    try {
      // Update creatures/NPCs
      if (worldData.creatures) {
        for (const creature of worldData.creatures) {
          await this.characterManager.createOrUpdateCreature(
            creature.id.toString(),
            creature
          );
        }
      }
    } catch (error) {
      console.error('Error updating world data:', error);
    }
  },

  // Data extraction from Phoenix LiveView
  getUserData(this: any) {
    try {
      const userDataElement = this.el.querySelector('[data-user-data]');
      if (userDataElement && userDataElement.dataset.userData) {
        return JSON.parse(userDataElement.dataset.userData);
      }
    } catch (error) {
      console.error('Error parsing user data:', error);
    }
    return null;
  },

  getChatData(this: any) {
    try {
      const chatDataElement = this.el.querySelector('[data-chat-data]');
      if (chatDataElement && chatDataElement.dataset.chatData) {
        return JSON.parse(chatDataElement.dataset.chatData);
      }
    } catch (error) {
      console.error('Error parsing chat data:', error);
    }
    return null;
  },

  getWorldData(this: any) {
    try {
      const worldDataElement = this.el.querySelector('[data-world-data]');
      if (worldDataElement && worldDataElement.dataset.worldData) {
        return JSON.parse(worldDataElement.dataset.worldData);
      }
    } catch (error) {
      console.error('Error parsing world data:', error);
    }
    return null;
  },

  // Event handlers for UI interactions
  handleCanvasClick(this: any, event: MouseEvent) {
    if (this.threeSceneManager) {
      // Convert screen coordinates to world coordinates and handle interaction
      console.log('Canvas clicked', event);
    }
  },

  // Cleanup
  cleanup(this: any) {
    if (this.threeSceneManager) {
      this.threeSceneManager.cleanup?.();
    }
    if (this.characterManager) {
      this.characterManager.dispose();
    }
  }
};

// Simple Test Scene Hook - For testing Three.js functionality
export const ThreeJSTestScene = {
  el: null as any,
  
  mounted(this: any) {
    // Defensive check for element existence
    if (!this.el) {
      console.error('❌ ThreeJS Test Scene hook mounted but element is null');
      return;
    }
    
    console.log('🧪 ThreeJS Test Scene mounted', this.el.id);
    
    try {
      this.createTestScene();
    } catch (error) {
      console.error('❌ Failed to initialize ThreeJS Test Scene:', error);
    }
  },

  updated(this: any) {
    console.log('🔄 ThreeJS Test Scene updated');
  },

  destroyed(this: any) {
    console.log('🗑️ ThreeJS Test Scene destroyed');
    this.cleanup();
  },

  createTestScene(this: any) {
    const canvas = this.el.querySelector('canvas');
    if (!canvas) {
      console.error('Canvas not found for test scene');
      return;
    }

    // Simple Three.js test scene
    const THREE = (window as any).THREE;
    if (!THREE) {
      console.error('THREE.js not loaded');
      return;
    }

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87CEEB);

    const camera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height, 0.1, 1000);
    camera.position.z = 5;

    const renderer = new THREE.WebGLRenderer({ canvas });
    renderer.setSize(canvas.width, canvas.height);

    // Create test objects
    const geometry = new THREE.BoxGeometry();
    const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
    const cube = new THREE.Mesh(geometry, material);
    scene.add(cube);

    // Animation loop
    const animate = () => {
      requestAnimationFrame(animate);
      cube.rotation.x += 0.01;
      cube.rotation.y += 0.01;
      renderer.render(scene, camera);
    };

    animate();
  },

  cleanup(this: any) {
    // Cleanup test scene
  }
};

// Export all hooks for use in Phoenix LiveView
export default {
  ThreeJSScene,
  ThreeJSTestScene,
  HomeGalaxyScene,
  NebulaScene,
  StarfieldScene,
  VoidScene
};