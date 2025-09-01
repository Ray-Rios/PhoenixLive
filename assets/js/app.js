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

// Clean hooks object with quest game
let Hooks = {
  QuestGame
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
