# 3D Character Asset Pipeline (glTF Preferred)

This guide explains how to prepare and integrate character models into the Phoenix/Babylon lobby.

## Summary
Use glTF 2.0 (`.gltf` + optional `.bin` + textures) as the primary format. FBX is only a temporary source format for conversion. Place exported assets under:
```
priv/static/models/<CharacterName>/<CharacterName>.gltf
priv/static/models/<CharacterName>/<CharacterName>.bin         (if using separate buffers)
priv/static/models/<CharacterName>/textures/*                  (if external textures)
```
`CharacterName` must exactly match the `config.name` in `character_model_manager_new.ts` (case sensitive):
- Eagle
- Fox
- HammerheadShark

## Why glTF?
- Native support in Babylon.js loader.
- Compact transmission (binary buffers, shared textures).
- Explicit animation channels and PBR materials.

## Converting FBX to glTF (Blender Workflow)
1. Open Blender → File → Import → FBX.
2. Select the FBX; if scale is very large, set Import Scale = 0.01.
3. In the 3D Viewport: select root object → Object > Apply > All Transforms.
4. Open the Action Editor / Dope Sheet, ensure each animation has a distinct, clear name: `Idle`, `Walk`, `Run`, `Fly`, `Swim`, `Jump`.
5. Remove unused meshes, clean up materials (optional but recommended).
6. File → Export → glTF 2.0:
   - Format: glTF Separate (preferred for caching) OR glTF Embedded for a single file.
   - Include: Meshes, Animations, Materials.
   - Remember to keep animation names consistent.
7. Export to: `priv/static/models/<CharacterName>/`.

If you chose Separate, move all generated files (gltf + bin + textures folder) into that directory.

## Animation Naming Conventions
| Behavior State | Accepted Name Substrings          |
|----------------|-----------------------------------|
| Idle           | idle, rest, stand                |
| Walk           | walk, move, locomotion, pace     |
| Run            | run, sprint, fast                |
| Fly            | fly, glide, soar                 |
| Swim           | swim                             |
| Jump           | jump, hop                        |

The system performs a case-insensitive partial match using these synonyms. If mismatched, it falls back to the first `idle` or any available animation.

## Verifying the Asset Loads
1. Hard reload the browser to avoid cached 404s.
2. Open dev tools console.
3. You should see: `Loading Fox from: /models/Fox/Fox.gltf` followed by `✅ Successfully loaded Fox:`.
4. If you see 404: The file path does not match the expected folder/filename.
5. If SceneLoader has no registered `.gltf` extension, dynamic imports failed — check network panel for blocked module requests.

## Testing Locally
From project root, your static directory is served under `/`. So the file `priv/static/models/Fox/Fox.gltf` should be reachable at:
`http://localhost:4000/models/Fox/Fox.gltf`

## FBX Fallback (Not Recommended in Production)
If you only have `HammerheadShark.fbx`:
```
priv/static/models/HammerheadShark/HammerheadShark.fbx
```
You also need an FBX loader plugin; Babylon core does not ship full FBX support. Convert to glTF to avoid this dependency.

## Scaling & Orientation
- If a model appears too large/small, adjust the per-character `scale` in `character_model_manager_new.ts` rather than re-exporting.
- Forward direction expected: +Z in your current fallback logic (rotate as needed in Blender so character faces +Z before export).

## Adding a New Character
1. Add config entry in `character_model_manager_new.ts` with unique `name`, `type`, `scale`, formats.
2. Export and place assets under matching `priv/static/models/<Name>/`.
3. Rebuild assets, reload page.

## Common Issues
| Issue | Cause | Fix |
|-------|-------|-----|
| 404 loading .gltf | Wrong path or filename case | Match folder & file names exactly to config.name |
| Mesh is not a constructor | Tree-shaken Mesh import | Root `@babylonjs/core` fallback added; ensure bundle updated |
| No animations play | Animation names don’t match synonyms | Rename animations or extend synonym table |
| Character doesn’t face W direction | Orientation mismatch in export | Rotate model in Blender, apply transforms, re-export |

## Extending Synonyms
Adjust inside `open_world_lobby_scene_class.ts` where `synonyms` map is defined.

---
Maintainer Notes:
- Keep asset sizes reasonable (<5 MB) to minimize initial lobby load time.
- Consider adding a preloader manifest if number of characters grows.
