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
import { ColorPicker, OpacitySlider } from "./color_picker";
import QuillEditorHook from "./quill_editor_hook";
import CollaborativeQuillHook from "./collaborative_quill_hook";

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

// Message list hook: only auto-scroll if user is at bottom, otherwise show a "New messages" notifier
const MessageList = {
  mounted() {
    const el = this.el as HTMLElement;
    let isAtBottom = true;
    const THRESHOLD = 24; // pixels

    // Create notifier element
    const notifier = document.createElement('div');
    notifier.className = 'fixed bottom-24 right-6 bg-blue-600 text-white px-3 py-1.5 rounded shadow cursor-pointer z-50 text-sm';
    notifier.textContent = 'New messages';
    notifier.style.display = 'none';
    document.body.appendChild(notifier);

    const updateIsAtBottom = () => {
      const atBottom = (el.scrollHeight - el.scrollTop - el.clientHeight) <= THRESHOLD;
      isAtBottom = atBottom;
      if (isAtBottom) {
        notifier.style.display = 'none';
      }
    };

    // Initial scroll-to-bottom when mounted
    setTimeout(() => {
      el.scrollTop = el.scrollHeight;
      updateIsAtBottom();
    }, 50);

    // Update relative time badges inside messages container
    const formatRelative = (d) => {
      const now = Date.now();
      const then = new Date(d).getTime();
      const diff = Math.floor((now - then) / 1000);
      if (diff < 5) return 'just now';
      if (diff < 60) return `${diff}s ago`;
      const mins = Math.floor(diff / 60);
      if (mins < 60) return `${mins}m ago`;
      const hours = Math.floor(mins / 60);
      if (hours < 24) return `${hours}h ago`;
      const days = Math.floor(hours / 24);
      return `${days}d ago`;
    };

    const updateTimes = () => {
      Array.from(el.querySelectorAll('time[datetime]') as HTMLElement[]).forEach((t) => {
        const dt = t.getAttribute('datetime');
        if (!dt) return;
        const rel = formatRelative(dt);
        t.textContent = rel;
        // Keep original hover text as full ISO timestamp
        t.title = new Date(dt).toLocaleString();
      });
    };

    updateTimes();
    const timeInterval = setInterval(updateTimes, 30_000);

    // Scroll listener to update at-bottom status
    el.addEventListener('scroll', () => updateIsAtBottom());

    // MutationObserver to detect appended messages
    let loadingOlder = false;
    const mo = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.addedNodes && m.addedNodes.length > 0) {
          if (isAtBottom) {
            // Auto-scroll
            el.scrollTop = el.scrollHeight;
            // Optionally mark as read
            this.pushEvent('messages_read', {});
          } else {
            // Show notifier
            notifier.style.display = 'block';
          }
        }
      }
    });

    mo.observe(el, { childList: true, subtree: false });

    // Top sentinel for loading older messages
    const topSentinel = document.createElement('div');
    topSentinel.style.width = '100%';
    topSentinel.style.height = '1px';
    topSentinel.id = 'load-older-sentinel';
    // Insert sentinel at the top
    if (el.firstChild) el.insertBefore(topSentinel, el.firstChild);

    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && !loadingOlder) {
          // Determine first message id
          const firstMsg = el.querySelector(':scope > [id^="message-"]');
          if (!firstMsg) return;
          const id = firstMsg.id.replace('message-', '');
          loadingOlder = true;
          this.pushEvent('load_older', { before_id: id });

          // Allow subsequent loads after short delay (server will respond with older messages)
          setTimeout(() => (loadingOlder = false), 800);
        }
      });
    }, { root: el, threshold: 0.1 });

    io.observe(topSentinel);

    notifier.addEventListener('click', () => {
      el.scrollTop = el.scrollHeight;
      notifier.style.display = 'none';
      // Notify server that user has read the messages
      this.pushEvent('messages_read', {});
      updateIsAtBottom();
    });

    // Cleanup
    this.destroy = () => {
      mo.disconnect();
      io.disconnect && io.disconnect();
      notifier.remove();
      topSentinel.remove();
      clearInterval(timeInterval);
    };
  },
  updated() {
    // No-op here; MutationObserver handles appends
  },
  destroyed() {
    if (typeof this.destroy === 'function') this.destroy();
  }
};

// Desktop Window Hook (placeholder to prevent missing hook errors)
export const DesktopWindow = {
  mounted() {
    console.log('DesktopWindow mounted');
  },
  updated() {
    // Intentionally empty - no update logic needed
  },
  destroyed() {
    // Intentionally empty - no cleanup needed
  }
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
  OpacitySlider,              // Opacity slider for avatar border
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
  QuillEditor: QuillEditorHook,
  CollaborativeQuill: CollaborativeQuillHook,
  // Chat
  MessageReactions,
  MessageList,
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
const liveSocket = new LiveSocket("/live", Socket, {
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
} catch {
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
            try { console.trace(); } catch {
              // Ignore trace errors
            }
          }
        }
      }
    }
  });

  removalObserver.observe(document.documentElement || document.body, { childList: true, subtree: true });
} catch {
  // ignore removal observer failures
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
      console.log('\ud83d\udd14 phx-submit form submitted:', target.id || target.getAttribute('name') || '(unnamed)');
    }
  } catch {
    // ignore form submit logging errors
  }
}, true);