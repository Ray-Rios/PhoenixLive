// Custom Gamified UI Hooks for Phoenix LiveView (No Impact.js)

// Player Controller Hook - Manages player movement and interactions
export const PlayerController = {
    mounted() {
        this.setupPlayerControls();
        this.startMovementTracking();
    },

    setupPlayerControls() {
        this.player = this.el;
        this.isMoving = false;
        this.lastPosition = { x: 0, y: 0 };
        this.keys = {};

        // Keyboard controls
        document.addEventListener('keydown', (e) => this.handleKeyDown(e));
        document.addEventListener('keyup', (e) => this.handleKeyUp(e));

        // Get initial position
        const rect = this.player.getBoundingClientRect();
        this.lastPosition = { x: rect.left, y: rect.top };

        // Start movement loop
        this.startMovementLoop();
    },

    handleKeyDown(event) {
        this.keys[event.key.toLowerCase()] = true;
        this.keys[event.code] = true;
    },

    handleKeyUp(event) {
        this.keys[event.key.toLowerCase()] = true;
        this.keys[event.code] = false;
    },

    startMovementLoop() {
        this.movementLoop = () => {
            this.updatePlayerMovement();
            requestAnimationFrame(this.movementLoop);
        };
        this.movementLoop();
    },

    updatePlayerMovement() {
        const speed = 5;
        let moved = false;
        const rect = this.player.getBoundingClientRect();
        let newX = rect.left;
        let newY = rect.top;

        // Check movement keys
        if (this.keys['arrowleft'] || this.keys['a'] || this.keys['keya']) {
            newX = Math.max(0, rect.left - speed);
            moved = true;
        }
        if (this.keys['arrowright'] || this.keys['d'] || this.keys['keyd']) {
            newX = Math.min(window.innerWidth - rect.width, rect.left + speed);
            moved = true;
        }
        if (this.keys['arrowup'] || this.keys['w'] || this.keys['keyw']) {
            newY = Math.max(500, rect.top - speed); // Keep in bottom area
            moved = true;
        }
        if (this.keys['arrowdown'] || this.keys['s'] || this.keys['keys']) {
            newY = Math.min(window.innerHeight - rect.height, rect.top + speed);
            moved = true;
        }

        if (moved) {
            this.movePlayer(newX, newY);
        }
    },

    movePlayer(x, y) {
        // Constrain to screen bounds
        x = Math.max(0, Math.min(window.innerWidth - 32, x));
        y = Math.max(500, Math.min(window.innerHeight - 50, y));  // Keep in bottom area

        this.player.style.left = x + 'px';
        this.player.style.top = y + 'px';

        // Send position update to LiveView
        if (Math.abs(x - this.lastPosition.x) > 5 || Math.abs(y - this.lastPosition.y) > 5) {
            this.pushEvent("player_move", { x: x, y: y });
            this.lastPosition = { x: x, y: y };
        }
    },

    startMovementTracking() {
        // Periodically check for collisions
        this.movementInterval = setInterval(() => {
            this.checkCollisions();
        }, 100);
    },

    checkCollisions() {
        // Collision detection will be handled by the canvas game
    },

    destroyed() {
        if (this.movementInterval) {
            clearInterval(this.movementInterval);
        }
    }
};

// Destructible Component Hook - Manages component health and damage effects
export const DestructibleComponent = {
    mounted() {
        this.component = this.el.dataset.component;
        this.health = parseInt(this.el.dataset.health);
        this.maxHealth = parseInt(this.el.dataset.maxHealth);
        this.setupDamageEffects();
    },

    updated() {
        this.health = parseInt(this.el.dataset.health);
        this.updateDamageEffects();
    },

    setupDamageEffects() {
        this.damageEffects = [];
        this.shakeIntensity = 0;

        // Start damage monitoring
        this.damageInterval = setInterval(() => {
            this.checkForDamage();
        }, 2000);
    },

    checkForDamage() {
        // Simulate random damage from space battles
        if (Math.random() < 0.05) {  // 5% chance every 2 seconds
            const damage = Math.floor(Math.random() * 100) + 50;
            this.takeDamage(damage);
        }
    },

    takeDamage(amount) {
        this.pushEvent("component_damage", {
            component: this.component,
            damage: amount
        });

        // Create visual damage effect
        this.createDamageEffect(amount);
    },

    createDamageEffect(damage) {
        // Screen shake
        this.shakeIntensity = Math.min(10, damage / 10);
        this.startScreenShake();

        // Damage number popup
        this.showDamageNumber(damage);

        // Add damaged class temporarily
        this.el.classList.add('damaged');
        setTimeout(() => {
            this.el.classList.remove('damaged');
        }, 500);
    },

    startScreenShake() {
        if (this.shakeIntensity > 0) {
            const shakeX = (Math.random() - 0.5) * this.shakeIntensity;
            const shakeY = (Math.random() - 0.5) * this.shakeIntensity;

            this.el.style.transform = `translate(${shakeX}px, ${shakeY}px)`;

            this.shakeIntensity *= 0.9;  // Decay

            if (this.shakeIntensity > 0.1) {
                requestAnimationFrame(() => this.startScreenShake());
            } else {
                this.el.style.transform = '';
            }
        }
    },

    showDamageNumber(damage) {
        const damageEl = document.createElement('div');
        damageEl.textContent = `-${damage}`;
        damageEl.className = 'damage-number';
        damageEl.style.cssText = `
      position: absolute;
      color: #ff4444;
      font-weight: bold;
      font-size: 18px;
      pointer-events: none;
      z-index: 1000;
      left: ${Math.random() * 200}px;
      top: 20px;
    `;

        this.el.appendChild(damageEl);

        // Animate damage number
        damageEl.animate([
            { transform: 'translateY(0px)', opacity: 1 },
            { transform: 'translateY(-50px)', opacity: 0 }
        ], {
            duration: 1500,
            easing: 'ease-out'
        }).onfinish = () => {
            damageEl.remove();
        };
    },

    updateDamageEffects() {
        const healthPercentage = this.health / this.maxHealth;

        // Update visual state based on health
        if (healthPercentage < 0.2) {
            this.el.style.filter = 'brightness(0.6) contrast(1.3) hue-rotate(10deg)';
        } else if (healthPercentage < 0.5) {
            this.el.style.filter = 'brightness(0.8) contrast(1.1)';
        } else {
            this.el.style.filter = '';
        }
    },

    destroyed() {
        if (this.damageInterval) {
            clearInterval(this.damageInterval);
        }
    }
};

// Draggable Window Hook - Manages window dragging and positioning
export const DraggableWindow = {
    mounted() {
        this.setupDragging();
    },

    setupDragging() {
        this.isDragging = false;
        this.dragOffset = { x: 0, y: 0 };
        this.windowName = this.el.dataset.windowType;

        const dragHandle = this.el.querySelector('.window-header');
        if (dragHandle) {
            dragHandle.addEventListener('mousedown', (e) => this.startDrag(e));
            dragHandle.addEventListener('touchstart', (e) => this.startDrag(e));
        }

        document.addEventListener('mousemove', (e) => this.drag(e));
        document.addEventListener('touchmove', (e) => this.drag(e));
        document.addEventListener('mouseup', () => this.stopDrag());
        document.addEventListener('touchend', () => this.stopDrag());
    },

    startDrag(event) {
        this.isDragging = true;

        const clientX = event.clientX || event.touches[0].clientX;
        const clientY = event.clientY || event.touches[0].clientY;
        const rect = this.el.getBoundingClientRect();

        this.dragOffset.x = clientX - rect.left;
        this.dragOffset.y = clientY - rect.top;

        this.el.style.cursor = 'grabbing';
        event.preventDefault();
    },

    drag(event) {
        if (!this.isDragging) return;

        const clientX = event.clientX || (event.touches && event.touches[0].clientX);
        const clientY = event.clientY || (event.touches && event.touches[0].clientY);

        if (clientX === undefined || clientY === undefined) return;

        const newX = Math.max(0, Math.min(window.innerWidth - this.el.offsetWidth, clientX - this.dragOffset.x));
        const newY = Math.max(0, Math.min(window.innerHeight - this.el.offsetHeight, clientY - this.dragOffset.y));

        this.el.style.left = newX + 'px';
        this.el.style.top = newY + 'px';
    },

    stopDrag() {
        if (this.isDragging) {
            this.isDragging = false;
            this.el.style.cursor = '';

            // Send final position to LiveView
            const rect = this.el.getBoundingClientRect();
            this.pushEvent("move_window", {
                window: this.windowName,
                x: rect.left,
                y: rect.top
            });
        }
    }
};

// Dynamic Content Hook - For WYSIWYG editor
export const DynamicContent = {
    mounted() {
        this.setupDropZone();
    },

    setupDropZone() {
        this.el.addEventListener('dragover', (e) => {
            e.preventDefault();
            this.el.classList.add('drag-over');
        });

        this.el.addEventListener('dragleave', () => {
            this.el.classList.remove('drag-over');
        });

        this.el.addEventListener('drop', (e) => {
            e.preventDefault();
            this.el.classList.remove('drag-over');

            const componentType = e.dataTransfer.getData('text/plain');
            if (componentType) {
                this.addComponent(componentType, e.clientX, e.clientY);
            }
        });
    },

    addComponent(type, x, y) {
        this.pushEvent("add_wysiwyg_component", {
            type: type,
            x: x,
            y: y
        });
    }
};