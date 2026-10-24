# Family Quest Character Creator — Step 1

Separate Godot 4.3 starter project for the Android-friendly creator workflow.

## Included
- A separate creator project; it does not modify Family Quest.
- A 3D preview viewport with a built-in placeholder character.
- GLB import/preview using Godot's GLTFDocument runtime API.
- Touch-drag camera controls and mouse-wheel zoom for desktop testing.
- Compatibility renderer for mobile-oriented development.

## Open
Open this folder as a Godot 4.3 project and run `scenes/main.tscn`.

## Android note
The built-in FileDialog may not provide the ideal Android document-picker experience on every device/export setup. Test on the target phone. If it cannot select files from Downloads, the next iteration should add an Android-compatible file selection/import flow.

## Current limits
This is a foundation prototype. It previews models and has a placeholder character. It does not yet generate 3D models with AI, repair meshes, rig characters, or perform a complete production export validation.
