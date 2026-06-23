import * as THREE from 'three';
import { CharacterModelManager } from '../characters/model-manager';
import CharacterController from '../controls/character-controller';

type CharacterCard = {
  id: string;
  name: string;
  character_type: string;
};

type SceneState = {
  uiState: string;
  selectedCharacterId: string | null;
  canLogin: boolean;
  characters: CharacterCard[];
  modelPaths: string[];
  availableModels: Array<{ label: string; model_path: string }>;
  onlineCharacters: Array<{ character_id: string; character_name: string; user_id: string; character_type?: string; model_path?: string; x?: number; y?: number; z?: number; heading?: number }>;
  currentPlayer: any;
};

type PanelData = {
  panelId: string;
  label: string;
  characterId?: string;
};

export const DesktopCharacterUIScene = {
  scene: null as THREE.Scene | null,
  camera: null as THREE.PerspectiveCamera | null,
  renderer: null as THREE.WebGLRenderer | null,
  raycaster: null as THREE.Raycaster | null,
  pointer: null as THREE.Vector2 | null,
  animationFrame: 0,
  panelMeshes: [] as THREE.Mesh[],
  panelTargets: [] as { mesh: THREE.Mesh; targetX: number; targetY: number; targetZ: number }[],
  ambientStars: null as THREE.Points | null,
  state: null as SceneState | null,
  characterManager: null as CharacterModelManager | null,
  controller: null as CharacterController | null,
  worldGroup: null as THREE.Group | null,
  movementAccumulator: 0,
  lastPositionPushMs: 0,
  lastSentLocalPosition: null as { x: number; y: number; z: number; heading: number } | null,
  remoteNetTargets: new Map<string, { x: number; y: number; z: number; heading: number; updatedAt: number }>(),
  remoteLastSeenMs: new Map<string, number>(),
  remoteStaleTimeoutMs: 30000,
  worldInitialized: false,
  remoteSyncInProgress: false,
  remoteSyncQueued: false,
  frameClock: new THREE.Clock(),
  nameplateLayer: null as HTMLDivElement | null,
  chatPanel: null as HTMLDivElement | null,
  chatInput: null as HTMLInputElement | null,
  chatOutsideClickHandler: null as ((event: MouseEvent) => void) | null,
  nameplateEls: new Map<string, HTMLDivElement>(),
  creatorOverlay: null as HTMLDivElement | null,

  mounted(this: any) {
    if (!this.el) return;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x000000);

    const width = this.el.clientWidth || window.innerWidth;
    const height = this.el.clientHeight || 480;

    this.camera = new THREE.PerspectiveCamera(60, width / height, 0.1, 1000);
    this.camera.position.set(0, 0.25, 11.5);
    this.camera.lookAt(0, 0, 0);

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    const isFirefox = typeof navigator !== 'undefined' && /firefox/i.test(navigator.userAgent || '');
    const maxPixelRatio = isFirefox ? 1.5 : 2;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, maxPixelRatio));
    this.renderer.setSize(width, height);
    this.renderer.domElement.className = 'w-full h-full rounded-xl border border-cyan-900/60 shadow-[0_0_40px_rgba(34,211,238,0.08)]';

    this.el.innerHTML = '';
    this.el.style.position = 'relative';
    this.el.appendChild(this.renderer.domElement);

    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.characterManager = new CharacterModelManager();
    this.characterManager.setActiveScene(this.scene);
    this.worldGroup = new THREE.Group();
    this.scene.add(this.worldGroup);

    this.setupLights();
    this.createAmbientStars();
    this.readState();
    this.syncSceneMode();

    this.handleResize = this.handleResize.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleWorldKeyDown = this.handleWorldKeyDown.bind(this);

    window.addEventListener('resize', this.handleResize);
    window.addEventListener('keydown', this.handleWorldKeyDown);
    this.renderer.domElement.addEventListener('click', this.handleClick);

    this.handleEvent('zone_presence_state', (payload: any) => {
      if (payload?.online_characters && this.state) {
        this.state.onlineCharacters = payload.online_characters;
      } else {
        this.readState();
      }

      if (this.state?.uiState === 'world' && this.state.currentPlayer) {
        void this.syncOtherPlayers();
      } else {
        this.syncSceneMode();
      }
    });

    this.handleEvent('zone_position_update', (payload: any) => {
      if (!payload?.character_id || !this.state?.currentPlayer) return;
      if (payload.character_id === this.state.currentPlayer.character_id) return;

      const now = performance.now();
      this.remoteLastSeenMs.set(payload.character_id, now);
      this.remoteNetTargets.set(payload.character_id, {
        x: payload.x || 0,
        y: payload.y || 0,
        z: payload.z || 0,
        heading: payload.heading || 0,
        updatedAt: now
      });

      if (this.state) {
        const idx = this.state.onlineCharacters.findIndex((c: any) => c.character_id === payload.character_id);
        const next = {
          character_id: payload.character_id,
          character_name: payload.character_name || 'Player',
          user_id: payload.user_id || '',
          character_type: payload.character_type,
          model_path: payload.model_path,
          x: payload.x || 0,
          y: payload.y || 0,
          z: payload.z || 0,
          heading: payload.heading || 0
        };

        if (idx >= 0) {
          this.state.onlineCharacters[idx] = { ...this.state.onlineCharacters[idx], ...next };
        } else {
          this.state.onlineCharacters.push(next);
        }
      }

      if (!this.characterManager?.getAllCharacters().has(payload.character_id) && this.state?.uiState === 'world' && this.characterManager) {
        const currentModelPath = this.state.currentPlayer?.model_path as string;
        void this.characterManager
          .createPlayerCharacterFromModelPath(
            payload.character_id,
            payload.character_name || 'Player',
            payload.character_type || 'AA',
            payload.model_path || currentModelPath,
            { x: payload.x || 0, y: payload.y || 0, z: payload.z || 0 },
            false
          )
          .catch(() => {
            // If creation races with presence sync, ignore and let the next sync resolve.
          });
      }
    });

    this.handleEvent('world_logged_out', () => {
      this.teardownWorldMode();
      this.resetSelectionCamera();
      this.worldInitialized = false;
      this.readState();

      if (this.state) {
        this.state.currentPlayer = null;
        this.state.onlineCharacters = [];
        this.state.uiState = 'selection';
      }

      this.syncSceneMode();
    });

    this.handleEvent('character_login_ready', (payload: any) => {
      this.readState();
      if (payload && this.state) {
        this.state.currentPlayer = payload;
        this.state.uiState = 'world';
      }
      this.syncSceneMode();
      this.flashLoginPanel();
    });

    this.handleEvent('world_position_corrected', (payload: any) => {
      if (!this.characterManager || !this.state?.currentPlayer?.character_id || !payload) return;

      this.characterManager.updateCharacterPosition(
        this.state.currentPlayer.character_id,
        { x: payload.x || 0, y: payload.y || 0, z: payload.z || 0 },
        { x: 0, y: payload.heading || 0, z: 0 }
      );

      if (this.state.currentPlayer?.position) {
        this.state.currentPlayer.position = {
          x: payload.x || 0,
          y: payload.y || 0,
          z: payload.z || 0,
          heading: payload.heading || 0
        };
      }
    });

    this.handleEvent('zone_chat_message', (payload: any) => {
      if (!payload || !payload.message) return;
      if (payload.character_id && payload.character_id === this.state?.currentPlayer?.character_id) return;
      this.appendChatMessage(payload.character_name || 'Player', payload.message);
    });

    this.animate();
  },

  updated(this: any) {
    // In world mode the DOM data-attributes are static; all live updates come via
    // push_event (zone_presence_state, character_login_ready, etc.).  Calling
    // readState + syncSceneMode here at 20 Hz causes the stutter.
    if (this.worldInitialized) return;
    this.readState();
    this.syncSceneMode();
  },

  destroyed(this: any) {
    if (this.positionHeartbeatInterval) {
      clearInterval(this.positionHeartbeatInterval);
      this.positionHeartbeatInterval = null;
    }
    cancelAnimationFrame(this.animationFrame);
    window.removeEventListener('resize', this.handleResize);
    window.removeEventListener('keydown', this.handleWorldKeyDown);
    if (this.renderer) {
      this.renderer.domElement.removeEventListener('click', this.handleClick);
      this.renderer.dispose();
    }
    this.controller?.dispose();
    this.characterManager?.dispose();
    this.clearPanels();
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.raycaster = null;
    this.pointer = null;
    this.characterManager = null;
    this.controller = null;
    this.worldGroup = null;
    this.removeWorldOverlayUI();
    this.nameplateEls.clear();
  },

  reconnected(this: any) {
    // Reset any stuck push lock — the same hook instance is reused across reconnects,
    // so a _pushPending=true left over from before the disconnect would block all sends.
    this._pushPending = false;
    if (this._pushPendingTimer) {
      clearTimeout(this._pushPendingTimer);
      this._pushPendingTimer = null;
    }
    // Re-sync other players in case presence state changed while offline.
    if (this.worldInitialized && this.state?.uiState === 'world') {
      void this.syncOtherPlayers();
    }
  },

  setupLights(this: any) {
    if (!this.scene) return;

    const ambient = new THREE.AmbientLight(0xffffff, 0.8);
    const key = new THREE.DirectionalLight(0x67e8f9, 0.8);
    key.position.set(6, 8, 10);

    const rim = new THREE.DirectionalLight(0xa855f7, 0.45);
    rim.position.set(-7, -3, 6);

    this.scene.add(ambient, key, rim);
  },

  createAmbientStars(this: any) {
    if (!this.scene) return;

    const starCount = 320;
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(starCount * 3);

    for (let index = 0; index < starCount; index += 1) {
      positions[index * 3] = (Math.random() - 0.5) * 54;
      positions[index * 3 + 1] = (Math.random() - 0.5) * 34;
      positions[index * 3 + 2] = (Math.random() - 0.5) * 38;
    }

    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const material = new THREE.PointsMaterial({ color: 0x7dd3fc, size: 0.1, transparent: true, opacity: 0.78 });
    this.ambientStars = new THREE.Points(geometry, material);
    this.scene.add(this.ambientStars);
  },

  readState(this: any) {
    const uiState = this.el.dataset.uiState || 'intro';
    const selectedCharacterId = this.el.dataset.selectedCharacterId || null;
    const canLogin = this.el.dataset.canLogin === 'true';

    let characters: CharacterCard[] = [];
    let modelPaths: string[] = [];
    let onlineCharacters: Array<{ character_id: string; character_name: string; user_id: string; character_type?: string; model_path?: string; x?: number; y?: number; z?: number; heading?: number }> = [];
    let currentPlayer: any = null;
    try {
      characters = JSON.parse(this.el.dataset.characters || '[]');
    } catch (_err) {
      characters = [];
    }

    try {
      modelPaths = JSON.parse(this.el.dataset.modelPaths || '[]');
    } catch (_err) {
      modelPaths = [];
    }

    let availableModels: Array<{ label: string; model_path: string }> = [];
    try {
      availableModels = JSON.parse(this.el.dataset.availableModels || '[]');
    } catch (_err) {
      availableModels = [];
    }

    try {
      onlineCharacters = JSON.parse(this.el.dataset.onlineCharacters || '[]');
    } catch (_err) {
      onlineCharacters = [];
    }

    try {
      currentPlayer = JSON.parse(this.el.dataset.currentPlayer || 'null');
    } catch (_err) {
      currentPlayer = null;
    }

    const resolvedUiState = currentPlayer ? 'world' : uiState;
    this.state = { uiState: resolvedUiState, selectedCharacterId, canLogin, characters, modelPaths, availableModels, onlineCharacters, currentPlayer };
  },

  syncSceneMode(this: any) {
    if (this.state?.uiState === 'world' && this.state.currentPlayer) {
      this.clearPanels();

      if (!this.worldInitialized) {
        void this.initializeWorldMode();
      } else {
        void this.syncOtherPlayers();
      }

      return;
    }

    this.teardownWorldMode();
    this.resetSelectionCamera();
    this.buildPanelsFromState();
  },

  async initializeWorldMode(this: any) {
    if (!this.scene || !this.camera || !this.state?.currentPlayer || !this.characterManager || !this.worldGroup) return;

    if (this.worldGroup.children.length === 0) {
      const ground = new THREE.Mesh(
        new THREE.PlaneGeometry(180, 180),
        new THREE.MeshStandardMaterial({ color: 0x101820, roughness: 0.9, metalness: 0.08 })
      );
      ground.rotation.x = -Math.PI / 2;
      ground.receiveShadow = true;
      this.worldGroup.add(ground);

      const grid = new THREE.GridHelper(180, 40, 0x2dd4bf, 0x1f2937);
      this.worldGroup.add(grid);
    }

    this.createWorldOverlayUI();

    const currentPlayer = this.state.currentPlayer;
    const localExists = this.characterManager.getAllCharacters().has(currentPlayer.character_id);
    if (!localExists) {
      await this.characterManager.createPlayerCharacterFromModelPath(
        currentPlayer.character_id,
        currentPlayer.name,
        currentPlayer.character_type,
        currentPlayer.model_path,
        {
          x: currentPlayer.position.x,
          y: currentPlayer.position.y,
          z: currentPlayer.position.z
        },
        true
      );
    }

    const localCharacter = this.characterManager.getAllCharacters().get(currentPlayer.character_id);
    if (localCharacter && !this.controller) {
      this.ensureLocalMarker(localCharacter.mesh);
      this.controller = new CharacterController(localCharacter.mesh, this.camera, {
        moveSpeed: 4.5,
        runSpeed: 8.0,
        cameraDistance: 9,
        cameraHeight: 3,
        cameraSmoothing: 0.12,
        flyMode: false
      });
      this.controller.setPositionCallback((x: number, y: number, z: number, rotation: number) => {
        this.sendLocalPosition(x, y, z, rotation);
      });
    }

    this.worldInitialized = true;

    // Fallback heartbeat so position keeps sending even when tab is backgrounded
    // (requestAnimationFrame throttles to ~1fps in background tabs)
    this.positionHeartbeatInterval = setInterval(() => {
      if (!this.worldInitialized || !this.el?.isConnected) {
        clearInterval(this.positionHeartbeatInterval);
        this.positionHeartbeatInterval = null;
        return;
      }
      const currentId = this.state?.currentPlayer?.character_id;
      const localCharacter = currentId ? this.characterManager?.getAllCharacters().get(currentId) : null;
      if (localCharacter) {
        this.sendLocalPosition(
          localCharacter.mesh.position.x,
          localCharacter.mesh.position.y,
          localCharacter.mesh.position.z,
          localCharacter.mesh.rotation.y,
          true
        );
      }
    }, 500);

    await this.syncOtherPlayers();
  },

  async syncOtherPlayers(this: any) {
    if (!this.state?.currentPlayer || !this.characterManager) return;

    if (this.remoteSyncInProgress) {
      this.remoteSyncQueued = true;
      return;
    }

    this.remoteSyncInProgress = true;

    try {
      const now = performance.now();
      const currentId = this.state.currentPlayer.character_id;
      const onlineIds = new Set<string>();

      for (const online of this.state.onlineCharacters) {
        if (!online.character_id || online.character_id === currentId) continue;
        onlineIds.add(online.character_id);
        this.remoteLastSeenMs.set(online.character_id, now);

        if (!this.characterManager.getAllCharacters().has(online.character_id)) {
          await this.characterManager.createPlayerCharacterFromModelPath(
            online.character_id,
            online.character_name || 'Player',
            online.character_type || 'AA',
            online.model_path || (this.state.currentPlayer.model_path as string),
            { x: online.x || 0, y: online.y || 0, z: online.z || 0 },
            false
          );
          this.remoteNetTargets.set(online.character_id, {
            x: online.x || 0,
            y: online.y || 0,
            z: online.z || 0,
            heading: online.heading || 0,
            updatedAt: performance.now()
          });
        } else {
          const existingTarget = this.remoteNetTargets.get(online.character_id);
          const onlineX = online.x || 0;
          const onlineY = online.y || 0;
          const onlineZ = online.z || 0;
          const onlineHeading = online.heading || 0;

          if (!existingTarget) {
            this.remoteNetTargets.set(online.character_id, {
              x: onlineX,
              y: onlineY,
              z: onlineZ,
              heading: onlineHeading,
              updatedAt: performance.now()
            });
          } else {
            const dx = onlineX - existingTarget.x;
            const dy = onlineY - existingTarget.y;
            const dz = onlineZ - existingTarget.z;
            const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
            const staleTarget = now - existingTarget.updatedAt > 500;

            // Fallback path: keep remote movement alive from presence snapshots if
            // realtime zone_position_update packets are delayed or missing.
            if (distance > 0.05 || staleTarget) {
              this.remoteNetTargets.set(online.character_id, {
                x: onlineX,
                y: onlineY,
                z: onlineZ,
                heading: onlineHeading,
                updatedAt: performance.now()
              });
            }
          }
        }
      }

      this.characterManager.getAllCharacters().forEach((_character, id) => {
        if (id !== currentId && !onlineIds.has(id)) {
          const lastSeen = this.remoteLastSeenMs.get(id) || 0;
          const lastTargetUpdate = this.remoteNetTargets.get(id)?.updatedAt || 0;
          if (now - lastSeen >= this.remoteStaleTimeoutMs && now - lastTargetUpdate >= this.remoteStaleTimeoutMs) {
            this.characterManager?.removeCharacter(id);
            this.remoteNetTargets.delete(id);
            this.remoteLastSeenMs.delete(id);
          }
        }
      });
    } finally {
      this.remoteSyncInProgress = false;
      if (this.remoteSyncQueued) {
        this.remoteSyncQueued = false;
        void this.syncOtherPlayers();
      }
    }
  },

  applyRemoteSmoothing(this: any, deltaSeconds: number) {
    if (!this.characterManager || !this.state?.currentPlayer) return;

    const currentId = this.state.currentPlayer.character_id;
    const snapDistance = 15.0;
    const baseAlpha = Math.min(1, deltaSeconds * 12);

    this.remoteNetTargets.forEach((target: any, id: string) => {
      if (id === currentId) return;
      const character = this.characterManager.getAllCharacters().get(id);
      if (!character) {
        return;
      }

      const currentPos = character.mesh.position;
      const dx = target.x - currentPos.x;
      const dy = target.y - currentPos.y;
      const dz = target.z - currentPos.z;
      const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);

      if (distance > snapDistance) {
        currentPos.set(target.x, target.y, target.z);
      } else {
        currentPos.x += dx * baseAlpha;
        currentPos.y += dy * baseAlpha;
        currentPos.z += dz * baseAlpha;
      }

      const currentHeading = character.mesh.rotation.y;
      const headingDiff = this.shortestAngleDiff(currentHeading, target.heading || 0);
      character.mesh.rotation.y = currentHeading + headingDiff * Math.min(1, deltaSeconds * 14);

      character.position.set(currentPos.x, currentPos.y, currentPos.z);
      character.rotation.set(0, character.mesh.rotation.y, 0);

      const isMoving = distance > 0.06;
      const isRunning = distance > 0.28;
      this.characterManager.updateCharacterMotionState(id, { isMoving, isRunning, isJumping: false });
    });
  },

  syncCharacterAnimations(this: any) {
    if (!this.characterManager || !this.state?.currentPlayer) return;

    const currentId = this.state.currentPlayer.character_id;
    const movementState = this.controller?.getMovementState?.();

    this.characterManager.updateCharacterMotionState(currentId, {
      isMoving: !!movementState?.isMoving,
      isRunning: !!movementState?.isRunning,
      isJumping: movementState ? !movementState.isGrounded : false
    });
  },

  shortestAngleDiff(this: any, from: number, to: number): number {
    let diff = to - from;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    return diff;
  },

  teardownWorldMode(this: any) {
    if (this.positionHeartbeatInterval) {
      clearInterval(this.positionHeartbeatInterval);
      this.positionHeartbeatInterval = null;
    }
    if (this._pushPendingTimer) {
      clearTimeout(this._pushPendingTimer);
      this._pushPendingTimer = null;
    }
    this.controller?.dispose();
    this.controller = null;
    this.movementAccumulator = 0;
    this.lastPositionPushMs = 0;
    this.lastSentLocalPosition = null;
    this._pushPending = false;
    this.remoteNetTargets.clear();
    this.remoteLastSeenMs.clear();
    this.worldInitialized = false;
    this.remoteSyncInProgress = false;
    this.remoteSyncQueued = false;

    if (this.characterManager) {
      this.characterManager.dispose();
      this.characterManager = new CharacterModelManager();
      this.characterManager.setActiveScene(this.scene);
    }

    if (this.worldGroup) {
      this.worldGroup.clear();
    }

    this.removeWorldOverlayUI();
    this.nameplateEls.clear();
  },

  createWorldOverlayUI(this: any) {
    if (!this.el || this.nameplateLayer) return;

    const layer = document.createElement('div');
    layer.className = 'absolute inset-0 pointer-events-none';

    const chatPanel = document.createElement('div');
    chatPanel.className = 'absolute left-3 bottom-3 w-[340px] max-w-[92%] rounded border border-cyan-900/60 bg-black/70 text-cyan-100 p-2 pointer-events-auto';

    const log = document.createElement('div');
    log.className = 'text-xs h-24 overflow-y-auto space-y-1 pr-1';
    log.setAttribute('data-chat-log', 'true');

    const form = document.createElement('form');
    form.className = 'mt-2 flex gap-2';

    const worldControls = document.createElement('div');
    worldControls.className = 'mb-2 flex items-center justify-between gap-2';

    const worldTitle = document.createElement('div');
    worldTitle.className = 'text-[11px] uppercase tracking-wide text-cyan-200/90';
    worldTitle.textContent = 'World Chat';

    const logoutButton = document.createElement('button');
    logoutButton.type = 'button';
    logoutButton.className = 'rounded bg-rose-700 hover:bg-rose-600 px-2 py-1 text-[11px] text-white';
    logoutButton.textContent = 'Logout';
    logoutButton.addEventListener('click', () => {
      (this.pushEvent('logout_character', {}) as any)?.catch?.(() => {});
    });

    const input = document.createElement('input');
    input.type = 'text';
    input.maxLength = 220;
    input.placeholder = 'Proximity chat (nearby players only)';
    input.className = 'flex-1 rounded bg-slate-900/80 border border-cyan-900/60 px-2 py-1 text-xs text-cyan-50 outline-none';

    const button = document.createElement('button');
    button.type = 'submit';
    button.className = 'rounded bg-cyan-700 hover:bg-cyan-600 px-2 py-1 text-xs text-white';
    button.textContent = 'Send';

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const message = input.value.trim();
      if (!message) return;
      (this.pushEvent('world_chat_message', { message }) as any)?.catch?.(() => {});
      this.appendChatMessage('You', message);
      input.value = '';
    });

    form.appendChild(input);
    form.appendChild(button);
    worldControls.appendChild(worldTitle);
    worldControls.appendChild(logoutButton);
    chatPanel.appendChild(worldControls);
    chatPanel.appendChild(log);
    chatPanel.appendChild(form);
    layer.appendChild(chatPanel);
    this.el.appendChild(layer);

    this.nameplateLayer = layer;
    this.chatPanel = chatPanel;
    this.chatInput = input;

    this.chatOutsideClickHandler = (event: MouseEvent) => {
      const target = event.target as Node | null;
      if (!target) return;
      if (this.chatPanel && this.chatPanel.contains(target)) return;
      if (document.activeElement === this.chatInput) {
        this.chatInput?.blur();
      }
    };

    this.renderer?.domElement.addEventListener('pointerdown', this.chatOutsideClickHandler, true);
  },

  removeWorldOverlayUI(this: any) {
    if (this.nameplateLayer && this.nameplateLayer.parentElement) {
      this.nameplateLayer.parentElement.removeChild(this.nameplateLayer);
    }
    this.nameplateLayer = null;
    this.chatPanel = null;
    this.chatInput = null;

    if (this.chatOutsideClickHandler) {
      this.renderer?.domElement.removeEventListener('pointerdown', this.chatOutsideClickHandler, true);
      this.chatOutsideClickHandler = null;
    }
  },

  appendChatMessage(this: any, sender: string, message: string) {
    if (!this.chatPanel) return;
    const log = this.chatPanel.querySelector('[data-chat-log="true"]') as HTMLDivElement | null;
    if (!log) return;

    const entry = document.createElement('div');
    entry.className = 'leading-tight';
    entry.textContent = `${sender}: ${message}`;
    log.appendChild(entry);
    log.scrollTop = log.scrollHeight;

    while (log.childElementCount > 16) {
      log.removeChild(log.firstElementChild as Node);
    }
  },

  handleWorldKeyDown(this: any, event: KeyboardEvent) {
    if (this.state?.uiState !== 'world') return;

    const target = event.target as HTMLElement | null;
    const isTyping = target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);

    // Prevent movement keys from reaching the CharacterController while typing
    if (isTyping) {
      if (event.key === 'Escape') {
        (target as HTMLElement).blur();
        event.preventDefault();
        event.stopImmediatePropagation();
        return;
      }

      const movementKeys = ['KeyW', 'KeyA', 'KeyS', 'KeyD', 'Space', 'ShiftLeft', 'KeyC'];
      if (movementKeys.includes(event.code)) {
        event.stopImmediatePropagation();
      }
      return;
    }

    if (event.key !== 'Enter') return;
    if (!this.chatInput) return;
    event.preventDefault();
    this.chatInput.focus();
  },

  updateNameplates(this: any) {
    if (!this.camera || !this.renderer || !this.characterManager || !this.nameplateLayer) return;

    const characters = this.characterManager.getAllCharacters();
    const seen = new Set<string>();
    const rect = this.renderer.domElement.getBoundingClientRect();

    characters.forEach((character: any, id: string) => {
      seen.add(id);

      let label = this.nameplateEls.get(id);
      if (!label) {
        label = document.createElement('div');
        label.className = 'absolute -translate-x-1/2 -translate-y-1/2 px-2.5 py-1 rounded bg-black/85 border border-cyan-400/80 text-xs font-semibold text-cyan-100 whitespace-nowrap shadow-[0_0_12px_rgba(34,211,238,0.45)]';
        this.nameplateLayer?.appendChild(label);
        this.nameplateEls.set(id, label);
      }

      label.textContent = character.isLocalPlayer ? `${character.name} (You)` : character.name;

      const worldPos = character.mesh.position.clone();
      worldPos.y += 2.8;
      worldPos.project(this.camera);

      const x = ((worldPos.x + 1) / 2) * rect.width;
      const y = ((-worldPos.y + 1) / 2) * rect.height;
      const visible = worldPos.z < 1;

      label.style.display = visible ? 'block' : 'none';
      if (visible) {
        label.style.left = `${x}px`;
        label.style.top = `${y}px`;
      }
    });

    this.nameplateEls.forEach((el: HTMLDivElement, id: string) => {
      if (!seen.has(id)) {
        if (el.parentElement) el.parentElement.removeChild(el);
        this.nameplateEls.delete(id);
      }
    });
  },

  ensureLocalMarker(this: any, mesh: THREE.Object3D) {
    if ((mesh as any).userData?.localMarkerAttached) return;

    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.55, 0.8, 28),
      new THREE.MeshBasicMaterial({ color: 0x22d3ee, transparent: true, opacity: 0.9, side: THREE.DoubleSide })
    );
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    mesh.add(ring);

    const beacon = new THREE.Mesh(
      new THREE.SphereGeometry(0.14, 14, 14),
      new THREE.MeshBasicMaterial({ color: 0x34d399, transparent: true, opacity: 0.95 })
    );
    beacon.position.set(0, 2.6, 0);
    mesh.add(beacon);

    (mesh as any).userData = { ...(mesh as any).userData, localMarkerAttached: true };
  },

  clearPanels(this: any) {
    if (!this.scene) return;

    this.panelMeshes.forEach((mesh: THREE.Mesh) => {
      this.scene?.remove(mesh);
      mesh.geometry.dispose();
      const material = mesh.material as THREE.MeshStandardMaterial;
      if (material.map) material.map.dispose();
      material.dispose();
    });

    this.panelMeshes = [];
    this.panelTargets = [];
  },

  buildPanelsFromState(this: any) {
    if (!this.scene || !this.state) return;

    if (this.state.uiState === 'world') return;

    this.clearPanels();

    const panels: PanelData[] = [];

    if (this.state.uiState === 'intro') {
      panels.push({ panelId: 'intro', label: 'Welcome. Create your first character.' });
      panels.push({ panelId: 'creator', label: 'Click to create from 3D panel' });
    } else {
      panels.push({ panelId: 'creator', label: 'Click to create another (max 16)' });

      this.state.characters.slice(0, 5).forEach((character) => {
        panels.push({
          panelId: `char-${character.id}`,
          label: `${character.name} [${character.character_type}]`,
          characterId: character.id
        });
      });

      panels.push({ panelId: 'login', label: this.state.canLogin ? 'Login is ready' : 'Select character to login' });

      if (this.state.selectedCharacterId) {
        panels.push({ panelId: 'delete', label: 'Delete selected character' });
      }

      if (this.state.onlineCharacters.length > 0) {
        panels.push({ panelId: 'presence', label: `${this.state.onlineCharacters.length} online in zone` });
      }
    }

    panels.forEach((panel, index) => {
      const mesh = this.createPanelMesh(panel);

      const columns = Math.min(3, panels.length);
      const row = Math.floor(index / columns);
      const column = index % columns;

      const spacingX = 4.9;
      const spacingY = 2.8;
      const targetX = (column - (columns - 1) / 2) * spacingX;
      const targetY = 2.6 - row * spacingY;
      const targetZ = 0;

      mesh.position.set(targetX + 10 + index * 0.3, targetY + 1.4, -8);
      mesh.userData = {
        panelId: panel.panelId,
        characterId: panel.characterId || null
      };

      this.panelMeshes.push(mesh);
      this.panelTargets.push({ mesh, targetX, targetY, targetZ });
      this.scene?.add(mesh);
    });
  },

  createPanelMesh(this: any, panel: PanelData): THREE.Mesh {
    const isSelectedCharacter = panel.characterId && panel.characterId === this.state?.selectedCharacterId;
    const isLoginPanel = panel.panelId === 'login';
    const isPresencePanel = panel.panelId === 'presence';
    const isDeletePanel = panel.panelId === 'delete';

    const geometry = new THREE.PlaneGeometry(4.2, 1.7, 1, 1);
    const texture = this.createLabelTexture(panel.label);
    const material = new THREE.MeshStandardMaterial({
      color: isSelectedCharacter ? 0x2563eb : isLoginPanel ? 0x10b981 : isDeletePanel ? 0xdc2626 : isPresencePanel ? 0x9333ea : 0x23364d,
      emissive: isSelectedCharacter ? 0x1d4ed8 : isLoginPanel ? 0x064e3b : isDeletePanel ? 0x7f1d1d : isPresencePanel ? 0x4c1d95 : 0x102033,
      emissiveIntensity: isSelectedCharacter ? 0.78 : 0.55,
      metalness: 0.12,
      roughness: 0.48,
      map: texture,
      transparent: true,
      opacity: 1
    });

    const mesh = new THREE.Mesh(geometry, material);
    mesh.scale.setScalar(isSelectedCharacter ? 1.06 : 1);
    return mesh;
  },

  createLabelTexture(this: any, text: string): THREE.CanvasTexture {
    const canvas = document.createElement('canvas');
    canvas.width = 1024;
    canvas.height = 384;

    const ctx = canvas.getContext('2d');
    if (!ctx) return new THREE.CanvasTexture(canvas);

    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, '#13263f');
    gradient.addColorStop(1, '#223a57');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = 'rgba(125, 211, 252, 0.95)';
    ctx.lineWidth = 12;
    ctx.strokeRect(8, 8, canvas.width - 16, canvas.height - 16);

    ctx.fillStyle = '#f8fafc';
    ctx.font = 'bold 72px "Trebuchet MS", "Verdana", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const lines = this.wrapText(ctx, text, 900);
    const startY = canvas.height / 2 - ((lines.length - 1) * 74) / 2;

    lines.forEach((line: string, index: number) => {
      ctx.fillText(line, canvas.width / 2, startY + index * 74);
    });

    const texture = new THREE.CanvasTexture(canvas);
    texture.needsUpdate = true;
    return texture;
  },

  wrapText(this: any, ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
    const words = text.split(' ');
    const lines: string[] = [];
    let current = '';

    words.forEach((word) => {
      const test = current ? `${current} ${word}` : word;
      if (ctx.measureText(test).width > maxWidth && current) {
        lines.push(current);
        current = word;
      } else {
        current = test;
      }
    });

    if (current) lines.push(current);
    return lines.slice(0, 3);
  },

  handleResize(this: any) {
    if (!this.renderer || !this.camera) return;
    const width = this.el.clientWidth || window.innerWidth;
    const height = this.el.clientHeight || 480;

    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  },

  sendLocalPosition(this: any, x: number, y: number, z: number, heading: number, force = false) {
    // Don't send if a previous push is still in-flight — prevents flooding long-poll
    if (this._pushPending) return;

    const now = performance.now();
    const prev = this.lastSentLocalPosition;

    const moved =
      !prev ||
      Math.abs(x - prev.x) > 0.01 ||
      Math.abs(y - prev.y) > 0.01 ||
      Math.abs(z - prev.z) > 0.01 ||
      Math.abs(this.shortestAngleDiff(prev.heading, heading)) > 0.015;

    const heartbeatDue = !prev || now - this.lastPositionPushMs >= 300;

    if (!force && now - this.lastPositionPushMs < 50) return;
    if (!force && !moved && !heartbeatDue) return;

    this.lastPositionPushMs = now;
    this.lastSentLocalPosition = { x, y, z, heading };
    this._pushPending = true;

    // Watchdog: auto-reset after 5 s in case the promise never resolves
    if (this._pushPendingTimer) clearTimeout(this._pushPendingTimer);
    this._pushPendingTimer = setTimeout(() => {
      this._pushPending = false;
      this._pushPendingTimer = null;
    }, 5000);

    const clearPending = () => {
      this._pushPending = false;
      if (this._pushPendingTimer) {
        clearTimeout(this._pushPendingTimer);
        this._pushPendingTimer = null;
      }
    };

    try {
      const p = this.pushEvent('world_position_update', { x, y, z, heading });
      if (p && typeof p.then === 'function') {
        p.then(clearPending, clearPending);
      } else {
        clearPending();
      }
    } catch (_e) {
      clearPending();
    }
  },

  resetSelectionCamera(this: any) {
    if (!this.camera) return;
    this.camera.position.set(0, 0.25, 11.5);
    this.camera.lookAt(0, 0, 0);
  },

  handleClick(this: any, event: MouseEvent) {
    if (!this.renderer || !this.camera || !this.raycaster || !this.pointer) return;
    const rect = this.renderer.domElement.getBoundingClientRect();

    this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    this.raycaster.setFromCamera(this.pointer, this.camera);
    const intersects = this.raycaster.intersectObjects(this.panelMeshes, false);

    if (intersects.length === 0) return;

    const first = intersects[0].object as THREE.Mesh;
    const { panelId, characterId } = first.userData || {};

    if (characterId) {
      (this.pushEvent('select_character', { character_id: characterId }) as any)?.catch?.(() => {});
      return;
    }

    if (panelId === 'login' && this.state?.canLogin) {
      (this.pushEvent('login_character', {}) as any)?.catch?.(() => {});
      return;
    }

    if (panelId === 'delete' && this.state?.selectedCharacterId) {
      const character = this.state.characters.find((c: CharacterCard) => c.id === this.state?.selectedCharacterId);
      const name = character?.name || 'this character';
      const confirmed = window.confirm(`Delete ${name}? This cannot be undone.`);
      if (confirmed) {
        (this.pushEvent('delete_character', { character_id: this.state.selectedCharacterId }) as any)?.catch?.(() => {});
      }
      return;
    }

    if (panelId === 'creator') {
      this.showCharacterCreator();
    }
  },

  showCharacterCreator(this: any) {
    if (this.creatorOverlay) return;

    const overlay = document.createElement('div');
    overlay.className = 'absolute inset-0 bg-black/75 flex items-center justify-center pointer-events-auto';
    overlay.style.zIndex = '20';

    const panel = document.createElement('div');
    panel.className = 'bg-slate-900 border border-cyan-700/60 rounded-2xl p-6 w-80 shadow-2xl text-cyan-50';

    // Block all keyboard events from leaving the panel (prevents model movement while typing)
    const stopProp = (e: Event) => e.stopImmediatePropagation();
    panel.addEventListener('keydown', stopProp, true);
    panel.addEventListener('keyup', stopProp, true);

    const titleEl = document.createElement('h2');
    titleEl.textContent = 'Create Character';
    titleEl.className = 'text-lg font-bold mb-4 text-cyan-200';

    const mkInput = (placeholder: string) => {
      const inp = document.createElement('input');
      inp.type = 'text';
      inp.placeholder = placeholder;
      inp.className = 'w-full rounded bg-slate-800 border border-cyan-900/60 px-3 py-2 text-sm text-cyan-50 outline-none focus:border-cyan-500 mb-3';
      return inp;
    };

    const nameInput = mkInput('Name (min 2 chars)');
    const typeInput = mkInput('Type / Class (min 2 chars)');

    const modelSelect = document.createElement('select');
    modelSelect.className = 'w-full rounded bg-slate-800 border border-cyan-900/60 px-3 py-2 text-sm text-cyan-50 outline-none focus:border-cyan-500 mb-4';

    const defaultOpt = document.createElement('option');
    defaultOpt.value = '';
    defaultOpt.textContent = '— Choose model —';
    modelSelect.appendChild(defaultOpt);

    const models: Array<{ label: string; model_path: string }> = this.state?.availableModels || [];
    models.forEach((model) => {
      const opt = document.createElement('option');
      opt.value = model.model_path;
      opt.textContent = model.label;
      modelSelect.appendChild(opt);
    });

    const btnRow = document.createElement('div');
    btnRow.className = 'flex gap-2 mt-1';

    const createBtn = document.createElement('button');
    createBtn.textContent = 'Create';
    createBtn.className = 'flex-1 rounded bg-cyan-700 hover:bg-cyan-600 py-2 text-sm font-semibold';

    const cancelBtn = document.createElement('button');
    cancelBtn.textContent = 'Cancel';
    cancelBtn.className = 'flex-1 rounded bg-slate-700 hover:bg-slate-600 py-2 text-sm';

    createBtn.addEventListener('click', () => {
      const name = nameInput.value.trim();
      const characterType = typeInput.value.trim();
      const modelPath = modelSelect.value;
      this.removeCharacterCreator();
      (this.pushEvent('three_ui_create_character', { name, character_type: characterType, model_path: modelPath }) as any)?.catch?.(() => {});
    });

    cancelBtn.addEventListener('click', () => this.removeCharacterCreator());

    btnRow.appendChild(createBtn);
    btnRow.appendChild(cancelBtn);
    panel.appendChild(titleEl);
    panel.appendChild(nameInput);
    panel.appendChild(typeInput);
    panel.appendChild(modelSelect);
    panel.appendChild(btnRow);
    overlay.appendChild(panel);
    this.el.appendChild(overlay);

    this.creatorOverlay = overlay;
    nameInput.focus();
  },

  removeCharacterCreator(this: any) {
    if (this.creatorOverlay?.parentElement) {
      this.creatorOverlay.parentElement.removeChild(this.creatorOverlay);
    }
    this.creatorOverlay = null;
  },

  flashLoginPanel(this: any) {
    if (this.state?.uiState === 'world') {
      return;
    }
    this.panelMeshes.forEach((mesh: THREE.Mesh) => {
      if (mesh.userData.panelId === 'login') {
        const material = mesh.material as THREE.MeshStandardMaterial;
        material.emissiveIntensity = 1.0;
        setTimeout(() => {
          material.emissiveIntensity = 0.35;
        }, 500);
      }
    });
  },

  animate(this: any) {
    if (!this.renderer || !this.scene || !this.camera) return;

    const deltaSeconds = Math.min(this.frameClock.getDelta(), 0.05);

    this.panelTargets.forEach(({ mesh, targetX, targetY, targetZ }) => {
      mesh.position.x += (targetX - mesh.position.x) * 0.08;
      mesh.position.y += (targetY - mesh.position.y) * 0.08;
      mesh.position.z += (targetZ - mesh.position.z) * 0.08;
      mesh.rotation.y += (0 - mesh.rotation.y) * 0.08;
      mesh.rotation.x += (0 - mesh.rotation.x) * 0.08;
    });

    if (this.ambientStars) {
      this.ambientStars.rotation.y += 0.0008;
    }

    if (this.state?.uiState === 'world') {
      this.controller?.update(deltaSeconds);

      const currentId = this.state?.currentPlayer?.character_id;
      const localCharacter = currentId ? this.characterManager?.getAllCharacters().get(currentId) : null;
      if (!localCharacter) {
        this._noCharFrames = (this._noCharFrames || 0) + 1;
      } else {
        this._noCharFrames = 0;
        this.sendLocalPosition(
          localCharacter.mesh.position.x,
          localCharacter.mesh.position.y,
          localCharacter.mesh.position.z,
          localCharacter.mesh.rotation.y
        );
      }

      this.applyRemoteSmoothing(deltaSeconds);
      this.syncCharacterAnimations();
      this.characterManager?.updateAnimations(deltaSeconds);
      this.updateNameplates();
    }

    this.renderer.render(this.scene, this.camera);
    this.animationFrame = requestAnimationFrame(() => this.animate());
  }
};
