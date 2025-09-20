// Import Babylon.js classes from our optimized imports
import { 
    Vector3, Color3, MeshBuilder, StandardMaterial, ArcRotateCamera, UniversalCamera, Ray
} from './babylon_imports';

// Character movement controller for the lobby and zones
export class CharacterController {
    constructor(scene, camera) {
        this.scene = scene;
        this.camera = camera;
        this.character = null;
        this.moveSpeed = 5;
        this.rotateSpeed = 2;
        this.isMoving = false;
        
        this.keys = {
            w: false, a: false, s: false, d: false,
            up: false, down: false, left: false, right: false
        };

        this.setupInputHandling();
        this.createCharacterMesh();
    }

    createCharacterMesh() {
        // Create a simple character representation (can be replaced with actual character models later)
        const { MeshBuilder, StandardMaterial, Color3 } = this.getBabylonCore();
        
        // Character capsule
        this.character = MeshBuilder.CreateCapsule("character", 
            { height: 1.8, radius: 0.3 }, this.scene);
        
        const charMaterial = new StandardMaterial("charMat", this.scene);
        charMaterial.diffuseColor = new Color3(0.2, 0.4, 0.8);
        this.character.material = charMaterial;
        
        // Position character at spawn point
        this.character.position = new (this.getBabylonCore().Vector3)(0, 1, 0);
        
        // Setup camera to follow character
        this.setupCameraFollow();
        
        return this.character;
    }

    getBabylonCore() {
        // Get Babylon classes from the imports
        return {
            Vector3: Vector3,
            MeshBuilder: MeshBuilder,
            StandardMaterial: StandardMaterial,
            Color3: Color3
        };
    }

    setupCameraFollow() {
        // Third-person camera setup
        if (this.camera instanceof ArcRotateCamera) {
            this.camera.setTarget(this.character.position);
            this.camera.radius = 8;
            this.camera.heightOffset = 2;
        } else if (this.camera instanceof UniversalCamera || this.camera instanceof FreeCamera) {
            // First-person style follow
            this.camera.setTarget(this.character.position.add(new Vector3(0, 0, 1)));
        }
    }

    setupInputHandling() {
        // Keyboard input
        document.addEventListener('keydown', (event) => {
            this.handleKeyDown(event);
        });

        document.addEventListener('keyup', (event) => {
            this.handleKeyUp(event);
        });

        // Register render loop for movement
        this.scene.registerBeforeRender(() => {
            this.updateMovement();
        });
    }

    handleKeyDown(event) {
        const key = event.key.toLowerCase();
        switch(key) {
            case 'w':
            case 'arrowup':
                this.keys.w = true;
                break;
            case 's':
            case 'arrowdown':
                this.keys.s = true;
                break;
            case 'a':
            case 'arrowleft':
                this.keys.a = true;
                break;
            case 'd':
            case 'arrowright':
                this.keys.d = true;
                break;
        }
        event.preventDefault();
    }

    handleKeyUp(event) {
        const key = event.key.toLowerCase();
        switch(key) {
            case 'w':
            case 'arrowup':
                this.keys.w = false;
                break;
            case 's':
            case 'arrowdown':
                this.keys.s = false;
                break;
            case 'a':
            case 'arrowleft':
                this.keys.a = false;
                break;
            case 'd':
            case 'arrowright':
                this.keys.d = false;
                break;
        }
    }

    updateMovement() {
        if (!this.character) return;

        const deltaTime = this.scene.getEngine().getDeltaTime() / 1000;
        let moveVector = new Vector3(0, 0, 0);
        let rotateAmount = 0;

        // Calculate movement based on camera direction
        const cameraForward = this.camera.getForwardRay().direction;
        const cameraRight = Vector3.Cross(cameraForward, Vector3.Up()).normalize();
        
        // Forward/backward movement
        if (this.keys.w) {
            moveVector = moveVector.add(cameraForward.scale(this.moveSpeed * deltaTime));
            this.isMoving = true;
        }
        if (this.keys.s) {
            moveVector = moveVector.subtract(cameraForward.scale(this.moveSpeed * deltaTime));
            this.isMoving = true;
        }

        // Left/right movement (strafe)
        if (this.keys.a) {
            moveVector = moveVector.subtract(cameraRight.scale(this.moveSpeed * deltaTime));
            this.isMoving = true;
        }
        if (this.keys.d) {
            moveVector = moveVector.add(cameraRight.scale(this.moveSpeed * deltaTime));
            this.isMoving = true;
        }

        // Apply movement
        if (moveVector.length() > 0) {
            // Keep Y position stable (no flying)
            moveVector.y = 0;
            this.character.position = this.character.position.add(moveVector);
            
            // Update camera to follow character
            this.updateCameraFollow();
        } else {
            this.isMoving = false;
        }
    }

    updateCameraFollow() {
        if (this.camera instanceof ArcRotateCamera) {
            this.camera.setTarget(this.character.position);
        } else if (this.camera instanceof UniversalCamera || this.camera instanceof FreeCamera) {
            // Smooth camera follow for first-person
            const targetPos = this.character.position.add(new Vector3(0, 1.6, 0)); // Eye level
            this.camera.position = Vector3.Lerp(this.camera.position, targetPos, 0.1);
        }
    }

    moveCharacterTo(x, y, z) {
        if (this.character) {
            this.character.position = new Vector3(x, y, z);
            this.updateCameraFollow();
        }
    }

    getCharacterPosition() {
        return this.character ? this.character.position : new Vector3(0, 0, 0);
    }

    setMoveSpeed(speed) {
        this.moveSpeed = speed;
    }

    dispose() {
        if (this.character) {
            this.character.dispose();
        }
        
        // Remove event listeners
        document.removeEventListener('keydown', this.handleKeyDown);
        document.removeEventListener('keyup', this.handleKeyUp);
    }
}