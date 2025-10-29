export const BackgroundUpdater = {
  mounted(this: any) {
    console.log('BackgroundUpdater hook mounted');

    // Listen for background updates from LiveView
    this.handleEvent("update_background", (data: any) => {
      console.log('Updating background:', data);
      this.updateBackground(data);

      // If this is a global update, dispatch a window event for all components
      if (data.global) {
        window.dispatchEvent(new CustomEvent('background-update', { detail: data }));
      }
    });

    // Listen for global background updates from other components
    window.addEventListener('background-update', (event: any) => {
      this.updateBackground(event.detail);
    });
  },

  updateBackground(data: any) {
    const backgroundType = data.background;
    const customData = data.custom_data || {};

    // Find the global background canvas
    const canvas = document.getElementById('global-background-canvas');
    if (!canvas) {
      console.warn('Global background canvas not found');
      return;
    }

    // Clean up any existing 3D scene
    this.cleanup3DScene(canvas);

    if (backgroundType === 'gradient') {
      // Apply gradient background
      const startColor = customData.gradient_start || '#3B82F6';
      const endColor = customData.gradient_end || '#9333EA';
      canvas.style.background = `linear-gradient(135deg, ${startColor}, ${endColor})`;
      canvas.removeAttribute('data-static-scene');
      canvas.setAttribute('data-bg-type', 'gradient');

  // Disable pointer events on the main background canvas for non-3D backgrounds
  // and ensure there's a hidden camera control canvas so other UI doesn't break.
  canvas.style.pointerEvents = 'none';
  this.ensureCameraControlCanvas();

    } else if (backgroundType === 'solid') {
      // Apply solid color background
      const color = customData.solid_color || '#0F172A';
      canvas.style.background = color;
      canvas.removeAttribute('data-static-scene');
      canvas.setAttribute('data-bg-type', 'solid');

  // Disable pointer events on the main background canvas for non-3D backgrounds
  canvas.style.pointerEvents = 'none';
  this.ensureCameraControlCanvas();

    } else {
      // Apply 3D scene background
      const hookName = this.getHookName(backgroundType);
      canvas.setAttribute('data-static-scene', hookName);
      canvas.style.background = ''; // Clear any CSS background
      canvas.setAttribute('data-bg-type', '3d');

  // Enable pointer events on the main background canvas so GlobalCameraController
  // and the Three.js scene can receive pointer input for camera controls.
  canvas.style.pointerEvents = 'auto';

  // Remove the auxiliary camera control canvas (not needed for 3D)
  this.removeCameraControlCanvas();

      // Initialize the 3D scene
      this.initialize3DScene(canvas, hookName);
    }

    console.log('Background updated:', { type: backgroundType, customData });
  },

  cleanup3DScene(canvas: HTMLElement) {
    // Clean up any existing Three.js scene
    // This is handled by the existing static scene system
    console.log('Cleaning up existing 3D scene');
  },

  ensureCameraControlCanvas() {
    let cameraCanvas = document.getElementById('camera-control-canvas');
    if (!cameraCanvas) {
      cameraCanvas = document.createElement('div');
      cameraCanvas.id = 'camera-control-canvas';
      cameraCanvas.setAttribute('data-static-scene', 'HomeGalaxyScene');
      cameraCanvas.className = 'fixed inset-0 z-0 pointer-events-auto opacity-0';
      document.body.appendChild(cameraCanvas);
    }
  },

  removeCameraControlCanvas() {
    const cameraCanvas = document.getElementById('camera-control-canvas');
    if (cameraCanvas) {
      cameraCanvas.remove();
    }
  },

  getHookName(backgroundType: string): string {
    switch (backgroundType) {
      case 'galaxy': return 'HomeGalaxyScene';
      case 'nebula': return 'NebulaScene';
      case 'starfield': return 'StarfieldScene';
      case 'void': return 'VoidScene';
      default: return 'HomeGalaxyScene';
    }
  },

  initialize3DScene(canvas: HTMLElement, hookName: string) {
    // This will trigger the static scene initializer in app.ts
    // The scene will be mounted automatically by the existing system
    console.log('Initializing 3D scene:', hookName);
  }
};