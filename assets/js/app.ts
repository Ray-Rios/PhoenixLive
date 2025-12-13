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
import { AudioHook } from "./audio";

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
  mounted(this: { el: HTMLElement, pushEvent: (event: string, payload: any) => void }) {
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
        // Push event to server to clear flash from assigns
        if (el.dataset.key) {
          this.pushEvent("lv:clear-flash", { key: el.dataset.key });
        }
        // Remove from DOM
        el.remove();
      }, 300);
    }, delay);
    
    el.dataset.dismissTimeout = timeoutId.toString();
  },
  
  updated(this: { el: HTMLElement, pushEvent: (event: string, payload: any) => void }) {
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
        // Push event to server to clear flash from assigns
        if (el.dataset.key) {
          this.pushEvent("lv:clear-flash", { key: el.dataset.key });
        }
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

// Message list hook: auto-scroll behavior
const MessageList = {
  autoScrollEnabled: false,

  mounted() {
    const el = this.el as HTMLElement;
    const THRESHOLD = 50; // pixels
    this.autoScrollEnabled = el.dataset.autoScroll === "true";
    console.log("MessageList mounted, autoScroll:", this.autoScrollEnabled);

    // Find existing elements
    const toggleBtn = document.getElementById('auto-scroll-toggle');
    const notifier = document.getElementById('new-messages-notifier');

    const scrollToBottom = () => {
      el.scrollTop = el.scrollHeight;
    };

    const updateButtonState = () => {
      if (!toggleBtn) return;
      
      // Base classes for dark-glass look
      const baseClasses = ['absolute', 'bottom-4', 'right-4', 'z-50', 'w-[30px]', 'h-[30px]', 'rounded-full', 'shadow-lg', 'transition-all', 'duration-300', 'flex', 'items-center', 'justify-center', 'bg-black/50', 'backdrop-blur-md', 'border', 'border-white/10', 'text-white', 'hover:bg-black/70'];
      
      // Reset classes
      toggleBtn.className = baseClasses.join(' ');

      if (this.autoScrollEnabled) {
        // Locked state - Lock icon
        toggleBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
        </svg>`;
        toggleBtn.title = "Auto-scroll ON (Locked to bottom)";
        // Add a subtle green glow or indicator if desired, but user asked for dark-glass lock
        toggleBtn.classList.add('text-green-400'); 
      } else {
        // Unlocked state - Down Arrow
        toggleBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
        </svg>`;
        toggleBtn.title = "Scroll to bottom";
        toggleBtn.classList.remove('text-green-400');
      }
    };

    // Initialize button state
    updateButtonState();

    if (toggleBtn) {
      // Remove old listeners to prevent duplicates if re-mounted (though mounted runs once per element)
      const newBtn = toggleBtn.cloneNode(true) as HTMLElement;
      toggleBtn.parentNode?.replaceChild(newBtn, toggleBtn);
      
      newBtn.addEventListener('click', () => {
        if (this.autoScrollEnabled) {
           // If locked, clicking unlocks it (and stays at current position)
           this.autoScrollEnabled = false;
           // Push event to server to update state
           this.pushEvent("toggle_auto_scroll", { enabled: false });
        } else {
           // If unlocked, clicking scrolls to bottom and locks it
           this.autoScrollEnabled = true;
           scrollToBottom();
           if (notifier) notifier.classList.add('hidden');
           // Push event to server to update state
           this.pushEvent("toggle_auto_scroll", { enabled: true });
        }
        updateButtonState();
      });
    }

    if (notifier) {
      notifier.addEventListener('click', () => {
        scrollToBottom();
        notifier.classList.add('hidden');
        // Mark read
        const lastMsg = el.querySelector(':scope > [id^="message-"]:last-child');
        if (lastMsg) {
           const id = lastMsg.id.replace('message-', '');
           this.pushEvent('messages_read', { last_read_id: id });
        }
      });
    }

    // Initial scroll-to-bottom when mounted
    // Use requestAnimationFrame to ensure layout is ready
    requestAnimationFrame(() => {
      if (this.autoScrollEnabled) {
        scrollToBottom();
      }
    });

    // Also try again after a short delay for images
    setTimeout(() => {
      if (this.autoScrollEnabled) {
        scrollToBottom();
      }
    }, 300);

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

    // Scroll listener to mark messages as read
    let scrollTimeout;
    el.addEventListener('scroll', () => {
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(() => {
        const atBottom = (el.scrollHeight - el.scrollTop - el.clientHeight) <= THRESHOLD;
        
        // If user scrolls up, disable auto-scroll
        if (!atBottom && this.autoScrollEnabled) {
          this.autoScrollEnabled = false;
          this.pushEvent("toggle_auto_scroll", { enabled: false });
          updateButtonState();
        }
        
        // If user scrolls to bottom, enable auto-scroll
        if (atBottom && !this.autoScrollEnabled) {
          this.autoScrollEnabled = true;
          this.pushEvent("toggle_auto_scroll", { enabled: true });
          updateButtonState();
          
          if (notifier) notifier.classList.add('hidden');
          const lastMsg = el.querySelector(':scope > [id^="message-"]:last-child');
          if (lastMsg) {
             const id = lastMsg.id.replace('message-', '');
             this.pushEvent('messages_read', { last_read_id: id });
          }
        }
      }, 200);
    });

    // MutationObserver to detect appended messages and auto-scroll
    const mo = new MutationObserver((mutations) => {
      // Only auto-scroll if a new MESSAGE was added, not just a status update
      const hasNewMessages = mutations.some(m => {
        return Array.from(m.addedNodes).some((n: any) => {
             return n.nodeType === 1 && n.id && n.id.startsWith('message-');
        });
      });

      if (hasNewMessages) {
        if (this.autoScrollEnabled) {
          scrollToBottom();
        } else {
           if (notifier) notifier.classList.remove('hidden');
        }
      }
    });

    mo.observe(el, { childList: true, subtree: true });

    // Top sentinel for loading older messages
    const topSentinel = document.createElement('div');
    topSentinel.style.width = '100%';
    topSentinel.style.height = '1px';
    topSentinel.id = 'load-older-sentinel';
    if (el.firstChild) el.insertBefore(topSentinel, el.firstChild);

    let loadingOlder = false;
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && !loadingOlder) {
          const firstMsg = el.querySelector(':scope > [id^="message-"]');
          if (!firstMsg) return;
          const id = firstMsg.id.replace('message-', '');
          loadingOlder = true;
          this.pushEvent('load_older', { before_id: id });
          setTimeout(() => (loadingOlder = false), 800);
        }
      });
    }, { root: el, threshold: 0.1 });

    io.observe(topSentinel);

    // Cleanup
    this.destroyed = () => {
      mo.disconnect();
      io.disconnect && io.disconnect();
      clearInterval(timeInterval);
    };
  },
  updated() {
    // No-op
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
    // Handle Enter key
    this.el.addEventListener('keydown', (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const form = this.el.closest('form');
        if (form) {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
        }
      }
    });

    // Handle custom insert-text event (for emoji picker)
    this.el.addEventListener('insert-text', (e: CustomEvent) => {
      const text = e.detail.text;
      if (!text) return;
      
      const start = this.el.selectionStart;
      const end = this.el.selectionEnd;
      const value = this.el.value;
      
      this.el.value = value.substring(0, start) + text + value.substring(end);
      this.el.selectionStart = this.el.selectionEnd = start + text.length;
      this.el.focus();
      
      // Trigger input event for LiveView binding
      this.el.dispatchEvent(new Event('input', { bubbles: true }));
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

// FullscreenContainer hook - prevents body scrolling on fullscreen pages
const FullscreenContainer = {
  mounted() {
    // Immediately add no-scroll to prevent any page scrolling
    document.documentElement.classList.add('no-scroll');
    document.body.classList.add('no-scroll');
    
    // Ensure proper positioning based on navbar/taskbar state
    const navbar = document.getElementById('main-navbar');
    const isHidden = navbar?.style.transform === 'translateY(-100%)';
    
    if (isHidden) {
      this.el.style.top = '0';
      this.el.style.bottom = '0';
    } else {
      this.el.style.top = '30px';
      this.el.style.bottom = '35px';
    }
  },
  destroyed() {
    document.documentElement.classList.remove('no-scroll');
    document.body.classList.remove('no-scroll');
  }
};

// Sidebar Resizer Hook
const SidebarResizer = {
  mounted() {
    const el = this.el as HTMLElement;
    const handle = el.querySelector('.resize-handle') as HTMLElement;
    const content = el.querySelector('.sidebar-content') as HTMLElement;
    
    if (!handle) return;

    let isResizing = false;
    let startX = 0;
    let startWidth = 0;
    let lastWidth = 256; // Default width
    let isCollapsed = false;
    let clickThreshold = 5; // Pixels to distinguish click from drag

    // Restore state from localStorage
    const savedWidth = localStorage.getItem('forum_sidebar_width');
    const savedCollapsed = localStorage.getItem('forum_sidebar_collapsed');

    if (savedWidth) {
      lastWidth = parseInt(savedWidth);
      if (!savedCollapsed || savedCollapsed === 'false') {
        el.style.width = `${lastWidth}px`;
      }
    }

    const onMouseDown = (e: MouseEvent) => {
      isResizing = true;
      startX = e.clientX;
      startWidth = el.offsetWidth;
      
      document.addEventListener('mousemove', onMouseMove);
      document.addEventListener('mouseup', onMouseUp);
      
      // Prevent text selection during drag
      document.body.style.userSelect = 'none';
      document.body.style.cursor = 'col-resize';
    };

    const onMouseMove = (e: MouseEvent) => {
      if (!isResizing) return;
      
      const dx = e.clientX - startX;
      let newWidth = startWidth + dx;
      
      // Constraints
      if (newWidth < 100) newWidth = 10; // Snap to collapse
      if (newWidth > 600) newWidth = 600; // Max width
      
      if (newWidth <= 10) {
        if (content) content.style.display = 'none';
      } else {
        if (content) content.style.display = 'block';
      }
      
      el.style.width = `${newWidth}px`;
    };

    const onMouseUp = (e: MouseEvent) => {
      if (!isResizing) return;
      
      const dx = Math.abs(e.clientX - startX);
      isResizing = false;
      
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
      document.body.style.userSelect = '';
      document.body.style.cursor = '';

      // Check if it was a click (toggle)
      if (dx < clickThreshold) {
        // If clicking the handle, we want to collapse it (since handle is only visible when open)
        this.pushEvent("toggle_sidebar", {});
      } else {
        // It was a drag, save the new state
        const currentWidth = el.offsetWidth;
        if (currentWidth <= 100) {
          // Dragged to collapse - trigger server event to close fully
          this.pushEvent("toggle_sidebar", {});
        } else {
          isCollapsed = false;
          lastWidth = currentWidth;
          localStorage.setItem('forum_sidebar_width', lastWidth.toString());
          localStorage.setItem('forum_sidebar_collapsed', 'false');
        }
      }
    };

    const toggleSidebar = () => {
      // This is called when clicking the handle.
      // Since handle is only visible when open, we always collapse.
      this.pushEvent("toggle_sidebar", {});
    };

    handle.addEventListener('mousedown', onMouseDown);
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
  AudioHook,                  // Audio notification system
  FullscreenContainer,        // Prevents body scrolling on fullscreen pages
  SidebarResizer,             // Handles sidebar resizing and toggling
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

  // If this element was already initialized
  if ((el as any)._threeJSHook) {
    // Check if the scene has changed
    if ((el as any)._currentSceneName === sceneName) {
      return;
    }
    
    // Scene changed, destroy old one
    console.log('🔄 Switching static scene to:', sceneName);
    const oldHook = (el as any)._threeJSHook;
    if (typeof oldHook.destroyed === 'function') {
      try {
        oldHook.destroyed.call(oldHook);
      } catch (e) {
        console.error('Error destroying old scene:', e);
      }
    }
    (el as any)._threeJSHook = null;
  }

      // Create a minimal hook-like context and call mounted()
      try {
        const instance = Object.create(hookConstructor);
        instance.el = el;
        if (typeof instance.mounted === 'function') {
          instance.mounted.call(instance);
          // Mark the element as initialized and store instance
          (el as any)._threeJSHook = instance;
          (el as any)._currentSceneName = sceneName;
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
      // Handle attribute changes (scene switching)
      if (m.type === 'attributes' && m.attributeName === 'data-static-scene') {
        setTimeout(() => initializeStaticScenes(), 50);
        return;
      }

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

  observer.observe(document.documentElement || document.body, { 
    childList: true, 
    subtree: true, 
    attributes: true, 
    attributeFilter: ['data-static-scene'] 
  });
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