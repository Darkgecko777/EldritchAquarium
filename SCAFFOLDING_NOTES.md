# Eldritch Aquarium - Initial Scaffolding

This was generated from the planning docs (Readme + Game_Vision.md).

> For the story of *why* we made certain choices during bootstrap (e.g. GDScript switch) and a running log of design decisions across sessions, see [DESIGN_HISTORY.md](DESIGN_HISTORY.md). This file focuses on "how to get the current build running" and concrete next implementation steps.

## What Was Created

### Folder Structure
- `scenes/` + `scenes/entities/`, `scenes/ui/`
- `scripts/`
  - `managers/GameManager.cs` (core singleton)
  - `entities/` (ShippingContainer, Organ, Pet)
  - `ui/ResourceDisplay.cs`
  - `data/GameEnums.cs`
  - `AquariumController.cs` (main tank scene logic)
- `resources/`, `assets/` (with standard subfolders)
- `scenes/Aquarium.tscn` (playable starting scene with placeholders)
- `scenes/entities/*.tscn` (minimal packed scenes for the exports)

### Key Systems (Skeletons)
- **GameManager** — resources, pollution, OrderShipment(), signals. Registered as autoload.
- **AquariumController** — spawns containers from top, handles clicks + SPACE / button, wires everything.
- **ShippingContainer** — drops with tween, clickable to open, asks controller to spawn organs.
- **Organ** — floats, clickable to collect, gives Biomass.
- **Pet** — swims, can be fed, grows visually, evolves at thresholds (unlocks Void Essence).
- **ResourceDisplay** — live-updating HUD labels + pollution bar.

All use heavy placeholder visuals (ColorRect) so you can play immediately.

## How to Use Right Now

1. Open the Godot editor on this project.
2. The autoload `GameManager` is already registered in `project.godot`.
3. Open `scenes/Aquarium.tscn`.
4. In the inspector for the **Aquarium** root node, assign the three PackedScenes under "Spawning":
   - Shipping Container Scene → `res://scenes/entities/ShippingContainer.tscn`
   - Organ Scene → `res://scenes/entities/Organ.tscn`
   - Pet Scene → `res://scenes/entities/Pet.tscn`
5. Run the scene (F5 or the play button).

### Current Playable Loop (MVP)
- Press **SPACE** or click the **"Order Shipment"** button → container drops from the top.
- **Left-click** the landed container → it "opens" and releases 3 organs.
- **Left-click** organs → collect them (gain Biomass).
- **Left-click** the pet → debug feed (uses Biomass).
- Feed enough → pet grows and eventually evolves (fun message + Void Essence).
- Pollution slowly rises with activity. High pollution has a small chance of a "madness" log message.
- Right-click anywhere → +25 Biomass (debug).

The ResourceDisplay at the top updates live.

## Next Immediate Things to Do in Editor

- Add a real background / water shader / bubbles (CPUParticles2D node) to the Aquarium scene.
- Replace ColorRect placeholders with actual sprites (start with the shipping container + a cute larval pet).
- Expand the pet evolution visuals and add more species.
- Make organs draggable onto pets for more satisfying feeding.
- Add sound (even placeholder AudioStreamPlayer beeps).
- Create a real shop UI that lists upgrades (more organs per container, cheaper shipments, etc.).
- Implement actual save/load in GameManager.
- Add a few more madness visual effects when pollution is high.

## File Ownership / Style Notes

- Keep data-driven things in `resources/data/` as .tres custom resources when possible.
- Use signals heavily (already started in GameManager).
- The controller owns the "tank space" — use its ClampToTank() helper from other objects.
- All core logic goes through GameManager so the incremental systems stay centralized.

See Game_Vision.md and Assets.md for the full direction.

Happy shipping!

## Switched to GDScript (for decreased error rates and simpler workflow)

The project has been converted from C# to GDScript. No more .csproj builds, no more delegate signature headaches, no more GlobalClass attributes.

- All logic is now in `.gd` files (equivalent structure preserved).
- Autoload is now `GameManager.gd`.
- Scenes reference the new GDScript files.
- Enums are in `scripts/data/enums.gd` (use `GameEnums.ResourceType.BIOMASS` etc. — make sure `enums.gd` has `class_name GameEnums`).
- GDScript is hot-reload friendly and has lower friction for Godot-specific features (signals, tweens, etc.).

When opening the project, assign the three PackedScene exports on the Aquarium root node (ShippingContainer.tscn, Organ.tscn, Pet.tscn) in the inspector if they are not set.

### Running
1. Open in Godot editor (any 4.6+ build is fine now — no .NET requirement).
2. Press F5. Changes to .gd are picked up instantly.

The visual style (all primitives) and core loop remain the same.

## Current Known Good State

- Title screen is the main scene.
- All visuals use only Godot primitives (ColorRect, CpuParticles2D in C#, CPUParticles2D nodes in editor, StyleBoxFlat, etc.).
- Start/Exit on title + Menu button in-game are functional.
- Core loop (order → drop container → open for organs → feed pet → evolve) should work with placeholder shapes.
