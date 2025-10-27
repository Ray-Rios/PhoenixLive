// Global Camera Controller Hook for Phoenix LiveView
// Provides camera controls on any page, even without 3D scenes

import * as THREE from 'three';
import { CameraController } from './camera-controller';

export const GlobalCameraController = {
  camera: null as THREE.PerspectiveCamera | null,
  controller: null as CameraController | null,
  activeScene: null as any,
  isLoggedIn: false,
  animationId: null as number | null,
  controlElement: null as HTMLElement | null,

  mounted(this: any) {
    console.log('🎥 Global Camera Controller mounted');

    // Check if user is logged in by looking for user data
    const bodyElement = document.getElementById('global-glass-theme');
    this.isLoggedIn = bodyElement?.dataset?.user !== undefined;

    // Prepare a camera now; we'll bind the controller to the proper element (scene canvas or control layer)
    this.camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 2000);
    this.camera.position.set(0, 0, 0);

    // Attempt to attach to an existing control layer (for gradient/solid backgrounds)
    const controlLayer = document.getElementById('camera-control-canvas');
    if (controlLayer) {
      this.controlElement = controlLayer as HTMLElement;
      this.controller = new CameraController(this.camera, this.controlElement);

      // Enable auto-rotate for logged-out users on home page
      const isHomePage = window.location.pathname === '/' || window.location.pathname === '/home';
      if (!this.isLoggedIn && isHomePage) {
        console.log('🔄 Auto-rotate enabled for home page (no 3D scene)');
        this.controller.setAutoRotate(true, 0.001);
      }
    }

    // Start animation loop for camera updates (runs even if controller not yet attached)
    this.startAnimationLoop();

    // Listen for scene initialization to take control of their cameras
    window.addEventListener('scene-initialized', (event: any) => {
      if (event.detail && event.detail.scene && event.detail.camera) {
        console.log('🎬 Taking control of scene camera');
        this.activeScene = event.detail.scene;

        const sceneCanvas: HTMLElement | null = event.detail.canvas || null;

        // If we already had a controller, dispose it to rebind listeners to the scene canvas only
        if (this.controller) {
          try { this.controller.dispose(); } catch (e) { console.warn('Dispose previous controller failed', e); }
          this.controller = null;
        }

        // Create a fresh controller bound to the scene's canvas to avoid intercepting UI events globally
        this.camera = event.detail.camera;
        this.controlElement = sceneCanvas;
        this.controller = new CameraController(this.camera, this.controlElement || undefined);

        // Re-enable auto-rotate if applicable
        const isHomePage = window.location.pathname === '/' || window.location.pathname === '/home';
        if (!this.isLoggedIn && isHomePage && this.controller) {
          this.controller.setAutoRotate(true, 0.001);
        }
      }
    });

    // Listen for camera state requests from other components
    window.addEventListener('request-camera-state', (event: any) => {
      if (event.detail && typeof event.detail.callback === 'function') {
        event.detail.callback({
          position: this.camera.position.clone(),
          rotation: {
            x: this.controller ? this.controller.getRotationX() : 0,
            y: this.controller ? this.controller.getRotationY() : 0
          }
        });
      }
    });

    console.log('✅ Global camera controller initialized');
  },

  startAnimationLoop(this: any) {
    const animate = () => {
      this.animationId = requestAnimationFrame(animate);
      
      if (this.controller) {
        this.controller.update();
      }
    };
    animate();
  },

  destroyed(this: any) {
    console.log('🗑️ Global Camera Controller destroyed');
    
    if (this.animationId !== null) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    
    if (this.controller && typeof this.controller.dispose === 'function') {
      this.controller.dispose();
    }
  }
};