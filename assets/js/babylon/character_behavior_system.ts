// Character Behavior System - Defines movement and behavior patterns for different character types

import type { CharacterType, CharacterTypeConfig } from './character_model_manager_new';

export interface MovementState {
  isMoving: boolean;
  isRunning: boolean;
  isFlying: boolean;
  isSwimming: boolean;
  isJumping: boolean;
  currentSpeed: number;
  jumpVelocity: number;
  altitude: number; // For flying characters
  inWater: boolean;
  onGround: boolean;
}

export interface CharacterBounds {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  minY: number; // Minimum altitude (water level for sharks)
  maxY: number; // Maximum altitude (height limit for eagles)
  waterLevel: number;
  groundLevel: number;
}

export interface MovementInput {
  forward: boolean;
  backward: boolean;
  left: boolean;
  right: boolean;
  jump: boolean;
  sprint: boolean;
  fly: boolean; // For eagles
}

export abstract class CharacterBehavior {
  protected config: CharacterTypeConfig;
  protected movementState: MovementState;
  protected bounds: CharacterBounds;
  protected mesh: any; // Babylon mesh
  protected scene: any; // Babylon scene

  constructor(config: CharacterTypeConfig, mesh: any, scene: any) {
    this.config = config;
    this.mesh = mesh;
    this.scene = scene;
    this.movementState = this.initializeMovementState();
    this.bounds = this.initializeBounds();
  }

  protected initializeMovementState(): MovementState {
    return {
      isMoving: false,
      isRunning: false,
      isFlying: false,
      isSwimming: false,
      isJumping: false,
      currentSpeed: 0,
      jumpVelocity: 0,
      altitude: 0,
      inWater: false,
      onGround: true,
    };
  }

  protected initializeBounds(): CharacterBounds {
    return {
      minX: -500,
      maxX: 500,
      minZ: -500,
      maxZ: 500,
      minY: -10, // Below water level
      maxY: 200, // Sky limit
      waterLevel: 45,
      groundLevel: 50, // Island level
    };
  }

  // Abstract methods to be implemented by each character type
  abstract updateMovement(input: MovementInput, deltaTime: number): void;
  abstract applyEnvironmentalConstraints(): void;
  abstract getCurrentAnimationState(): string;
  abstract canPerformAction(action: string): boolean;

  // Common utility methods
  protected updatePosition(deltaTime: number, velocity: { x: number; y: number; z: number }): void {
    if (!this.mesh) return;

    const newPosition = {
      x: this.mesh.position.x + velocity.x * deltaTime,
      y: this.mesh.position.y + velocity.y * deltaTime,
      z: this.mesh.position.z + velocity.z * deltaTime,
    };

    // Apply bounds checking
    newPosition.x = Math.max(this.bounds.minX, Math.min(this.bounds.maxX, newPosition.x));
    newPosition.z = Math.max(this.bounds.minZ, Math.min(this.bounds.maxZ, newPosition.z));
    newPosition.y = Math.max(this.bounds.minY, Math.min(this.bounds.maxY, newPosition.y));

    this.mesh.position.x = newPosition.x;
    this.mesh.position.y = newPosition.y;
    this.mesh.position.z = newPosition.z;

    // Update environmental state
    this.updateEnvironmentalState();
  }

  protected updateEnvironmentalState(): void {
    const y = this.mesh.position.y;
    this.movementState.inWater = y <= this.bounds.waterLevel;
    this.movementState.onGround = y <= this.bounds.groundLevel + 1;
    this.movementState.altitude = Math.max(0, y - this.bounds.groundLevel);
  }

  // Getters
  public getMovementState(): MovementState {
    return { ...this.movementState };
  }

  public getConfig(): CharacterTypeConfig {
    return this.config;
  }

  public getCurrentSpeed(): number {
    return this.movementState.currentSpeed;
  }
}

// Eagle Behavior - Can fly, walk, but prefers flying
export class EagleBehavior extends CharacterBehavior {
  private flyingAltitude = 80; // Preferred flying altitude
  private soaringMode = false;

  updateMovement(input: MovementInput, deltaTime: number): void {
    const velocity = { x: 0, y: 0, z: 0 };
    
    // Determine movement mode
    const shouldFly = input.fly || this.movementState.altitude > 10;
    
    if (shouldFly && this.config.behaviors.canFly) {
      this.handleFlyingMovement(input, velocity, deltaTime);
    } else {
      this.handleGroundMovement(input, velocity, deltaTime);
    }

    this.updatePosition(deltaTime, velocity);
    this.applyEnvironmentalConstraints();
  }

  private handleFlyingMovement(input: MovementInput, velocity: any, deltaTime: number): void {
    this.movementState.isFlying = true;
    this.movementState.isSwimming = false;
    
    const speed = input.sprint ? this.config.behaviors.flySpeed! * 1.5 : this.config.behaviors.flySpeed!;
    
    // Forward/backward
    if (input.forward) {
      velocity.z += speed;
      this.movementState.isMoving = true;
    }
    if (input.backward) {
      velocity.z -= speed * 0.7; // Slower backward flying
    }
    
    // Strafing
    if (input.left) velocity.x -= speed * 0.8;
    if (input.right) velocity.x += speed * 0.8;
    
    // Altitude control
    if (input.jump) {
      velocity.y += speed * 0.6; // Climb
    } else if (this.mesh.position.y > this.flyingAltitude) {
      // Auto-descend to preferred altitude
      velocity.y -= speed * 0.3;
    } else if (this.mesh.position.y < this.flyingAltitude - 10) {
      // Auto-climb to preferred altitude
      velocity.y += speed * 0.2;
    }

    this.movementState.currentSpeed = speed;
  }

  private handleGroundMovement(input: MovementInput, velocity: any, deltaTime: number): void {
    this.movementState.isFlying = false;
    
    const speed = input.sprint ? this.config.behaviors.maxSpeed * 1.2 : this.config.behaviors.maxSpeed;
    
    // Ground movement
    if (input.forward) {
      velocity.z += speed;
      this.movementState.isMoving = true;
    }
    if (input.backward) {
      velocity.z -= speed * 0.6;
    }
    if (input.left) velocity.x -= speed * 0.7;
    if (input.right) velocity.x += speed * 0.7;
    
    // Take off when jumping on ground
    if (input.jump && this.movementState.onGround) {
      this.movementState.isFlying = true;
      velocity.y += 15; // Take-off velocity
    }

    this.movementState.currentSpeed = speed;
  }

  applyEnvironmentalConstraints(): void {
    // Eagles can't swim well - if in water, they try to escape
    if (this.movementState.inWater && !this.movementState.isFlying) {
      this.movementState.isFlying = true;
      // Emergency takeoff from water
      if (this.mesh.position.y <= this.bounds.waterLevel + 2) {
        this.mesh.position.y += 0.5; // Boost out of water
      }
    }
  }

  getCurrentAnimationState(): string {
    if (this.movementState.isFlying) {
      return this.movementState.isMoving ? 'fly' : 'soar';
    } else if (this.movementState.isMoving) {
      return 'walk';
    } else {
      return 'idle';
    }
  }

  canPerformAction(action: string): boolean {
    switch (action) {
      case 'fly': return this.config.behaviors.canFly;
      case 'swim': return false; // Eagles don't swim well
      case 'jump': return !this.movementState.isFlying;
      case 'run': return !this.movementState.isFlying;
      default: return true;
    }
  }
}

// Fox Behavior - Fast ground movement, good jumping, can swim
export class FoxBehavior extends CharacterBehavior {
  private agility = 1.3; // Foxes are agile

  updateMovement(input: MovementInput, deltaTime: number): void {
    const velocity = { x: 0, y: 0, z: 0 };
    
    if (this.movementState.inWater) {
      this.handleSwimmingMovement(input, velocity, deltaTime);
    } else {
      this.handleGroundMovement(input, velocity, deltaTime);
    }

    this.updatePosition(deltaTime, velocity);
    this.applyEnvironmentalConstraints();
  }

  private handleGroundMovement(input: MovementInput, velocity: any, deltaTime: number): void {
    this.movementState.isSwimming = false;
    
    const baseSpeed = this.config.behaviors.maxSpeed;
    const speed = input.sprint ? baseSpeed * 1.5 * this.agility : baseSpeed * this.agility;
    
    // Ground movement with agility bonus
    if (input.forward) {
      velocity.z += speed;
      this.movementState.isMoving = true;
      this.movementState.isRunning = input.sprint;
    }
    if (input.backward) {
      velocity.z -= speed * 0.8;
    }
    if (input.left) velocity.x -= speed * 0.9;
    if (input.right) velocity.x += speed * 0.9;
    
    // Enhanced jumping
    if (input.jump && this.movementState.onGround && !this.movementState.isJumping) {
      this.movementState.isJumping = true;
      this.movementState.jumpVelocity = this.config.behaviors.jumpHeight! * this.agility;
    }

    // Apply jump physics
    if (this.movementState.isJumping) {
      velocity.y += this.movementState.jumpVelocity;
      this.movementState.jumpVelocity -= 25 * deltaTime; // Gravity
      
      if (this.movementState.onGround && this.movementState.jumpVelocity <= 0) {
        this.movementState.isJumping = false;
        this.movementState.jumpVelocity = 0;
      }
    }

    this.movementState.currentSpeed = speed;
  }

  private handleSwimmingMovement(input: MovementInput, velocity: any, deltaTime: number): void {
    this.movementState.isSwimming = true;
    this.movementState.isRunning = false;
    
    const swimSpeed = this.config.behaviors.maxSpeed * 0.7; // Foxes are decent swimmers
    
    // Swimming movement
    if (input.forward) {
      velocity.z += swimSpeed;
      this.movementState.isMoving = true;
    }
    if (input.backward) {
      velocity.z -= swimSpeed * 0.6;
    }
    if (input.left) velocity.x -= swimSpeed * 0.8;
    if (input.right) velocity.x += swimSpeed * 0.8;
    
    // Swimming up/down
    if (input.jump) {
      velocity.y += swimSpeed * 0.5;
    }

    this.movementState.currentSpeed = swimSpeed;
  }

  applyEnvironmentalConstraints(): void {
    // Foxes handle all environments reasonably well
    // No special constraints needed
  }

  getCurrentAnimationState(): string {
    if (this.movementState.isSwimming) {
      return this.movementState.isMoving ? 'swim' : 'idle';
    } else if (this.movementState.isJumping) {
      return 'jump';
    } else if (this.movementState.isMoving) {
      return this.movementState.isRunning ? 'run' : 'walk';
    } else {
      return 'idle';
    }
  }

  canPerformAction(action: string): boolean {
    switch (action) {
      case 'fly': return false;
      case 'swim': return this.config.behaviors.canSwim;
      case 'jump': return !this.movementState.isSwimming;
      case 'run': return !this.movementState.isSwimming;
      default: return true;
    }
  }
}

// Hammerhead Shark Behavior - Swimming only, cannot walk or fly
export class HammerheadSharkBehavior extends CharacterBehavior {
  private cruisingDepth = 40; // Preferred depth below surface

  updateMovement(input: MovementInput, deltaTime: number): void {
    const velocity = { x: 0, y: 0, z: 0 };
    
    // Sharks can only swim
    this.handleSwimmingMovement(input, velocity, deltaTime);
    this.updatePosition(deltaTime, velocity);
    this.applyEnvironmentalConstraints();
  }

  private handleSwimmingMovement(input: MovementInput, velocity: any, deltaTime: number): void {
    this.movementState.isSwimming = true;
    this.movementState.isFlying = false;
    
    const swimSpeed = this.config.behaviors.swimSpeed!;
    const burstSpeed = input.sprint ? swimSpeed * 1.4 : swimSpeed;
    
    // Swimming movement
    if (input.forward) {
      velocity.z += burstSpeed;
      this.movementState.isMoving = true;
    }
    if (input.backward) {
      velocity.z -= burstSpeed * 0.5; // Sharks move mainly forward
    }
    if (input.left) velocity.x -= burstSpeed * 0.8;
    if (input.right) velocity.x += burstSpeed * 0.8;
    
    // Depth control
    if (input.jump) {
      velocity.y += burstSpeed * 0.4; // Surface
    } else if (this.mesh.position.y > this.cruisingDepth) {
      // Auto-dive to preferred depth
      velocity.y -= burstSpeed * 0.3;
    }

    this.movementState.currentSpeed = burstSpeed;
  }

  applyEnvironmentalConstraints(): void {
    // Sharks must stay in water
    if (!this.movementState.inWater) {
      // Force shark back into water
      this.mesh.position.y = Math.min(this.mesh.position.y, this.bounds.waterLevel - 1);
    }
    
    // Sharks can't go too deep either
    if (this.mesh.position.y < this.bounds.waterLevel - 50) {
      this.mesh.position.y = this.bounds.waterLevel - 50;
    }
  }

  getCurrentAnimationState(): string {
    if (this.movementState.isMoving) {
      return this.movementState.currentSpeed > this.config.behaviors.swimSpeed! ? 'swim_fast' : 'swim';
    } else {
      return 'idle';
    }
  }

  canPerformAction(action: string): boolean {
    switch (action) {
      case 'fly': return false;
      case 'swim': return true;
      case 'jump': return false; // No jumping for sharks
      case 'run': return false; // No running for sharks
      default: return false;
    }
  }
}

// Factory function to create the appropriate behavior for a character type
export function createCharacterBehavior(
  characterType: CharacterType, 
  config: CharacterTypeConfig, 
  mesh: any, 
  scene: any
): CharacterBehavior {
  switch (characterType) {
    case 'eagle':
      return new EagleBehavior(config, mesh, scene);
    case 'fox':
      return new FoxBehavior(config, mesh, scene);
    case 'hammerhead_shark':
      return new HammerheadSharkBehavior(config, mesh, scene);
    default:
      throw new Error(`Unknown character type: ${characterType}`);
  }
}