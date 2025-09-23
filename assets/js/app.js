// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Topbar for progress indicators
import topbar from "../vendor/topbar";

// Phoenix LiveView
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// CSRF token
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

// ---------------------------
// Hooks
// ---------------------------

// Import quest engine
import "./quest_engine";

// Import rich editor components
import { RichEditor } from "./rich_editor";

// Import file drag-drop hooks
import { FileDragDrop, FileUpload } from "./file_drag_drop";

// Import Babylon.js hooks
import { BabylonScene } from "./babylon/babylon_hooks"
import { LobbyScene } from "./babylon/lobby_hooks";
import { HomeGalaxyScene } from "./babylon/home_galaxy_scene";

// Import terminal typewriter effect
import { TerminalTypewriter } from "./terminal_typewriter";

// Import CAPTCHA hook
import { HCaptcha } from "./hcaptcha";

// Import form handler to prevent CAPTCHA destruction
import { FormHandler } from "./form_handler";

// Import form preserver to maintain form data during LiveView updates
import { FormPreserver } from "./form_preserver";


// Quest Game Hook
const QuestGame = {
  mounted() {
    this.players = JSON.parse(this.el.dataset.players || '{}');
    this.currentPlayerId = this.el.dataset.currentPlayer;

    this.questEngine = new window.QuestEngine(this.el, this);
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
};

// Message Reactions Hook for chat functionality
const MessageReactions = {
  mounted() {
    this.setupMessageReactions();
  },

  updated() {
    this.setupMessageReactions();
  },

  setupMessageReactions() {
    // Add hover effects for message reactions
    this.el.querySelectorAll('.message').forEach(message => {
      if (!message.dataset.reactionsSetup) {
        message.addEventListener('mouseenter', () => {
          this.showReactionButtons(message);
        });
        
        message.addEventListener('mouseleave', () => {
          this.hideReactionButtons(message);
        });
        
        message.dataset.reactionsSetup = 'true';
      }
    });
  },

  showReactionButtons(messageEl) {
    // Add reaction buttons if they don't exist
    let reactionBar = messageEl.querySelector('.reaction-bar');
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
      reactionBar.querySelectorAll('.reaction-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const emoji = e.target.dataset.emoji;
          this.addReaction(messageEl, emoji);
        });
      });
    }
    
    reactionBar.style.opacity = '1';
  },

  hideReactionButtons(messageEl) {
    const reactionBar = messageEl.querySelector('.reaction-bar');
    if (reactionBar) {
      reactionBar.style.opacity = '0';
    }
  },

  addReaction(messageEl, emoji) {
    // This would normally send to the server
    console.log('Adding reaction:', emoji, 'to message');
    // You can extend this to send phx events for persistence
  }
};

// Flash Notification Hook for smooth animations
const FlashNotification = {
  mounted() {
    // Auto-hide after 4 seconds
    this.hideTimer = setTimeout(() => {
      this.hide();
    }, 4000);
  },

  destroyed() {
    if (this.hideTimer) {
      clearTimeout(this.hideTimer);
    }
  },

  hide() {
    this.el.style.transform = 'translateX(100%)';
    this.el.style.opacity = '0';
    
    // Remove element after animation
    setTimeout(() => {
      if (this.el.parentNode) {
        this.el.parentNode.removeChild(this.el);
      }
    }, 300);
  }
};

// Clean hooks object with quest game, CMS components, file management, and Babylon.js
let Hooks = {
  QuestGame,
  MessageReactions,
  RichEditor,
  FileDragDrop,
  FileUpload,
  BabylonScene,
  LobbyScene,
  HomeGalaxyScene,
  FlashNotification,
  HCaptcha,
  FormHandler,
  FormPreserver,
  TerminalTypewriter
};

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// ---------------------------
// Connect LiveSocket
// ---------------------------
liveSocket.connect();
window.liveSocket = liveSocket;

// ---------------------------
// Topbar
// ---------------------------
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// ---------------------------
// Stripe integration
// ---------------------------
window.addEventListener("phx:stripe-checkout", (e) => {
  const stripe = Stripe(e.detail.public_key);
  stripe.redirectToCheckout({ sessionId: e.detail.session_id });
});

// ---------------------------
// File download handler
// ---------------------------
window.addEventListener("phx:download-file", (e) => {
  const link = document.createElement("a");
  link.href = e.detail.url;
  link.download = e.detail.filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
});

// ---------------------------
// Notifications
// ---------------------------
window.addEventListener("phx:notification", (e) => {
  if (Notification.permission === "granted") {
    new Notification(e.detail.title, {
      body: e.detail.body,
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
window.addEventListener("phx:run_babylon_test", (e) => {
  if (window.BabylonTest) {
    console.log("Running Babylon.js test...");
    const results = window.BabylonTest.runCapabilityTest();
    window.BabylonTest.displayResults(results);
  } else {
    console.error("BabylonTest not available");
  }
});

window.addEventListener("phx:create_test_scene", (e) => {
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

window.addEventListener("phx:debug_scene", (e) => {
  // Find the babylon scene hook and log debug info
  const babylonScene = document.getElementById('babylon-test-scene');
  if (babylonScene && babylonScene._babylonHook) {
    const hook = babylonScene._babylonHook;
    console.log('=== BABYLON SCENE DEBUG ===');
    console.log('Scene exists:', !!hook.scene);
    console.log('Engine exists:', !!hook.engine);
    console.log('Canvas exists:', !!hook.canvas);
    if (hook.scene) {
      console.log('Meshes count:', hook.scene.meshes.length);
      console.log('Meshes:', hook.scene.meshes.map(m => m.name));
      console.log('Camera position:', hook.camera.position);
      console.log('Camera target:', hook.camera.target);
    }
    console.log('========================');
  } else {
    console.log('Babylon scene hook not found');
  }
});

window.addEventListener("phx:toggle_fullscreen", (e) => {
  const fullscreenOverlay = document.getElementById('babylon-fullscreen-overlay');
  const babylonScene = document.getElementById('babylon-test-scene');
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
    babylonScene._originalParent = originalParent;
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
    const escHandler = (event) => {
      if (event.key === 'Escape') {
        exitFullscreen();
        document.removeEventListener('keydown', escHandler);
      }
    };
    document.addEventListener('keydown', escHandler);

  } else {
    exitFullscreen();
  }

  function exitFullscreen() {
    // Exit fullscreen
    fullscreenOverlay.style.display = 'none';
    document.body.style.overflow = '';

    // Restore babylon scene to original position
    if (babylonScene._originalStyles) {
      Object.assign(babylonScene.style, babylonScene._originalStyles);
      babylonScene._originalStyles = null;
      babylonScene._originalParent = null;
    }
  }
});

// ---------------------------
// DOM enhancements
// ---------------------------
document.addEventListener("DOMContentLoaded", function () {
  // Smooth scrolling
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener("click", function (e) {
      e.preventDefault();
      document.querySelector(this.getAttribute("href")).scrollIntoView({ behavior: "smooth" });
    });
  });

  // Button hover effect
  document.querySelectorAll("button, .btn").forEach(button => {
    button.addEventListener("mouseenter", () => button.style.transform = "translateY(-2px)");
    button.addEventListener("mouseleave", () => button.style.transform = "translateY(0)");
  });
});
