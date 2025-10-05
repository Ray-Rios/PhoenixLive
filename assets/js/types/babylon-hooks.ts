// TypeScript interfaces for Babylon.js hooks

import { LiveViewHook } from './liveview';

// Use any for Babylon.js types since they're imported dynamically
export interface BabylonHookData {
    engine: any | null;
    scene: any | null;
    camera: any | null;
    animationRunning: boolean;
    canvas?: HTMLCanvasElement;
}

export interface GalaxySceneData extends BabylonHookData {
    stars: any[];
    debouncedResize: () => void;
    visibilityHandler: () => void;
    pageLoadingStopHandler: () => void;
    windowResizeHandler: () => void;
    _lastDPR: number;
    _lastCanvasClientW: number;
    _lastCanvasClientH: number;
    _framesSinceLastIntegrityCheck: number;
}

export interface StarAnimationData {
    speed: number;
    radius: number;
    offset: number;
    originalPosition: any; // Vector3
}

export interface AnimatedStar {
    animationData: StarAnimationData;
    position: any;
    scaling: any;
    material: any;
    dispose(): void;
}

export interface HomeGalaxySceneHook extends LiveViewHook, GalaxySceneData {
    initializeGalaxyScene(canvas: HTMLCanvasElement): Promise<boolean>;
    createCamera(): Promise<void>;
    createSkybox(): Promise<void>;
    createStarField(): Promise<void>;
    generateGalaxyTexture(texture: any): void;
    startRenderLoop(): void;
    ensureResolutionIntegrity(canvas: HTMLCanvasElement): void;
    handleResize(): void;
    pause(): void;
    resume(): void;
    cleanup(): void;
}

export interface TerrainOptions {
    size?: number;
    subdivisions?: number;
    maxHeight?: number;
}

export interface HeightmapTerrainInterface {
    scene: any; // Scene
    options: Required<TerrainOptions>;
    createFromImage(imagePath: string): Promise<any>; // Promise<Mesh>
    loadHeightmapImage(imagePath: string): Promise<number[]>;
    createTerrainMesh(heights: number[]): any; // Mesh
    createFlatTerrain(): any; // Mesh
    getHeightAtPosition(x: number, z: number, terrain: any): number; // terrain: Mesh
}