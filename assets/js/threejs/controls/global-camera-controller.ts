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

    // Always create global camera controls for the entire site
    this.controller = new CameraController(this.camera); // No element = document.body with smart event handling
    
    // Enable auto-rotation for a nice idle effect (rotates after 3 seconds of no interaction)
    this.controller.setAutoRotate(true, 0.0005);
    
    console.log('🎮 Global camera controls enabled for entire site with auto-rotation');

    // If there's also a specific control layer (for gradient/solid backgrounds), we can use that too
    const controlLayer = document.getElementById('camera-control-canvas');
    if (controlLayer) {
      // For now, keep the global controls as primary
      console.log('� Found additional control layer, but using global controls');
    }

    // Start animation loop for camera updates (runs even if controller not yet attached)
    this.startAnimationLoop();

    // Listen for scene initialization to take control of their cameras
    window.addEventListener('scene-initialized', (event: any) => {
      if (event.detail && event.detail.scene && event.detail.camera) {
        console.log('🎬 Scene initialized, updating camera reference');
        this.activeScene = event.detail.scene;
        this.camera = event.detail.camera;

        const sceneCanvas: HTMLElement | null = event.detail.canvas || null;

        // If we don't have a controller yet, create one
        // Otherwise, just update the camera reference - keep the same controller!
        if (!this.controller) {
          this.controlElement = sceneCanvas;
          this.controller = new CameraController(this.camera, this.controlElement || undefined);
          this.controller.setAutoRotate(true, 0.0005);
          console.log('🎮 Camera controller created for 3D scene with auto-rotation');
        } else {
          // Just update the camera reference, don't recreate the controller
          this.controller.camera = this.camera;
          console.log('🔄 Camera reference updated for new scene');
        }

        // Enable camera controls for all users on all pages with 3D scenes
        console.log('✅ Camera controls active for 3D scene');
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

  createGlobalControlLayer(this: any) {
    // Create a full-screen overlay for camera controls when no 3D scene exists
    const controlLayer = document.createElement('div');
    controlLayer.id = 'global-camera-control-layer';
    controlLayer.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      z-index: 0;
      pointer-events: auto;
      cursor: grab;
    `;
    controlLayer.style.cursor = 'grab';
    
    document.body.appendChild(controlLayer);
    this.controlElement = controlLayer;
    this.controller = new CameraController(this.camera, this.controlElement);
    
    console.log('🎮 Global camera control layer created for entire page');
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