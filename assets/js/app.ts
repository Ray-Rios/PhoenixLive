// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Topbar for progress indicators
import topbar from "./topbar";

// Phoenix LiveView
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// Import TypeScript hooks
import { TerminalTypewriter } from "./terminal_typewriter";
import { FileDragDrop, FileUpload } from "./file_drag_drop";

// Import Three.js hooks
import { ThreeJSScene } from "./threejs/hooks";
import { HomeGalaxyScene } from "./threejs/galaxy-scene";
import { NebulaScene } from "./threejs/scenes/nebula-scene";
import { StarfieldScene } from "./threejs/scenes/starfield-scene";
import { VoidScene } from "./threejs/scenes/void-scene";
import { GlobalCameraController } from "./threejs/controls/global-camera-controller";
import { RichEditor } from "./rich_editor";
import { BlogAutosave } from "./blog_autosave_hook";
import { DeviceFingerprintHook } from "./device_fingerprint";
import { GlassTheme } from "./glass_theme";
import { BackgroundUpdater } from "./background_updater";
import { GlobalHooks } from "./global_hooks";
import { ProfileSettings } from "./profile_settings";
import { ColorPicker } from "./color_picker";

// Import Desktop hooks
import "./desktop";

// CSRF token
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Auto-dismiss flash notifications - DISABLED to let AutoDismissFlash hook handle it
// document.addEventListener('DOMContentLoaded', () => {
//   // Schedule removal of any existing flash messages after initial join
//   const scheduleDismiss = () => {
//     document.querySelectorAll('[data-auto-dismiss]').forEach((el: Element) => {
//       const h = el as HTMLElement;
//       if (!h.dataset.dismissScheduled) {
//         h.dataset.dismissScheduled = 'true';
//         const delay = parseInt(h.dataset.autoDismiss || '4000');
//         setTimeout(() => {
//           h.style.opacity = '0';
//           setTimeout(() => h.remove(), 300);
//         }, delay);
//       }
//     });
//   };

//   // Run once on DOMContentLoaded, and again after LiveView page loading stops
//   scheduleDismiss();
//   window.addEventListener('phx:page-loading-stop', () => setTimeout(scheduleDismiss, 250));
// });

// AutoDismissFlash Hook for individual flash management
const AutoDismissFlash = {
  mounted(this: { el: HTMLElement }) {
    const el = this.el;
    const delay = parseInt(el.dataset.autoDismiss || '3000');
    
    console.log('🔔 AutoDismissFlash mounted, will dismiss in', delay, 'ms');
    
    // Clear any existing timeout
    if (el.dataset.dismissTimeout) {
      clearTimeout(parseInt(el.dataset.dismissTimeout));
    }
    
    // Set new timeout
    const timeoutId = setTimeout(() => {
      console.log('🔔 AutoDismissFlash: Dismissing flash notification');
      // Fade out
      el.style.opacity = '0';
      setTimeout(() => {
        // Remove from DOM
        el.remove();
      }, 300);
    }, delay);
    
    el.dataset.dismissTimeout = timeoutId.toString();
  },
  
  updated(this: { el: HTMLElement }) {
    // Reset timeout when flash content changes
    const el = this.el;
    const delay = parseInt(el.dataset.autoDismiss || '3000');
    
    // Clear any existing timeout
    if (el.dataset.dismissTimeout) {
      clearTimeout(parseInt(el.dataset.dismissTimeout));
    }
    
    // Set new timeout
    const timeoutId = setTimeout(() => {
      // Trigger the same dismiss animation as clicking
      el.style.transform = 'translateX(120%)';
      el.style.opacity = '0';
      setTimeout(() => {
        // Remove from DOM
        el.remove();
      }, 300);
    }, delay);
    
    el.dataset.dismissTimeout = timeoutId.toString();
  },
  
  destroyed(this: { el: HTMLElement }) {
    // Clear timeout when element is removed
    const el = this.el;
    if (el.dataset.dismissTimeout) {
      clearTimeout(parseInt(el.dataset.dismissTimeout));
    }
  }
};

// Message Reactions Hook (simplified)
const MessageReactions = {
  mounted() {
    console.log('Message Reactions mounted');
  },
  updated() {
    console.log('Message Reactions updated');
  }
};

// Desktop Window Hook (placeholder to prevent missing hook errors)
const DesktopWindow = {
  mounted() {
    console.log('DesktopWindow mounted');
  },
  updated() {},
  destroyed() {}
};

// ChatInput Hook - Handle Enter key to submit, Shift+Enter for newline
const ChatInput = {
  mounted(this: any) {
    this.el.addEventListener('keydown', (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        // Find the parent form and submit it
        const form = this.el.closest('form');
        if (form) {
          const submitEvent = new Event('submit', { bubbles: true, cancelable: true });
          form.dispatchEvent(submitEvent);
        }
      }
    });
  },
  updated() {},
  destroyed() {}
};

// Reload Page Hook - Used for applying background changes
const ReloadPage = {
  mounted(this: any) {
    this.handleEvent("reload_page", ({delay}: {delay: number}) => {
      setTimeout(() => {
        window.location.reload();
      }, delay || 1000);
    });
  }
};

// Hooks object - register all hooks referenced in templates
const Hooks = {
  // Core/site
  TerminalTypewriter,         // Used on homepage
  AutoDismissFlash,           // Flash notification auto-dismiss
  DeviceFingerprint: DeviceFingerprintHook,
  GlassTheme,                 // Glass theme customization
  BackgroundUpdater,          // Background customization
  ColorPicker,                // Color input handler for LiveView
  // Background Scenes
  HomeGalaxyScene,            // Default galaxy background
  NebulaScene,                // Colorful nebula with gas clouds
  StarfieldScene,             // Hyperspace scrolling stars
  VoidScene,                  // Minimal void with dim stars
  GlobalCameraController,     // Global camera controls for all pages
  // Files
  FileDragDrop,
  FileUpload,
  // Blog/editor
  RichEditor,
  BlogAutosave,
  // Chat
  MessageReactions,
  ChatInput,
  // Desktop
  DesktopWindow: (window as any).DesktopWindow,
  ResizeHandle: (window as any).ResizeHandle,
  GlobalHooks,
  ProfileSettings,
  // Utility
  ReloadPage
};

// Disabled hooks for debugging (add back as needed):
// MessageReactions, RichEditor, FileDragDrop, FileUpload,
// BlogAutosave, FormHandler, FormPreserver, DeviceFingerprint

// Connect LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// Expose liveSocket on window
(window as any).liveSocket = liveSocket

liveSocket.connect()

console.log('✅ Phoenix LiveView connected');
// Note: Three.js background scenes are mounted via Phoenix LiveView hooks
// (phx-hook attributes) so we avoid manual initialization here which
// can conflict with LiveView's hook lifecycle.

// Static scene initializer: for layout-mounted background canvas elements that
// are not part of a LiveView patch (they use data-static-scene), initialize
// the matching Three.js hook directly so LiveView doesn't attempt to attach
// hooks to DOM nodes it didn't render.
let staticSceneInstance: any = null;
const initializeStaticScenes = () => {
  try {
    const staticEls = Array.from(document.querySelectorAll('[data-static-scene]')) as HTMLElement[];
    staticEls.forEach((el) => {
      const sceneName = el.getAttribute('data-static-scene');
      if (!sceneName) return;

      // Map scene names to hook constructors available in Hooks
      const hookConstructor: any = (Hooks as any)[sceneName];
      if (!hookConstructor) {
        console.warn('No hook registered for static scene:', sceneName);
        return;
      }

  // If this element was already initialized, skip
  if ((el as any)._threeJSHook) return;

      // Create a minimal hook-like context and call mounted()
      try {
        const instance = Object.create(hookConstructor);
        instance.el = el;
        if (typeof instance.mounted === 'function') {
          instance.mounted.call(instance);
          // Mark the element as initialized and store instance
          (el as any)._threeJSHook = instance;
          staticSceneInstance = instance;
          console.log('✅ Initialized static scene:', sceneName, 'on', el.id || el.tagName);
        }
      } catch (err) {
        console.error('❌ Failed to initialize static scene', sceneName, err);
      }
    });
  } catch (err) {
    console.error('❌ Error initializing static scenes', err);
  }
};

// Run after a short delay to allow LiveSocket to perform initial patches
setTimeout(initializeStaticScenes, 250);

// Re-initialize on page navigation if needed
window.addEventListener('phx:page-loading-stop', () => {
  setTimeout(() => {
    if (document.querySelector('[data-static-scene]')) {
      initializeStaticScenes();
    }
  }, 100);
});

// MutationObserver fallback: if LiveView removes and re-inserts the canvas during a patch,
// detect insertion and re-initialize the static scene on the new node.
try {
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'childList' && m.addedNodes.length > 0) {
        for (const node of Array.from(m.addedNodes)) {
          if (!(node instanceof HTMLElement)) continue;
          if (node.matches && node.matches('[data-static-scene]')) {
            setTimeout(() => initializeStaticScenes(), 50);
            return;
          }
          // Also check descendants
          if (node.querySelector && node.querySelector('[data-static-scene]')) {
            setTimeout(() => initializeStaticScenes(), 50);
            return;
          }
        }
      }
    }
  });

  observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
} catch (e) {
  // ignore mutation observer failures
}

// Also log removals of the global background canvas for debugging
try {
  const removalObserver = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'childList' && m.removedNodes.length > 0) {
        for (const node of Array.from(m.removedNodes)) {
          if (!(node instanceof HTMLElement)) continue;
          if (node.id === 'global-background-canvas' || (node.querySelector && node.querySelector('#global-background-canvas'))) {
            console.warn('🧨 global-background-canvas was removed from DOM', node);
            try { console.trace(); } catch(e) {}
          }
        }
      }
    }
  });

  removalObserver.observe(document.documentElement || document.body, { childList: true, subtree: true });
} catch (e) {
  // ignore
}

// Global error diagnostics: capture unhandled errors and list phx-hook elements
window.addEventListener('error', (event) => {
  try {
    console.error('Global error captured:', event.message, event.error);
    const hookEls = Array.from(document.querySelectorAll('[data-phx-hook], [phx-hook]'));
    console.group('PHX HOOK ELEMENTS SNAPSHOT');
    console.log('Total phx-hook elements found:', hookEls.length);
    hookEls.forEach((el, idx) => {
      try {
        const ds = (el as HTMLElement).dataset;
        console.log(idx, el.tagName, 'id=', el.id || '(no id)', 'phx-hook=', el.getAttribute('phx-hook') || el.getAttribute('data-phx-hook'), 'dataset=', ds);
      } catch (e) {
        console.log(idx, 'error reading element', e);
      }
    });
    console.groupEnd();
  } catch (e) {
    console.error('Failed to capture phx-hook snapshot', e);
  }
});

window.addEventListener('unhandledrejection', (ev) => {
  console.error('Unhandled promise rejection:', ev.reason);
});

// Debug helper: log forms with phx-submit to track client-side submits
document.addEventListener('submit', (ev) => {
  try {
    const target = ev.target as HTMLElement | null;
    if (!target) return;
    if (target instanceof HTMLFormElement && target.hasAttribute('phx-submit')) {
      console.log('🔔 phx-submit form submitted:', target.id || target.getAttribute('name') || '(unnamed)');
    }
  } catch (e) {
    // ignore
  }
}, true);