// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Topbar for progress indicators
import topbar from "./topbar";

// Phoenix LiveView
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// Import TypeScript hooks
import { TerminalTypewriter } from "./terminal_typewriter";
import { HCaptcha } from "./hcaptcha";
import { FormHandler } from "./form_handler";
import { FormPreserver } from "./form_preserver";
import { FileDragDrop, FileUpload } from "./file_drag_drop";

// Import remaining JavaScript hooks (to be converted later)
import { BabylonScene } from "./babylon/babylon_hooks";
import { OpenWorldLobbySceneHook } from "./babylon/open_world_lobby_scene_class";
import { HomeGalaxyScene } from "./babylon/home_galaxy_scene";
import { RichEditor } from "./rich_editor";
import { BlogAutosave } from "./blog_autosave_hook";
import "./quest_engine";

// Import TypeScript interfaces
import { 
  QuestGameHook, 
  MessageReactionsHook, 
  FlashNotificationHook,
  LiveSocketInstrumentation,
  StripeEvent,
  DownloadFileEvent,
  NotificationEvent
} from "./types/app";

// CSRF token
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";

// ---------------------------
// Hooks
// ---------------------------

// Quest Game Hook
const QuestGame: QuestGameHook = {
  mounted() {
    this.players = JSON.parse(this.el.dataset.players || '{}');
    this.currentPlayerId = this.el.dataset.currentPlayer || '';

    this.questEngine = new window.QuestEngine(this.el as HTMLCanvasElement, this);
    this.questEngine.updatePlayers(this.players);
    this.questEngine.setCurrentPlayer(this.currentPlayerId);

    console.log('Quest Game initialized with', Object.keys(this.players).length, 'players');
  },

  updated() {
    if (this.questEngine) {
      const newPlayers = JSON.parse(this.el.dataset.players || '{}');
      this.questEngine.updatePlayers(newPlayers);
    }
  },

  destroyed() {
    if (this.questEngine) {
      // Clean up if needed
    }
  }
} as QuestGameHook;

// Message Reactions Hook for chat functionality
const MessageReactions: MessageReactionsHook = {
  mounted() {
    this.setupMessageReactions();
  },

  updated() {
    this.setupMessageReactions();
  },

  setupMessageReactions(): void {
    // Add hover effects for message reactions
    this.el.querySelectorAll('.message').forEach((message: Element) => {
      const messageEl = message as HTMLElement;
      if (!messageEl.dataset.reactionsSetup) {
        messageEl.addEventListener('mouseenter', () => {
          this.showReactionButtons(messageEl);
        });
        
        messageEl.addEventListener('mouseleave', () => {
          this.hideReactionButtons(messageEl);
        });
        
        messageEl.dataset.reactionsSetup = 'true';
      }
    });
  },

  showReactionButtons(messageEl: HTMLElement): void {
    // Add reaction buttons if they don't exist
    let reactionBar = messageEl.querySelector('.reaction-bar') as HTMLElement;
    if (!reactionBar) {
      reactionBar = document.createElement('div');
      reactionBar.className = 'reaction-bar absolute right-0 top-0 bg-gray-800 rounded p-1 opacity-0 transition-opacity';
      reactionBar.innerHTML = `
        <button class="reaction-btn" data-emoji="👍">👍</button>
        <button class="reaction-btn" data-emoji="❤️">❤️</button>
        <button class="reaction-btn" data-emoji="😄">😄</button>
        <button class="reaction-btn" data-emoji="😮">😮</button>
      `;
      messageEl.style.position = 'relative';
      messageEl.appendChild(reactionBar);
      
      // Add click handlers
      reactionBar.querySelectorAll('.reaction-btn').forEach((btn: Element) => {
        btn.addEventListener('click', (e: Event) => {
          const target = e.target as HTMLElement;
          const emoji = target.dataset.emoji;
          if (emoji) {
            this.addReaction(messageEl, emoji);
          }
        });
      });
    }
    
    reactionBar.style.opacity = '1';
  },

  hideReactionButtons(messageEl: HTMLElement): void {
    const reactionBar = messageEl.querySelector('.reaction-bar') as HTMLElement;
    if (reactionBar) {
      reactionBar.style.opacity = '0';
    }
  },

  addReaction(messageEl: HTMLElement, emoji: string): void {
    // This would normally send to the server
    console.log('Adding reaction:', emoji, 'to message');
    // You can extend this to send phx events for persistence
  }
} as MessageReactionsHook;

// Flash Notification Hook for smooth animations
const FlashNotification: FlashNotificationHook = {
  mounted() {
    // Auto-hide after 4 seconds
    this.hideTimer = window.setTimeout(() => {
      this.hide();
    }, 4000);
  },

  destroyed() {
    if (this.hideTimer) {
      clearTimeout(this.hideTimer);
    }
  },

  hide(): void {
    this.el.style.transform = 'translateX(100%)';
    this.el.style.opacity = '0';
    
    // Remove element after animation
    setTimeout(() => {
      if (this.el.parentNode) {
        this.el.parentNode.removeChild(this.el);
      }
    }, 300);
  }
} as FlashNotificationHook;

// Clean hooks object with quest game, CMS components, file management, and Babylon.js
const Hooks = {
  QuestGame,
  MessageReactions,
  RichEditor,
  FileDragDrop,
  FileUpload,
  BlogAutosave,
  BabylonScene,
  OpenWorldLobbyScene: OpenWorldLobbySceneHook,
  HomeGalaxyScene,
  FlashNotification,
  HCaptcha,
  FormHandler,
  FormPreserver,
  TerminalTypewriter
};

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// ---- LiveSocket instrumentation ----
if (!window.__liveSocketInstr) {
  window.__liveSocketInstr = { connects: 0, disconnects: 0, errors: 0 };
}

const originalConnect = liveSocket.connect.bind(liveSocket);
liveSocket.connect = function() {
  console.log('[LiveSocket] connect() invoked');
  return originalConnect();
};

liveSocket.socket.onOpen(() => {
  if (window.__liveSocketInstr) {
    window.__liveSocketInstr.connects += 1;
    console.log(`[LiveSocket] OPEN (total: ${window.__liveSocketInstr.connects})`);
  }
});

liveSocket.socket.onClose((ev: CloseEvent) => {
  if (window.__liveSocketInstr) {
    window.__liveSocketInstr.disconnects += 1;
    // Only log concerning close codes (not normal navigation)
    if (ev && ev.code !== 1001 && ev.code !== 1000) {
      console.warn('[LiveSocket] CLOSE', ev.code, 'total:', window.__liveSocketInstr.disconnects);
    } else if (window.__liveSocketInstr.disconnects > 3) {
      // Log if there are many disconnections (potential issue)
      console.warn('[LiveSocket] Multiple disconnections detected', ev && ev.code, 'total:', window.__liveSocketInstr.disconnects);
    }
  }
});

liveSocket.socket.onError((err: Event) => {
  if (window.__liveSocketInstr) {
    window.__liveSocketInstr.errors += 1;
    console.error('[LiveSocket] ERROR', err, 'total:', window.__liveSocketInstr.errors);
  }
});

// ---------------------------
// Connect LiveSocket
// ---------------------------
liveSocket.connect();
(window as any).liveSocket = liveSocket;

// ---------------------------
// Topbar
// ---------------------------
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info: Event) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info: Event) => topbar.hide());

// ---------------------------
// Stripe integration
// ---------------------------
window.addEventListener("phx:stripe-checkout", (e: Event) => {
  const event = e as CustomEvent<StripeEvent['detail']>;
  if (window.Stripe) {
    const stripe = window.Stripe(event.detail.public_key);
    stripe.redirectToCheckout({ sessionId: event.detail.session_id });
  }
});

// ---------------------------
// File download handler
// ---------------------------
window.addEventListener("phx:download-file", (e: Event) => {
  const event = e as CustomEvent<DownloadFileEvent['detail']>;
  const link = document.createElement("a");
  link.href = event.detail.url;
  link.download = event.detail.filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
});

// ---------------------------
// Notifications
// ---------------------------
window.addEventListener("phx:notification", (e: Event) => {
  const event = e as CustomEvent<NotificationEvent['detail']>;
  if (Notification.permission === "granted") {
    new Notification(event.detail.title, {
      body: event.detail.body,
      icon: "/favicon.ico"
    });
  }
});

if ("Notification" in window && Notification.permission === "default") {
  Notification.requestPermission();
}

// ---------------------------
// Babylon.js Test Events
// ---------------------------
window.addEventListener("phx:run_babylon_test", (e: Event) => {
  if (window.BabylonTest) {
    console.log("Running Babylon.js test...");
    const results = window.BabylonTest.runCapabilityTest();
    window.BabylonTest.displayResults(results);
  } else {
    console.error("BabylonTest not available");
  }
});

window.addEventListener("phx:create_test_scene", (e: Event) => {
  if (window.BabylonTest) {
    console.log("Creating Babylon.js test scene...");
    const container = document.getElementById('babylon-test-scene');
    if (container) {
      try {
        const testScene = window.BabylonTest.createTestScene(container);
        console.log("Test scene created successfully:", testScene);
      } catch (error) {
        console.error("Failed to create test scene:", error);
      }
    }
  } else {
    console.error("BabylonTest not available");
  }
});

window.addEventListener("phx:debug_scene", (e: Event) => {
  // Find the babylon scene hook and log debug info
  const babylonScene = document.getElementById('babylon-test-scene') as any;
  if (babylonScene && babylonScene._babylonHook) {
    const hook = babylonScene._babylonHook;
    console.log('=== BABYLON SCENE DEBUG ===');
    console.log('Scene exists:', !!hook.scene);
    console.log('Engine exists:', !!hook.engine);
    console.log('Canvas exists:', !!hook.canvas);
    if (hook.scene) {
      console.log('Meshes count:', hook.scene.meshes.length);
      console.log('Meshes:', hook.scene.meshes.map((m: any) => m.name));
      console.log('Camera position:', hook.camera.position);
      console.log('Camera target:', hook.camera.target);
    }
    console.log('========================');
  } else {
    console.log('Babylon scene hook not found');
  }
});

window.addEventListener("phx:toggle_fullscreen", (e: Event) => {
  const fullscreenOverlay = document.getElementById('babylon-fullscreen-overlay') as HTMLElement;
  const babylonScene = document.getElementById('babylon-test-scene') as HTMLElement & {
    _originalParent?: Node;
    _originalStyles?: Record<string, string>;
  };
  
  if (!fullscreenOverlay || !babylonScene) return;
  
  const originalParent = babylonScene.parentNode;

  if (fullscreenOverlay.style.display === 'none' || !fullscreenOverlay.style.display) {
    // Enter fullscreen
    fullscreenOverlay.style.display = 'block';
    document.body.style.overflow = 'hidden';

    // Move the babylon scene to fullscreen
    babylonScene.style.position = 'fixed';
    babylonScene.style.top = '0';
    babylonScene.style.left = '0';
    babylonScene.style.width = '100vw';
    babylonScene.style.height = '100vh';
    babylonScene.style.zIndex = '999';
    babylonScene.style.borderRadius = '0';

    // Store original parent for restoration
    babylonScene._originalParent = originalParent || undefined;
    babylonScene._originalStyles = {
      position: babylonScene.style.position,
      top: babylonScene.style.top,
      left: babylonScene.style.left,
      width: babylonScene.style.width,
      height: babylonScene.style.height,
      zIndex: babylonScene.style.zIndex,
      borderRadius: babylonScene.style.borderRadius
    };

    // Add ESC key listener
    const escHandler = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        exitFullscreen();
        document.removeEventListener('keydown', escHandler);
      }
    };
    document.addEventListener('keydown', escHandler);

  } else {
    exitFullscreen();
  }

  function exitFullscreen(): void {
    // Exit fullscreen
    fullscreenOverlay.style.display = 'none';
    document.body.style.overflow = '';

    // Restore babylon scene to original position
    if (babylonScene._originalStyles) {
      Object.assign(babylonScene.style, babylonScene._originalStyles);
      babylonScene._originalStyles = undefined;
      babylonScene._originalParent = undefined;
    }
  }
});

// ---------------------------
// DOM enhancements
// ---------------------------
document.addEventListener("DOMContentLoaded", function () {
  // Smooth scrolling
  document.querySelectorAll('a[href^="#"]').forEach((anchor: Element) => {
    anchor.addEventListener("click", (e: Event) => {
      e.preventDefault();
      const href = (anchor as HTMLAnchorElement).getAttribute("href");
      if (href) {
        const target = document.querySelector(href);
        target?.scrollIntoView({ behavior: "smooth" });
      }
    });
  });

  // Button hover effect
  document.querySelectorAll("button, .btn").forEach((button: Element) => {
    const buttonEl = button as HTMLElement;
    buttonEl.addEventListener("mouseenter", () => buttonEl.style.transform = "translateY(-2px)");
    buttonEl.addEventListener("mouseleave", () => buttonEl.style.transform = "translateY(0)");
  });
});