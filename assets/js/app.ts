// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Topbar for progress indicators
import topbar from "./topbar";

// Phoenix LiveView
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// Import TypeScript hooks
import { TerminalTypewriter } from "./terminal_typewriter";
import { FormHandler } from "./form_handler";
import { FormPreserver } from "./form_preserver";
import { FileDragDrop, FileUpload } from "./file_drag_drop";

// Import Three.js hooks
import { ThreeJSScene, ThreeJSTestScene } from "./threejs/hooks";
import { HomeGalaxyScene } from "./threejs/galaxy-scene";
import { RichEditor } from "./rich_editor";
import { BlogAutosave } from "./blog_autosave_hook";
import { DeviceFingerprintHook } from "./device_fingerprint";
import "./quest_engine";

// CSRF token
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Quest Game Hook (simplified)
const QuestGame = {
  mounted() {
    console.log('Quest Game mounted');
  },
  updated() {
    console.log('Quest Game updated');
  },
  destroyed() {
    console.log('Quest Game destroyed');
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

// Flash Notification Hook (simplified)
const FlashNotification = {
  mounted(this: any) {
    console.log('Flash Notification mounted');
    // Auto-hide after 4 seconds
    setTimeout(() => {
      if (this.el && this.el.parentNode) {
        this.el.style.opacity = '0';
        setTimeout(() => {
          if (this.el && this.el.parentNode) {
            this.el.parentNode.removeChild(this.el);
          }
        }, 300);
      }
    }, 4000);
  },
  destroyed() {
    console.log('Flash Notification destroyed');
  }
};

// Hooks object - WITHOUT Three.js hooks (they'll be initialized manually)
const Hooks = {
  QuestGame,
  MessageReactions,
  RichEditor,
  FileDragDrop,
  FileUpload,
  BlogAutosave,
  FlashNotification,
  FormHandler,
  FormPreserver,
  TerminalTypewriter,
  DeviceFingerprint: DeviceFingerprintHook
};

// Connect LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// Expose liveSocket on window
(window as any).liveSocket = liveSocket

liveSocket.connect()

console.log('✅ Phoenix LiveView connected');

// Initialize Three.js scenes manually after Phoenix has mounted
// This avoids the race condition with Phoenix LiveView's DOM patching
window.addEventListener('phx:page-loading-stop', () => {
  initializeThreeJSScenes();
});

// Also initialize on initial page load
document.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => initializeThreeJSScenes(), 100);
});

function initializeThreeJSScenes() {
  // Initialize home galaxy scene
  const galaxyCanvas = document.getElementById('home-galaxy-canvas');
  if (galaxyCanvas && !galaxyCanvas.dataset.threeInitialized) {
    console.log('🌌 Initializing home galaxy scene');
    galaxyCanvas.dataset.threeInitialized = 'true';
    const hookInstance = Object.create(HomeGalaxyScene);
    hookInstance.el = galaxyCanvas;
    HomeGalaxyScene.mounted.call(hookInstance);
  }

  // Initialize lobby scene
  const lobbyCanvas = document.getElementById('world-builder-scene') as HTMLCanvasElement;
  if (lobbyCanvas && !lobbyCanvas.dataset.threeInitialized) {
    console.log('🎮 Initializing lobby Three.js scene');
    lobbyCanvas.dataset.threeInitialized = 'true';
    const hookInstance = Object.create(ThreeJSScene);
    hookInstance.el = lobbyCanvas;
    hookInstance.pushEvent = () => {};
    hookInstance.handleEvent = () => {};
    hookInstance.pushEventTo = () => {};
    ThreeJSScene.mounted.call(hookInstance);
  }

  // Initialize test scene
  const testScene = document.getElementById('threejs-scene') as HTMLCanvasElement;
  if (testScene && !testScene.dataset.threeInitialized) {
    console.log('🧪 Initializing test Three.js scene');
    testScene.dataset.threeInitialized = 'true';
    const hookInstance = Object.create(ThreeJSTestScene);
    hookInstance.el = testScene;
    hookInstance.pushEvent = () => {};
    hookInstance.handleEvent = () => {};
    hookInstance.pushEventTo = () => {};
    ThreeJSTestScene.mounted.call(hookInstance);
  }
}