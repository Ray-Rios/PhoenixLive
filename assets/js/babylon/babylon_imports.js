// Optimized Babylon.js imports - only import what we need
// Core engine and scene
import { Engine } from '@babylonjs/core/Engines/engine';
import { Scene } from '@babylonjs/core/scene';

// Math and vectors
import { Vector3, Vector2 } from '@babylonjs/core/Maths/math.vector';
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color';
import { Ray } from '@babylonjs/core/Culling/ray';

// Cameras
import { FreeCamera } from '@babylonjs/core/Cameras/freeCamera';
import { ArcRotateCamera } from '@babylonjs/core/Cameras/arcRotateCamera';
import { UniversalCamera } from '@babylonjs/core/Cameras/universalCamera';

// Camera controls (needed for attachToCanvas)
import '@babylonjs/core/Cameras/Inputs/freeCameraMouseInput';
import '@babylonjs/core/Cameras/Inputs/freeCameraKeyboardMoveInput';
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraMouseWheelInput';
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraKeyboardMoveInput';
import '@babylonjs/core/Cameras/Inputs/arcRotateCameraPointersInput';

// Camera Controls - needed for attachToCanvas method
import '@babylonjs/core/Cameras/Inputs';

// Lights
import { HemisphericLight } from '@babylonjs/core/Lights/hemisphericLight';
import { DirectionalLight } from '@babylonjs/core/Lights/directionalLight';

// Meshes and materials
import { MeshBuilder } from '@babylonjs/core/Meshes/meshBuilder';
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial';
import { PBRMaterial } from '@babylonjs/core/Materials/PBR/pbrMaterial';

// Animation
import { Animation } from '@babylonjs/core/Animations/animation';
import { AnimationGroup } from '@babylonjs/core/Animations/animationGroup';

// Input
import { ActionManager } from '@babylonjs/core/Actions/actionManager';
import { ExecuteCodeAction } from '@babylonjs/core/Actions/directActions';
import { PointerEventTypes } from '@babylonjs/core/Events/pointerEvents';

// Loading
import '@babylonjs/core/Loading/loadingScreen';

// Asset loading side effects
import '@babylonjs/core/Materials/Textures/Loaders/envTextureLoader';

export {
    Engine, Scene, Vector3, Vector2, Color3, Color4, Ray,
    FreeCamera, ArcRotateCamera, UniversalCamera,
    HemisphericLight, DirectionalLight,
    MeshBuilder, StandardMaterial, PBRMaterial,
    Animation, AnimationGroup,
    ActionManager, ExecuteCodeAction, PointerEventTypes
};