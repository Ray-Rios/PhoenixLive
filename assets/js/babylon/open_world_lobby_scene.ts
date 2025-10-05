import { Engine, Scene, Vector3, Color3, Ray, ArcRotateCamera, HemisphericLight, DirectionalLight, MeshBuilder, StandardMaterial, ActionManager, initializeBabylonExports } from './babylon_imports';
import { MaterialLibrary, WorldBuilderTools } from './world-builder-tools';

export const OpenWorldLobbyScene = {
  mounted() {
    console.log('OpenWorldLobbyScene hook mounted');
    this.el._babylonHook = this;
    if (!window.__lobbyMetrics) { window.__lobbyMetrics = { mounts: 0, updates: 0 }; console.log('[LobbyMetrics] Initialized metrics'); }
    window.__lobbyMetrics.mounts += 1; console.log(`[LobbyMetrics] Mount #${window.__lobbyMetrics.mounts}`);
    this.keys = {}; this.moveSpeed = 5; this.isInWater = false; this.isJumping = false; this.jumpVelocity = 0;
    this.sceneConfig = JSON.parse(this.el.dataset.sceneConfig || '{}');
    this.userData = JSON.parse(this.el.dataset.user || '{}');
    this.initializeScene().then(()=>{ this.setupEventListeners(); console.log('OpenWorldLobbyScene ready'); }).catch(e=>console.error('Init failed:', e));
  },
  updated() {
    if (window.__lobbyMetrics) window.__lobbyMetrics.updates += 1;
    // Debug: log update reason and diff
    const prev = this._lastDataset || {};
    const curr = {...this.el.dataset};
    let changed = [];
    for (const k in curr) {
      if (curr[k] !== prev[k]) changed.push(`${k}: ${prev[k]} → ${curr[k]}`);
    }
    this._lastDataset = curr;
    console.log('[LobbyDebug] LiveView updated, dataset:', curr, 'Changed:', changed);
  },
  destroyed() { console.log('OpenWorldLobbyScene destroyed'); this.cleanup(); },
  async initializeScene() {
    console.log('Initializing scene...');
    
    // Initialize BABYLON exports before using them
    try {
      initializeBabylonExports();
    } catch (e) {
      console.error('Failed to initialize BABYLON:', e);
      return;
    }
    
    this.createChatUI();
    const canvas = this.el;
    // Ensure canvas takes full container size
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    // Wait for layout
    await new Promise(resolve => requestAnimationFrame(resolve));
    // Try to use parent container size if available
    const parent = canvas.parentElement;
    let w = window.innerWidth, h = window.innerHeight - 30;
    if (parent) {
      w = parent.offsetWidth || w;
      h = parent.offsetHeight || h;
    }
    canvas.width = w;
    canvas.height = h;
    console.log(`[LobbyDebug] Canvas size set to: ${canvas.width}x${canvas.height}`);
    this.engine = new Engine(canvas, true, { preserveDrawingBuffer: true, stencil: true, antialias: true });
    this.scene = new Scene(this.engine); this.scene.actionManager = new ActionManager(this.scene);
    this.engine.resize(); // Ensure initial size
    this.setupEnvironment();
    
    // Initialize World Builder System
    this.materialLibrary = new MaterialLibrary(this.scene);
    this.worldBuilderTools = new WorldBuilderTools(this.scene, this.materialLibrary);
    console.log('🏗️ World Builder tools initialized');
    
    await this.createWorld();
    await this.createPlayer();
    this.setupMovement();
    this.engine.runRenderLoop(()=>{ this.updateMovement(); this.scene.render(); if (this.engine.getRenderWidth()!==this.el.clientWidth||this.engine.getRenderHeight()!==this.el.clientHeight){ this.engine.resize(); }});
    window.addEventListener('resize', ()=> this.engine.resize());
    console.log('Scene initialized successfully');
  },
  setupEnvironment() {
    const hemi = new HemisphericLight('ambient', new Vector3(0,1,0), this.scene); hemi.intensity = 0.6;
    const sun = new DirectionalLight('sun', new Vector3(-1,-1,-0.5), this.scene); sun.intensity = 0.8; sun.diffuse = new Color3(1,0.9,0.8);
    this.scene.fogMode = Scene.FOGMODE_EXP2; this.scene.fogColor = new Color3(0.7,0.8,0.9); this.scene.fogDensity = 0.0002;
  },
  async createWorld() { 
    console.log('Creating infinite world builder...'); 
    try { 
      await this.createInfiniteWorld(); 
    } catch(e) { 
      console.warn('Infinite world failed; using fallback flat terrain', e); 
      this.createFallbackTerrain(); 
    } 
    this.createInfiniteWater(); 
  },
  async createInfiniteWorld() {
    // Create starting island - large flat circular area for building
    const islandRadius = 100;
    const islandSubdivisions = 64;
    
    // Create the starting island as a circular disc
    this.startingIsland = MeshBuilder.CreateDisc('startingIsland', {
      radius: islandRadius,
      subdivisions: islandSubdivisions
    }, this.scene);
    
    // Rotate to make it horizontal
    this.startingIsland.rotation.x = Math.PI / 2;
    this.startingIsland.position.y = 50; // Above water level
    
    // Material for the starting island
    const islandMat = new StandardMaterial('islandMaterial', this.scene);
    islandMat.diffuseColor = new Color3(0.6, 0.8, 0.4); // Grassy green
    this.startingIsland.material = islandMat;
    
    // Add collision detection for the island
    this.startingIsland.checkCollisions = true;
    
    console.log('✅ Starting island created');
    this.terrain = this.startingIsland; // For compatibility
  },
  createFallbackTerrain() { 
    // Fallback to flat terrain if infinite world fails
    this.terrain = MeshBuilder.CreateGround('fallbackTerrain', {
      width: 200, 
      height: 200, 
      subdivisions: 50
    }, this.scene); 
    this.terrain.position.y = 50;
    const mat = new StandardMaterial('fallbackTerrainMaterial', this.scene); 
    mat.diffuseColor = new Color3(0.3, 0.5, 0.3); 
    this.terrain.material = mat; 
  },
  createInfiniteWater() { 
    // Create massive water plane that extends to horizon
    const waterSize = 10000; // Very large water plane
    this.water = MeshBuilder.CreateGround('infiniteWater', {
      width: waterSize, 
      height: waterSize, 
      subdivisions: 8
    }, this.scene); 
    this.water.position.y = 45; // Below island level
    
    const waterMat = new StandardMaterial('infiniteWaterMaterial', this.scene); 
    waterMat.diffuseColor = new Color3(0.1, 0.3, 0.8); 
    waterMat.alpha = 0.8; 
    waterMat.backFaceCulling = false;
    this.water.material = waterMat; 
    
    // Animated water effect
    this.scene.registerBeforeRender(() => { 
      if (this.water) { 
        const t = Date.now() * 0.001; 
        this.water.position.y = 45 + Math.sin(t * 0.3) * 0.5; // Gentle waves
      } 
    }); 
    
    console.log('✅ Infinite water created');
  },
  async createPlayer() {
    try {
      await this.loadRandomCharacter();
    } catch (e) {
      console.warn('Random character load failed; fallback capsule', e);
      this.createFallbackPlayer();
    }
  },
  async loadRandomCharacter() { 
    // Import character management classes
    const { CharacterModelManager } = await import('./character_model_manager_new');
    const { createCharacterBehavior } = await import('./character_behavior_system');
    
    // Initialize character model manager
    this.characterModelManager = new CharacterModelManager(this.scene);
    
    // Get a random character configuration
    const characterConfig = this.characterModelManager.getRandomCharacterConfig();
    console.log(`🎲 Selected random character: ${characterConfig.name} (${characterConfig.type})`);
    
    // Load the character model
    const characterModel = await this.characterModelManager.loadCharacterModel(characterConfig.type);
    
    // Set up the player mesh
    this.player = characterModel.mesh;
    this.player.position = new Vector3(0, 55, 0); // Start on the island
    
    // Store character information
    this.characterModel = characterModel;
    this.characterConfig = characterConfig;
    
    // Create behavior system for this character
    this.characterBehavior = createCharacterBehavior(
      characterConfig.type, 
      characterConfig, 
      this.player, 
      this.scene
    );
    
    // Store animations
    this.playerAnimations = characterModel.animationGroups;
    if (this.playerAnimations.length) {
      console.log('Character animations:', this.playerAnimations.map(a => a.name));
    }
    
    // Set up camera
    this.setupCamera();
    
    // Add character-specific welcome message
    this.addCharacterWelcomeMessage();
    
    console.log(`✅ Random character loaded: ${characterConfig.name}`, {
      type: characterConfig.type,
      behaviors: characterConfig.behaviors,
      animations: this.playerAnimations.length
    });
  },
  addCharacterWelcomeMessage() {
    if (this.characterConfig && this.addChatMessage) {
      const charName = this.characterConfig.name;
      const charType = this.characterConfig.type;
      let controls = 'Use WASD to move';
      
      if (this.characterConfig.behaviors.canFly) {
        controls += ', F or Space to fly';
      } else if (this.characterConfig.behaviors.jumpHeight > 0) {
        controls += ', Space to jump';
      }
      
      if (this.characterConfig.behaviors.canSwim) {
        controls += ', swim in water';
      }
      
      controls += ', right-click to turn.';
      
      this.addChatMessage('SYSTEM', `🎯 You are a ${charName}! ${controls}`, '#ffff00');
      
      // Add character-specific tips
      if (charType === 'eagle') {
        this.addChatMessage('SYSTEM', '🦅 Eagle Tips: You can soar high above the world! Use your flying advantage.', '#87CEEB');
      } else if (charType === 'fox') {
        this.addChatMessage('SYSTEM', '🦊 Fox Tips: You are fast and agile! Sprint to outrun others.', '#FF4500');
      } else if (charType === 'hammerhead_shark') {
        this.addChatMessage('SYSTEM', '🦈 Shark Tips: Master of the ocean depths! Stay in the water for best mobility.', '#4682B4');
      }
    }
  },
  createFallbackPlayer() { this.player=MeshBuilder.CreateCapsule('player',{radius:1,height:3},this.scene); this.player.position=new Vector3(0,5,0); const pm=new StandardMaterial('playerMaterial',this.scene); pm.diffuseColor=new Color3(0.2,0.8,0.2); this.player.material=pm; this.setupCamera(); },
  setupCamera() {
    if(!this.player) return;
    this.camera = new ArcRotateCamera('playerCamera', 0, Math.PI/3, 15, this.player.position, this.scene);
    // Disable right mouse drag for camera
    this.camera.attachControl(this.el, true, {buttons: [0]});
    this.camera.lowerRadiusLimit = 2;
    this.camera.upperRadiusLimit = 100;
    this.camera.lowerBetaLimit = 0.1;
    this.camera.upperBetaLimit = Math.PI - 0.1;
    this.camera.wheelPrecision = 10;
    this.camera.lowerAlphaLimit = null;
    this.camera.upperAlphaLimit = null;

    // Custom right-click drag: rotate camera and character together
    let isRightDragging = false;
    let lastX = 0;
    this.el.addEventListener('mousedown', e => {
      if (e.button === 2) {
        isRightDragging = true;
        lastX = e.clientX;
      }
    });
    window.addEventListener('mousemove', e => {
      if (isRightDragging) {
        const dx = e.clientX - lastX;
        lastX = e.clientX;
        // Rotate camera alpha
        this.camera.alpha -= dx * 0.01;
        // Rotate character to match camera
        if (this.player) {
          const dir = this.camera.getTarget().subtract(this.camera.position).normalize();
          dir.y = 0; dir.normalize();
          this.player.rotation.y = Math.atan2(dir.x, dir.z);
        }
      }
    });
    window.addEventListener('mouseup', e => {
      if (e.button === 2) {
        isRightDragging = false;
      }
    });
  },
  setupMovement() { this.mouseMovement={leftMouseDown:false,rightMouseDown:false,isMovingForward:false,inRightClickMode:false,moveStartTime:0}; this.keyDownHandler=e=>{ const k=e.key.toLowerCase(); const chat=document.getElementById('chat-input'); const chatFocus=chat&&document.activeElement===chat; if(['w','a','s','d',' '].includes(k)&&!chatFocus){ e.preventDefault(); e.stopPropagation(); this.keys[k]=true; } }; this.keyUpHandler=e=>{ const k=e.key.toLowerCase(); const chat=document.getElementById('chat-input'); const chatFocus=chat&&document.activeElement===chat; if(['w','a','s','d',' '].includes(k)&&!chatFocus){ e.preventDefault(); e.stopPropagation(); this.keys[k]=false; } }; document.addEventListener('keydown',this.keyDownHandler,{capture:true}); document.addEventListener('keyup',this.keyUpHandler,{capture:true}); this.setupMouseControls(); },
  setupMouseControls() { this.el.addEventListener('contextmenu',e=>e.preventDefault()); this.el.addEventListener('mousedown',e=>{ if(e.button===0){ this.mouseMovement.leftMouseDown=true; this.checkForwardMovement(); } else if(e.button===2){ e.preventDefault(); this.mouseMovement.rightMouseDown=true; this.checkForwardMovement(); this.startRightClickMode(); } }); this.el.addEventListener('mouseup',e=>{ if(e.button===0){ this.mouseMovement.leftMouseDown=false; this.checkForwardMovement(); } else if(e.button===2){ this.mouseMovement.rightMouseDown=false; this.checkForwardMovement(); this.endRightClickMode(); } }); this.el.addEventListener('mouseleave',()=>{ this.mouseMovement.leftMouseDown=false; this.mouseMovement.rightMouseDown=false; this.mouseMovement.isMovingForward=false; this.endRightClickMode(); }); },
  startRightClickMode(){ if(!this.camera||!this.player) return; this.mouseMovement.inRightClickMode=true; },
  endRightClickMode(){ if(!this.camera) return; this.mouseMovement.inRightClickMode=false; },
  checkForwardMovement(){ const should=this.mouseMovement.leftMouseDown&&this.mouseMovement.rightMouseDown; if(should&&!this.mouseMovement.isMovingForward){ this.mouseMovement.isMovingForward=true; this.mouseMovement.moveStartTime=Date.now(); } else if(!should&&this.mouseMovement.isMovingForward){ this.mouseMovement.isMovingForward=false; } },
  rotateCharacterToCameraDirection(){ if(!this.camera||!this.player) return; const y=this.player.position.y; const dir=this.camera.getTarget().subtract(this.camera.position).normalize(); dir.y=0; dir.normalize(); this.player.rotation.y=Math.atan2(dir.x,dir.z); this.player.position.y=y; },
  updateMovement(){
    if(!this.player||!this.camera) return;
    
    const dt = this.engine.getDeltaTime() / 1000;
    
    // If we have a character behavior system, use it
    if (this.characterBehavior) {
      this.updateCharacterMovement(dt);
    } else {
      // Fallback to original movement system
      this.updateLegacyMovement(dt);
    }
  },
  updateCharacterMovement(deltaTime) {
    // Create movement input object from current input state
    const movementInput = {
      forward: this.keys['w'] || this.mouseMovement.leftMouseDown,
      backward: this.keys['s'],
      left: this.keys['a'],
      right: this.keys['d'],
      jump: this.keys[' '],
      sprint: this.keys['shift'] || false, // Could add shift key detection
      fly: this.keys['f'] || false, // Could add F key for flying
    };
    
    // Update character behavior
    this.characterBehavior.updateMovement(movementInput, deltaTime);
    
    // Update camera to follow player
    if (this.camera && this.player) {
      this.camera.setTarget(this.player.position);
      
      // Handle right-click camera rotation
      if (this.mouseMovement.rightMouseDown) {
        const dir = this.camera.getTarget().subtract(this.camera.position).normalize();
        dir.y = 0; 
        dir.normalize();
        this.player.rotation.y = Math.atan2(dir.x, dir.z);
      }
    }
    
    // Update animation based on character state
    this.updateCharacterAnimation();
  },
  updateCharacterAnimation() {
    if (!this.characterBehavior || !this.playerAnimations) return;
    
    const animationState = this.characterBehavior.getCurrentAnimationState();
    
    // Stop all current animations
    this.playerAnimations.forEach(ag => {
      if (ag.isPlaying) {
        ag.stop();
      }
    });
    
    // Find and play the appropriate animation
    const targetAnimation = this.playerAnimations.find(ag => 
      ag.name.toLowerCase().includes(animationState.toLowerCase())
    );
    
    if (targetAnimation) {
      targetAnimation.start(true); // Loop the animation
    } else {
      // Fallback to idle or first available animation
      const idleAnimation = this.playerAnimations.find(ag => 
        ag.name.toLowerCase().includes('idle')
      );
      if (idleAnimation) {
        idleAnimation.start(true);
      } else if (this.playerAnimations.length > 0) {
        this.playerAnimations[0].start(true);
      }
    }
  },
  updateLegacyMovement(dt) {
    // Original movement code as fallback
    const move=new Vector3(0,0,0);
    const f=this.camera.getTarget().subtract(this.camera.position).normalize(); f.y=0;
    const r=Vector3.Cross(Vector3.Up(),f).normalize();
    // Treat left-click as 'W' (forward)
    const isForward = this.keys['w'] || this.mouseMovement.leftMouseDown;
    if(isForward) move.addInPlace(f);
    if(this.keys['s']) move.subtractInPlace(f);
    if(this.keys['d']) move.addInPlace(r);
    if(this.keys['a']) move.subtractInPlace(r);

    // Right-click + drag: rotate character in place to match camera direction
    if(this.mouseMovement.rightMouseDown){
      // Only rotate, do not move
      const dir=this.camera.getTarget().subtract(this.camera.position).normalize();
      dir.y=0; dir.normalize();
      this.player.rotation.y=Math.atan2(dir.x,dir.z);
    }
    if(move.length()>0){
      move.normalize().scaleInPlace(this.moveSpeed*dt);
      const newPos=this.player.position.add(move);
      const dist=Vector3.Distance(new Vector3(newPos.x,0,newPos.z), new Vector3(0,0,0));
      this.isInWater=dist<200;
      this.player.position.x=newPos.x;
      this.player.position.z=newPos.z;
      const terrainH=this.getTerrainHeightAt(this.player.position.x,this.player.position.z);
      if(this.isInWater){
        const waterH=2+Math.sin(Date.now()*0.001*0.5)*0.2;
        if(!this.isJumping) this.player.position.y=Math.max(waterH+1, terrainH+3);
      } else if(!this.isJumping){
        this.player.position.y=Math.max(terrainH+3, this.player.position.y);
      }
      this.camera.setTarget(this.player.position);
      // Only rotate to movement direction if not right-clicking
      if(!this.mouseMovement.rightMouseDown){
        const tRot=Math.atan2(move.x,move.z);
        let cur=this.player.rotation.y;
        let diff=tRot-cur;
        if(diff>Math.PI) diff-=2*Math.PI;
        if(diff<-Math.PI) diff+=2*Math.PI;
        this.player.rotation.y=cur+diff*8*dt;
      }
    }
    if(this.keys[' ']&&!this.isJumping){
      this.isJumping=true;
      this.jumpVelocity=12;
    }
    if(this.isJumping){
      this.player.position.y+=this.jumpVelocity*dt;
      this.jumpVelocity-=25*dt;
      const terrainH=this.getTerrainHeightAt(this.player.position.x,this.player.position.z);
      const waterH=this.isInWater?2+Math.sin(Date.now()*0.001*0.5)*0.2+1:0;
      const ground=Math.max(terrainH+3, waterH);
      if(this.player.position.y<=ground){
        this.player.position.y=ground;
        this.isJumping=false;
        this.jumpVelocity=0;
      }
    }
  },
  getTerrainHeightAt(x,z){ if(!this.terrain) return 0; const rayOrig=new Vector3(x,100,z); const hit=this.scene.pickWithRay(new Ray(rayOrig,new Vector3(0,-1,0)), m=>m===this.terrain); return(hit.hit&&hit.pickedPoint)?hit.pickedPoint.y:0; },
  createChatUI(){ const chatContainer=document.createElement('div'); chatContainer.id='world-chat-container'; chatContainer.style.cssText='position:absolute;bottom:20px;left:20px;width:400px;max-height:300px;background:rgba(0,0,0,0.8);border-radius:8px;padding:10px;font-family:monospace;font-size:12px;color:#00ff00;z-index:1000;pointer-events:auto;'; const messagesArea=document.createElement('div'); messagesArea.id='chat-messages-area'; messagesArea.style.cssText='max-height:200px;overflow-y:auto;margin-bottom:10px;padding:5px;'; const inputContainer=document.createElement('div'); inputContainer.style.cssText='display:flex;gap:5px;'; const chatInput=document.createElement('input'); chatInput.id='chat-input'; chatInput.type='text'; chatInput.placeholder='Type message...'; chatInput.style.cssText='flex:1;background:rgba(0,0,0,0.9);border:1px solid #00ff00;color:#00ff00;padding:5px;border-radius:4px;font-family:monospace;font-size:12px;'; const sendBtn=document.createElement('button'); sendBtn.textContent='Send'; sendBtn.style.cssText='background:#00ff00;color:#000;border:none;padding:5px 10px;border-radius:4px;cursor:pointer;font-family:monospace;font-size:12px;'; inputContainer.appendChild(chatInput); inputContainer.appendChild(sendBtn); chatContainer.appendChild(messagesArea); chatContainer.appendChild(inputContainer); this.el.parentElement.appendChild(chatContainer); this.chatContainer=chatContainer; this.messagesArea=messagesArea; this.chatInput=chatInput; const enterHandler=e=>{ e.stopImmediatePropagation(); if(e.key==='Enter'){ e.preventDefault(); this.sendChatMessage(); return false; } }; chatInput.addEventListener('keydown',enterHandler,true); chatInput.addEventListener('keyup',e=>e.stopImmediatePropagation(),true); chatInput.addEventListener('keypress',e=>{ e.stopImmediatePropagation(); if(e.key==='Enter'){ e.preventDefault(); return false;} },true); sendBtn.addEventListener('click',e=>{ e.preventDefault(); e.stopImmediatePropagation(); this.sendChatMessage(); return false; },true); this.addChatMessage('SYSTEM','Welcome! Use WASD to move, space to jump, right-click to move forward.','#ffff00'); },
  addChatMessage(username,message,color='#00ff00'){ if(!this.messagesArea)return; const el=document.createElement('div'); el.style.cssText='margin-bottom:5px;color:'+color+';word-wrap:break-word;'; const ts=new Date().toLocaleTimeString(); el.innerHTML=`<span style="color:#888">[${ts}]</span> <strong>${username}:</strong> ${message}`; this.messagesArea.appendChild(el); this.messagesArea.scrollTop=this.messagesArea.scrollHeight; while(this.messagesArea.children.length>50){ this.messagesArea.removeChild(this.messagesArea.firstChild);} },
  sendChatMessage(){ if(!this.chatInput||!this.chatInput.value.trim())return; const msg=this.chatInput.value.trim(); const username=this.getCurrentUsername(); this.addChatMessage(username,msg); try{ if(typeof this.pushEvent==='function'){ this.pushEvent('chat_message',{ message:msg, username, user_id:this.userData?.id }); } }catch(e){ console.warn('Failed to send chat:',e);} this.chatInput.value=''; this.chatInput.blur(); },
  updateServerUsers(){},
  setupEventListeners(){ this.handleEvent('chat_message',d=>{ if(d.username!==this.getCurrentUsername()) this.addChatMessage(d.username,d.message); }); this.handleEvent('user_joined',d=>this.addChatMessage('SYSTEM',`${d.username} joined the world`,'#00ffff')); this.handleEvent('user_left',d=>this.addChatMessage('SYSTEM',`${d.username} left the world`,'#ff8800')); },
  getCurrentUsername(){ return this.userData?.name || this.userData?.username || 'Player'; },
  cleanup(){ 
    if(this.mouseMovement){ 
      this.mouseMovement.isMovingForward=false; 
      this.mouseMovement.leftMouseDown=false; 
      this.mouseMovement.rightMouseDown=false; 
      this.mouseMovement.inRightClickMode=false; 
    } 
    if(this.chatContainer?.parentElement){ 
      this.chatContainer.parentElement.removeChild(this.chatContainer);
    } 
    if(this.keyDownHandler) document.removeEventListener('keydown',this.keyDownHandler,{capture:true}); 
    if(this.keyUpHandler) document.removeEventListener('keyup',this.keyUpHandler,{capture:true}); 
    
    // Cleanup character systems
    if(this.characterModelManager) {
      this.characterModelManager.dispose();
    }
    
    if(this.engine) this.engine.dispose(); 
  }
};