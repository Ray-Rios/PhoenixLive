// hCaptcha integration for Phoenix LiveView - Enhanced persistence with visual state

import { LiveViewHook, LiveViewElement } from './types/liveview';
import { HCaptchaAPI, FormHandlerHook } from './types/hcaptcha';

let hCaptchaApiLoaded = false;
let hCaptchaLoadPromise: Promise<void> | null = null;

interface HCaptchaData {
  sitekey: string;
  preserveWidget: boolean;
  isCompleted: boolean;
  completedToken: string | null;
  widgetId?: string;
}

interface HCaptchaHook extends LiveViewHook, HCaptchaData {
  loadHCaptcha(): void;
  renderCaptcha(): void;
  createCompletedIndicator(): void;
  removeCompletedIndicator(): void;
  notifyFormHandler(eventName: string, data: any): void;
  preserveFormBeforeUpdate(): void;
}

export const HCaptcha: HCaptchaHook = {
  mounted() {
    this.sitekey = this.el.dataset.sitekey || '';
    this.preserveWidget = true; // Flag to prevent unnecessary re-renders
    this.isCompleted = false; // Track completion state
    this.completedToken = null; // Store the token for re-verification
    
    // Store reference to this hook on the element for global callback access
    (this.el as LiveViewElement).phxHook = this;
    
    this.loadHCaptcha();
  },

  updated() {
    // Check if the widget container is empty (indicating LiveView destroyed it)
    const hasWidget = this.el.children.length > 0;
    const sitekeyChanged = this.el.dataset.sitekey !== this.sitekey;
    
    // Only re-render if widget is missing or sitekey changed
    if (!hasWidget || sitekeyChanged) {
      this.sitekey = this.el.dataset.sitekey || '';
      this.loadHCaptcha();
    } else if (this.isCompleted) {
      // If widget exists but we had a completion, ensure visual state is shown
      this.createCompletedIndicator();
    }
  },

  loadHCaptcha(): void {
    // If API is already confirmed loaded and render method is available, render immediately
    if (hCaptchaApiLoaded && window.hcaptcha && typeof window.hcaptcha.render === 'function') {
      this.renderCaptcha();
      return;
    }

    // If we already have a load promise, wait for it
    if (hCaptchaLoadPromise) {
      hCaptchaLoadPromise.then(() => {
        if (this.el && !this.widgetId && window.hcaptcha && typeof window.hcaptcha.render === 'function') {
          this.renderCaptcha();
        }
      });
      return;
    }

    // Create load promise
    hCaptchaLoadPromise = new Promise<void>((resolve) => {
      // Set up global callback for when hCaptcha API is ready (only once)
      if (!window.hCaptchaLoaded) {
        window.hCaptchaLoaded = (): void => {
          // Add a small delay to ensure the API is fully initialized
          setTimeout(() => {
            hCaptchaApiLoaded = true;
            // Find all mounted hCaptcha hooks and render them
            document.querySelectorAll('[data-sitekey]').forEach((el: Element) => {
              const element = el as LiveViewElement;
              if (element.phxHook && element.phxHook.renderCaptcha && !element.phxHook.widgetId) {
                // Double-check that API is ready before rendering
                if (window.hcaptcha && typeof window.hcaptcha.render === 'function') {
                  element.phxHook.renderCaptcha();
                }
              }
            });
            resolve();
          }, 50); // Small delay to ensure API is fully ready
        };
      }

      // Load hCaptcha script with explicit rendering and onload callback (only if not already loading)
      if (!document.querySelector('script[src*="hcaptcha.com/1/api.js"]')) {
        const script = document.createElement('script');
        script.src = 'https://js.hcaptcha.com/1/api.js?render=explicit&onload=hCaptchaLoaded';
        script.async = true;
        script.defer = true;
        document.head.appendChild(script);
      }
    });

    // Wait for the API to load
    hCaptchaLoadPromise.then(() => {
      if (this.el && !this.widgetId && window.hcaptcha && typeof window.hcaptcha.render === 'function') {
        this.renderCaptcha();
      }
    });
  },

  renderCaptcha(): void {
    // Comprehensive check that API is loaded and fully ready
    if (!hCaptchaApiLoaded || !window.hcaptcha || !this.sitekey) {
      console.warn('hCaptcha API not ready or missing sitekey, skipping render');
      return;
    }

    // Additional check to ensure the hcaptcha.render method is available and ready
    if (typeof window.hcaptcha.render !== 'function') {
      console.warn('hCaptcha render method not available, API may not be fully loaded');
      return;
    }

    // Clear any existing widget first
    if (this.widgetId && window.hcaptcha) {
      try {
        window.hcaptcha.remove(this.widgetId);
      } catch (error) {
        console.error('Failed to remove existing hCaptcha widget:', error);
      }
    }
    this.el.innerHTML = '';

    try {
      this.widgetId = window.hcaptcha.render(this.el, {
        sitekey: this.sitekey,
        callback: (token: string) => {
          // Mark as completed and store token
          this.isCompleted = true;
          this.completedToken = token;
          
          // Preserve form data before LiveView update
          this.preserveFormBeforeUpdate();
          
          // Small delay to ensure form data is captured
          setTimeout(() => {
            // Send to LiveView
            this.pushEvent('captcha_verified', { token });
            
            // Also send to FormHandler if it exists
            this.notifyFormHandler('captcha_verified_client', { token });
          }, 100);
        },
        'error-callback': () => {
          this.isCompleted = false;
          this.completedToken = null;
          this.removeCompletedIndicator();
          this.preserveFormBeforeUpdate();
          this.pushEvent('captcha_error', {});
          this.notifyFormHandler('captcha_error_client', {});
        },
        'expired-callback': () => {
          this.isCompleted = false;
          this.completedToken = null;
          this.removeCompletedIndicator();
          this.preserveFormBeforeUpdate();
          this.pushEvent('captcha_expired', {});
          this.notifyFormHandler('captcha_error_client', {});
        },
        'chalexpired-callback': () => {
          this.isCompleted = false;
          this.completedToken = null;
          this.removeCompletedIndicator();
          this.preserveFormBeforeUpdate();
          this.pushEvent('captcha_expired', {});
          this.notifyFormHandler('captcha_error_client', {});
        },
        theme: 'dark',
        size: 'normal'
      });
      
      // If we had a previous completion, try to restore the visual state
      if (this.isCompleted && this.completedToken && window.hcaptcha.setData) {
        try {
          // Attempt to restore completed state (this may not work with all hCaptcha versions)
          window.hcaptcha.setData(this.widgetId, { 'h-captcha-response': this.completedToken });
        } catch (error) {
          // If restoration fails, create a visual indicator
          this.createCompletedIndicator();
        }
      }
      
    } catch (error) {
      console.error('Failed to render hCaptcha:', error);
      this.pushEvent('captcha_error', {});
    }
  },
  
  createCompletedIndicator(): void {
    // Remove any existing indicator first
    const existingOverlay = this.el.querySelector('.hcaptcha-completed-overlay');
    if (existingOverlay) {
      existingOverlay.remove();
    }
    
    // Create a visual overlay to show completion status
    if (this.isCompleted && this.widgetId) {
      const overlay = document.createElement('div');
      overlay.className = 'hcaptcha-completed-overlay';
      overlay.style.cssText = `
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(76, 175, 80, 0.1);
        border: 2px solid #4CAF50;
        border-radius: 4px;
        display: flex;
        align-items: center;
        justify-content: center;
        pointer-events: none;
        z-index: 10;
      `;
      
      const checkmark = document.createElement('div');
      checkmark.innerHTML = '✓';
      checkmark.style.cssText = `
        color: #4CAF50;
        font-size: 24px;
        font-weight: bold;
        background: white;
        border-radius: 50%;
        width: 30px;
        height: 30px;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 2px 4px rgba(0,0,0,0.2);
      `;
      
      overlay.appendChild(checkmark);
      
      // Make the container relative positioned
      this.el.style.position = 'relative';
      this.el.appendChild(overlay);
    }
  },
  
  removeCompletedIndicator(): void {
    const overlay = this.el.querySelector('.hcaptcha-completed-overlay');
    if (overlay) {
      overlay.remove();
    }
  },
  
  notifyFormHandler(eventName: string, data: any): void {
    const form = this.el.closest('form') as LiveViewElement;
    if (form && form.phxHook && form.phxHook.handleEvent) {
      (form.phxHook as FormHandlerHook).handleEvent(eventName, data);
    }
  },
  
  preserveFormBeforeUpdate(): void {
    const form = this.el.closest('form') as LiveViewElement;
    if (form && form.phxHook && form.phxHook.preserveFormData) {
      (form.phxHook as FormHandlerHook).preserveFormData?.();
    }
  },

  destroyed(): void {
    if (window.hcaptcha && this.widgetId) {
      try {
        window.hcaptcha.remove(this.widgetId);
      } catch (error) {
        console.error('Failed to cleanup hCaptcha widget:', error);
      }
    }
  }
} as HCaptchaHook;

// Auto-register the hook if not already registered
if (typeof window !== 'undefined' && window.liveSocket) {
  if (!window.liveSocket.hooks) {
    window.liveSocket.hooks = {};
  }
  window.liveSocket.hooks.HCaptcha = HCaptcha;
}