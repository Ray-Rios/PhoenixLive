// assets/js/babylon/lazy_loader.js
export class BabylonLazyLoader {
    static async loadCore() {
        const { Engine, Scene, Vector3, FreeCamera, HemisphericLight, MeshBuilder } = 
            await import('./babylon_imports.js');
        return { Engine, Scene, Vector3, FreeCamera, HemisphericLight, MeshBuilder };
    }

    static async loadPhysics() {
        // Only load physics when actually needed
        if (!this.physicsLoaded) {
            const HavokPhysics = await import('@babylonjs/havok');
            this.physicsLoaded = true;
            return HavokPhysics.default;
        }
    }

    static async loadGUI() {
        // Only load GUI when needed
        if (!this.guiLoaded) {
            const GUI = await import('@babylonjs/gui/2D');
            this.guiLoaded = true;
            return GUI;
        }
    }
}