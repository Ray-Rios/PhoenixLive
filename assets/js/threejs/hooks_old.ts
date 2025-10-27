// Three.js Phoenix LiveView Hooks - Replaces ALL Babylon.js hooks
import * as THREE from 'three';
import ThreeSceneManager from './core/scene-manager';
import CharacterModelManager from './characters/model-manager';

// Main Three.js Scene Hook
  private container: HTMLElement;
  private renderer: THREE.WebGLRenderer | null = null;
  private scene: THREE.Scene | null = null;
  private camera: THREE.PerspectiveCamera | null = null;
  private nebulaClouds: THREE.Points[] = [];
  private starClusters: THREE.Points[] = [];
  private animationId: number | null = null;
  private clock: THREE.Clock | null = null;
  private time: number = 0;

  constructor(container: HTMLElement) {
    this.container = container;
  }

  initialize(): void {
    const width = this.container.clientWidth || window.innerWidth;
    const height = this.container.clientHeight || window.innerHeight;

    // Scene with deep space black
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x000008);
    this.scene.fog = new THREE.FogExp2(0x000008, 0.0008);

    // Wide-angle camera for immersive feel
    this.camera = new THREE.PerspectiveCamera(75, width / height, 1, 3000);
    this.camera.position.set(0, 100, 500);
    this.camera.lookAt(0, 0, 0);

    // Renderer setup
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(width, height, false);
    this.renderer.outputEncoding = THREE.sRGBEncoding;
    
    // Ensure canvas doesn't block UI
    this.renderer.domElement.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: block;
      pointer-events: none;
    `;

    this.container.innerHTML = '';
    this.container.appendChild(this.renderer.domElement);

    this.clock = new THREE.Clock();

    this.createCosmicScene();
    this.start();
    this.setupResize();
  }

  private createCosmicScene(): void {
    if (!this.scene) return;

    // Create distant star field
    this.createDistantStars();
    
    // Create colorful nebula clouds with particle effects
    this.createNebulaClouds();
    
    // Create bright star clusters
    this.createStarClusters();
    
    // Add subtle ambient light
    const ambientLight = new THREE.AmbientLight(0x111133, 0.3);
    this.scene.add(ambientLight);
  }

  private createDistantStars(): void {
    if (!this.scene) return;

    const geometry = new THREE.BufferGeometry();
    const count = 5000;
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const sizes = new Float32Array(count);

    for (let i = 0; i < count; i++) {
      const i3 = i * 3;
      
      // Spherical distribution
      const radius = 1500 + Math.random() * 500;
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos((Math.random() * 2) - 1);
      
      positions[i3] = radius * Math.sin(phi) * Math.cos(theta);
      positions[i3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
      positions[i3 + 2] = radius * Math.cos(phi);

      // Subtle color variation - whites and pale blues
      const colorChoice = Math.random();
      if (colorChoice > 0.7) {
        colors[i3] = 0.8 + Math.random() * 0.2;
        colors[i3 + 1] = 0.9 + Math.random() * 0.1;
        colors[i3 + 2] = 1.0;
      } else {
        colors[i3] = 0.9 + Math.random() * 0.1;
        colors[i3 + 1] = 0.9 + Math.random() * 0.1;
        colors[i3 + 2] = 0.85 + Math.random() * 0.15;
      }

      sizes[i] = Math.random() * 2 + 0.5;
    }

    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

    const material = new THREE.PointsMaterial({
      size: 1.5,
      sizeAttenuation: true,
      vertexColors: true,
      transparent: true,
      opacity: 0.6,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });

    const stars = new THREE.Points(geometry, material);
    this.scene.add(stars);
  }

  private createNebulaClouds(): void {
    if (!this.scene) return;

    const cloudConfigs = [
      { count: 800, size: 40, color: new THREE.Color(0.4, 0.1, 0.6), radius: 600, speed: 0.02 },
      { count: 1000, size: 35, color: new THREE.Color(0.1, 0.3, 0.7), radius: 700, speed: -0.015 },
      { count: 600, size: 50, color: new THREE.Color(0.7, 0.2, 0.3), radius: 500, speed: 0.025 }
    ];

    cloudConfigs.forEach(config => {
      const geometry = new THREE.BufferGeometry();
      const positions = new Float32Array(config.count * 3);
      const colors = new Float32Array(config.count * 3);

      for (let i = 0; i < config.count; i++) {
        const i3 = i * 3;
        
        // Spiral galaxy distribution
        const angle = Math.random() * Math.PI * 2;
        const radius = Math.pow(Math.random(), 0.5) * config.radius;
        const heightVariation = (Math.random() - 0.5) * 100;
        
        positions[i3] = Math.cos(angle) * radius;
        positions[i3 + 1] = heightVariation;
        positions[i3 + 2] = Math.sin(angle) * radius;

        // Color with slight variation
        const colorVariation = 0.3;
        colors[i3] = config.color.r + (Math.random() - 0.5) * colorVariation;
        colors[i3 + 1] = config.color.g + (Math.random() - 0.5) * colorVariation;
        colors[i3 + 2] = config.color.b + (Math.random() - 0.5) * colorVariation;
      }

      geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

      const material = new THREE.PointsMaterial({
        size: config.size,
        sizeAttenuation: true,
        vertexColors: true,
        transparent: true,
        opacity: 0.4,
        blending: THREE.AdditiveBlending,
        depthWrite: false
      });

      const cloud = new THREE.Points(geometry, material);
      cloud.userData = { rotationSpeed: config.speed };
      this.scene.add(cloud);
      this.nebulaClouds.push(cloud);
    });
  }

  private createStarClusters(): void {
    if (!this.scene) return;

    const geometry = new THREE.BufferGeometry();
    const count = 300;
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const sizes = new Float32Array(count);

    for (let i = 0; i < count; i++) {
      const i3 = i * 3;
      
      // Clustered distribution
      const clusterRadius = 400;
      const spread = 200;
      const angle = Math.random() * Math.PI * 2;
      const dist = Math.random() * spread;
      
      positions[i3] = Math.cos(angle) * (clusterRadius + dist);
      positions[i3 + 1] = (Math.random() - 0.5) * 150;
      positions[i3 + 2] = Math.sin(angle) * (clusterRadius + dist);

      // Bright white with hints of yellow
      colors[i3] = 1.0;
      colors[i3 + 1] = 0.95 + Math.random() * 0.05;
      colors[i3 + 2] = 0.8 + Math.random() * 0.2;

      sizes[i] = Math.random() * 8 + 4;
    }

    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

    const material = new THREE.PointsMaterial({
      size: 6,
      sizeAttenuation: true,
      vertexColors: true,
      transparent: true,
      opacity: 0.9,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });

    const cluster = new THREE.Points(geometry, material);
    this.scene.add(cluster);
    this.starClusters.push(cluster);
  }

  private setupResize(): void {
    const handleResize = () => {
      if (!this.renderer || !this.camera) return;
      
      const width = this.container.clientWidth || window.innerWidth;
      const height = this.container.clientHeight || window.innerHeight;
      
      this.camera.aspect = width / height;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(width, height, false);
    };

    window.addEventListener('resize', handleResize);
    handleResize();
  }

  private start(): void {
    const animate = () => {
      if (!this.renderer || !this.scene || !this.camera || !this.clock) return;

      this.animationId = requestAnimationFrame(animate);

      const elapsed = this.clock.getElapsedTime();
      this.time += 0.001;

      // Rotate nebula clouds at different speeds
      this.nebulaClouds.forEach((cloud, index) => {
        cloud.rotation.y += cloud.userData.rotationSpeed;
        
        // Subtle vertical floating
        cloud.position.y = Math.sin(elapsed * 0.3 + index) * 20;
        
        // Pulse opacity for twinkling effect
        const material = cloud.material as THREE.PointsMaterial;
        material.opacity = 0.3 + Math.sin(elapsed * 0.8 + index) * 0.1;
      });

      // Make star clusters twinkle
      this.starClusters.forEach((cluster, index) => {
        const material = cluster.material as THREE.PointsMaterial;
        material.opacity = 0.7 + Math.sin(elapsed * 1.2 + index * 2) * 0.2;
        
        // Gentle rotation
        cluster.rotation.y += 0.001;
      });

      // Slow camera orbit for dynamic perspective
      const cameraRadius = 500;
      this.camera.position.x = Math.sin(elapsed * 0.03) * (cameraRadius * 0.15);
      this.camera.position.y = 100 + Math.sin(elapsed * 0.02) * 30;
      this.camera.position.z = cameraRadius + Math.cos(elapsed * 0.025) * 50;
      this.camera.lookAt(0, 0, 0);

      this.renderer.render(this.scene, this.camera);
      this.animationId = requestAnimationFrame(animate);
    };

    animate();
  }

  dispose(): void {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }

    // Cleanup nebula clouds
    this.nebulaClouds.forEach(cloud => {
      cloud.geometry.dispose();
      (cloud.material as THREE.Material).dispose();
    });
    this.nebulaClouds = [];

    // Cleanup star clusters
    this.starClusters.forEach(cluster => {
      cluster.geometry.dispose();
      (cluster.material as THREE.Material).dispose();
    });
    this.starClusters = [];

    if (this.renderer) {
      this.renderer.dispose();
      this.renderer.domElement.remove();
      this.renderer = null;
    }

    this.scene = null;
    this.camera = null;
    this.clock = null;
  }

  private handleWindowResize = () => {
    if (!this.renderer || !this.camera) return;
    const width = this.container.clientWidth || window.innerWidth;
    const height = this.container.clientHeight || window.innerHeight;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  };
}

// Main Three.js Scene Hook - Replaces OpenWorldLobbySceneHook
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
      
      // Initialize the scene
      this.threeSceneManager.mounted();
    } catch (error) {
      console.error('❌ Failed to initialize ThreeJS Scene:', error);
      this.handleError('initialization_failed', error);
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
    if (!this.characterManager) return;

    switch (userData.action) {
      case 'player_joined':
        await this.characterManager.createPlayerCharacter(
          userData.player_id,
          userData.player_name,
          userData.character_type || 'human_male',
          userData.position || { x: 0, y: 0, z: 0 },
          userData.is_local_player || false
        );
        break;

      case 'player_left':
        this.characterManager.removeCharacter(userData.player_id);
        break;

      case 'player_moved':
        this.characterManager.updateCharacterPosition(
          userData.player_id,
          userData.position,
          userData.rotation
        );
        if (userData.animation) {
          this.characterManager.playCharacterAnimation(
            userData.player_id,
            userData.animation
          );
        }
        break;
    }
  },

  // Chat system
  handleChatUpdate(this: any, chatData: any) {
    const chatContainer = document.getElementById('chat-messages');
    if (!chatContainer) return;

    const messageEl = document.createElement('div');
    messageEl.className = `chat-message ${chatData.channel || 'say'}`;
    messageEl.innerHTML = `
      <span class="timestamp">[${new Date().toLocaleTimeString()}]</span>
      <span class="player-name">${chatData.player_name}:</span>
      <span class="message">${chatData.message}</span>
    `;
    
    chatContainer.appendChild(messageEl);
    chatContainer.scrollTop = chatContainer.scrollHeight;

    // Limit chat history
    while (chatContainer.children.length > 100) {
      chatContainer.removeChild(chatContainer.firstChild!);
    }
  },

  // World updates (creatures, environment, etc.)
  async handleWorldUpdate(this: any, worldData: any) {
    if (!this.characterManager) return;

    switch (worldData.action) {
      case 'creature_spawned':
        await this.characterManager.createCreature(
          worldData.creature_id,
          worldData.creature_type,
          worldData.creature_name || worldData.creature_type,
          worldData.position || { x: 0, y: 0, z: 0 }
        );
        break;

      case 'creature_moved':
        this.characterManager.updateCharacterPosition(
          worldData.creature_id,
          worldData.position,
          worldData.rotation
        );
        break;

      case 'creature_died':
        this.characterManager.removeCreature(worldData.creature_id);
        break;
    }
  },

  // Data extraction from Phoenix LiveView
  getUserData(this: any) {
    try {
      const userData = this.el.dataset.user;
      return userData ? JSON.parse(userData) : null;
    } catch {
      return null;
    }
  },

  getChatData(this: any) {
    try {
      const chatData = this.el.dataset.chat;
      return chatData ? JSON.parse(chatData) : null;
    } catch {
      return null;
    }
  },

  getWorldData(this: any) {
    try {
      const worldData = this.el.dataset.world;
      return worldData ? JSON.parse(worldData) : null;
    } catch {
      return null;
    }
  },

  // Event handlers for UI interactions
  handleCanvasClick(this: any, event: MouseEvent) {
    if (!this.threeSceneManager) return;

    // Raycasting for object selection
    const rect = this.el.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    const y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    // This would normally use THREE.Raycaster for object picking
    console.log('Canvas clicked at:', { x, y });

    // Push event to Phoenix LiveView
    if (this.pushEvent) {
      this.pushEvent('canvas_click', { x, y, timestamp: Date.now() });
    }
  },

  // Cleanup
  cleanup(this: any) {
    // Remove any event listeners
    if (this.el && this.handleCanvasClick) {
      this.el.removeEventListener('click', this.handleCanvasClick);
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
    console.log('✅ Test scene created successfully');
  },

  cleanup(this: any) {
    // Cleanup test scene
  }
};

// Export all hooks for use in Phoenix LiveView
export default {
  ThreeJSScene,
  ThreeJSTestScene
};