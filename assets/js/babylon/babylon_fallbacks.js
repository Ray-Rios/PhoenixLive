/**
 * Fallback Manager for Babylon.js
 * Handles WebGL detection and fallback rendering for unsupported browsers
 */
export class BabylonFallbackManager {
  /**
   * Check if WebGL is supported in the current browser
   * @returns {boolean} True if WebGL is supported
   */
  static checkWebGLSupport() {
    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
      
      if (!gl) {
        return false;
      }

      // Check for required extensions
      const requiredExtensions = [
        'OES_texture_float',
        'OES_element_index_uint'
      ];

      for (const extension of requiredExtensions) {
        if (!gl.getExtension(extension)) {
          console.warn(`WebGL extension ${extension} not supported`);
        }
      }

      return true;
    } catch (e) {
      console.error('WebGL support check failed:', e);
      return false;
    }
  }

  /**
   * Check WebGL capabilities and performance
   * @returns {Object} Capability information
   */
  static checkWebGLCapabilities() {
    if (!this.checkWebGLSupport()) {
      return { supported: false };
    }

    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

      const capabilities = {
        supported: true,
        version: gl.getParameter(gl.VERSION),
        vendor: gl.getParameter(gl.VENDOR),
        renderer: gl.getParameter(gl.RENDERER),
        maxTextureSize: gl.getParameter(gl.MAX_TEXTURE_SIZE),
        maxVertexAttribs: gl.getParameter(gl.MAX_VERTEX_ATTRIBS),
        maxVaryingVectors: gl.getParameter(gl.MAX_VARYING_VECTORS),
        maxFragmentUniforms: gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_VECTORS),
        maxVertexUniforms: gl.getParameter(gl.MAX_VERTEX_UNIFORM_VECTORS),
        extensions: gl.getSupportedExtensions()
      };

      // Determine performance tier
      capabilities.performanceTier = this.determinePerformanceTier(capabilities);

      return capabilities;
    } catch (e) {
      console.error('WebGL capability check failed:', e);
      return { supported: false, error: e.message };
    }
  }

  /**
   * Determine performance tier based on WebGL capabilities
   * @param {Object} capabilities - WebGL capabilities
   * @returns {string} Performance tier: 'high', 'medium', 'low'
   */
  static determinePerformanceTier(capabilities) {
    const renderer = capabilities.renderer.toLowerCase();
    const maxTextureSize = capabilities.maxTextureSize;

    // High-end GPUs
    if (renderer.includes('nvidia') && (renderer.includes('rtx') || renderer.includes('gtx'))) {
      return 'high';
    }
    if (renderer.includes('amd') && renderer.includes('radeon')) {
      return 'high';
    }

    // Medium performance indicators
    if (maxTextureSize >= 4096) {
      return 'medium';
    }

    // Low performance fallback
    return 'low';
  }

  /**
   * Render fallback content for unsupported browsers
   * @param {HTMLElement} container - Container element
   * @param {Object} fallbackContent - Fallback content configuration
   */
  static renderFallback(container, fallbackContent) {
    const fallbackHTML = `
      <div class="babylon-fallback">
        <div class="fallback-content">
          <div class="fallback-icon">
            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 2L2 7l10 5 10-5-10-5z"/>
              <path d="M2 17l10 5 10-5"/>
              <path d="M2 12l10 5 10-5"/>
            </svg>
          </div>
          
          ${fallbackContent.image ? `
            <div class="fallback-image">
              <img src="${fallbackContent.image}" alt="${fallbackContent.alt || '3D Content Preview'}" />
            </div>
          ` : ''}
          
          <div class="fallback-message">
            <h3>3D Content Not Available</h3>
            <p>${fallbackContent.message || 'Your browser does not support 3D content.'}</p>
          </div>
          
          ${fallbackContent.link ? `
            <div class="fallback-actions">
              <a href="${fallbackContent.link}" class="fallback-link" target="_blank">
                View in Supported Browser
              </a>
            </div>
          ` : ''}
          
          <div class="fallback-info">
            <details>
              <summary>Technical Information</summary>
              <div class="tech-info">
                <p><strong>Issue:</strong> WebGL not supported or disabled</p>
                <p><strong>Solution:</strong> Please use a modern browser with WebGL enabled</p>
                <p><strong>Supported Browsers:</strong> Chrome 9+, Firefox 4+, Safari 5.1+, Edge 12+</p>
              </div>
            </details>
          </div>
        </div>
      </div>
    `;

    container.innerHTML = fallbackHTML;
    container.classList.add('babylon-fallback-container');
  }

  /**
   * Render performance warning for low-end devices
   * @param {HTMLElement} container - Container element
   * @param {Object} options - Warning options
   */
  static renderPerformanceWarning(container, options = {}) {
    const warningHTML = `
      <div class="babylon-performance-warning">
        <div class="warning-content">
          <div class="warning-icon">⚠️</div>
          <div class="warning-message">
            <h4>Performance Notice</h4>
            <p>Your device may experience reduced performance with 3D content.</p>
            <p>Consider switching to low-quality mode for better performance.</p>
          </div>
          <div class="warning-actions">
            <button class="btn-continue" onclick="this.parentElement.parentElement.parentElement.remove()">
              Continue Anyway
            </button>
            <button class="btn-low-quality" onclick="window.babylonLowQualityMode = true; this.parentElement.parentElement.parentElement.remove()">
              Use Low Quality Mode
            </button>
          </div>
        </div>
      </div>
    `;

    const warningElement = document.createElement('div');
    warningElement.innerHTML = warningHTML;
    container.appendChild(warningElement);
  }

  /**
   * Create a simple 2D canvas fallback for basic visualizations
   * @param {HTMLElement} container - Container element
   * @param {Object} data - Data to visualize
   */
  static render2DFallback(container, data) {
    const canvas = document.createElement('canvas');
    canvas.width = container.clientWidth || 400;
    canvas.height = container.clientHeight || 300;
    canvas.style.width = '100%';
    canvas.style.height = '100%';

    const ctx = canvas.getContext('2d');

    // Simple 2D representation
    ctx.fillStyle = '#f0f0f0';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.fillStyle = '#333';
    ctx.font = '16px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('2D Preview Mode', canvas.width / 2, canvas.height / 2 - 20);

    ctx.font = '12px Arial';
    ctx.fillStyle = '#666';
    ctx.fillText('3D content not available', canvas.width / 2, canvas.height / 2 + 10);

    container.innerHTML = '';
    container.appendChild(canvas);
  }

  /**
   * Check if device is mobile
   * @returns {boolean} True if mobile device
   */
  static isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  /**
   * Check if device has limited memory
   * @returns {boolean} True if limited memory device
   */
  static isLimitedMemoryDevice() {
    // Check for device memory API
    if ('deviceMemory' in navigator) {
      return navigator.deviceMemory < 4; // Less than 4GB RAM
    }

    // Fallback: assume mobile devices have limited memory
    return this.isMobileDevice();
  }

  /**
   * Get recommended quality settings based on device capabilities
   * @param {Object} capabilities - WebGL capabilities
   * @returns {Object} Recommended settings
   */
  static getRecommendedSettings(capabilities) {
    if (!capabilities.supported) {
      return {
        quality: 'fallback',
        enableShadows: false,
        enablePostProcessing: false,
        maxLights: 1,
        textureQuality: 'low'
      };
    }

    const isMobile = this.isMobileDevice();
    const isLimitedMemory = this.isLimitedMemoryDevice();
    const performanceTier = capabilities.performanceTier;

    if (performanceTier === 'high' && !isMobile) {
      return {
        quality: 'high',
        enableShadows: true,
        enablePostProcessing: true,
        maxLights: 8,
        textureQuality: 'high',
        antialias: true
      };
    } else if (performanceTier === 'medium' || (performanceTier === 'high' && isMobile)) {
      return {
        quality: 'medium',
        enableShadows: true,
        enablePostProcessing: false,
        maxLights: 4,
        textureQuality: 'medium',
        antialias: false
      };
    } else {
      return {
        quality: 'low',
        enableShadows: false,
        enablePostProcessing: false,
        maxLights: 2,
        textureQuality: 'low',
        antialias: false
      };
    }
  }

  /**
   * Initialize fallback detection and setup
   * @param {HTMLElement} container - Container element
   * @param {Object} options - Configuration options
   * @returns {Object} Detection results and recommendations
   */
  static initialize(container, options = {}) {
    const capabilities = this.checkWebGLCapabilities();
    const settings = this.getRecommendedSettings(capabilities);
    
    // Show performance warning for low-end devices
    if (settings.quality === 'low' && options.showPerformanceWarning !== false) {
      this.renderPerformanceWarning(container, options);
    }

    return {
      capabilities,
      recommendedSettings: settings,
      shouldShowWarning: settings.quality === 'low'
    };
  }
}