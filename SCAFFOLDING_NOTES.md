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
- Enums are in `scripts/data/enums.gd` (use `GameEnums.ResourceType.ELDRITCH_INSIGHT` as the primary basic currency per v1.3 vision — **generated exclusively by pet collision-eating**; BIOMASS is legacy/bridge. Unique starter "incubation packets" for the first egg are distinct from normal organs. Make sure `enums.gd` has `class_name GameEnums`).
- GDScript is hot-reload friendly and has lower friction for Godot-specific features (signals, tweens, etc.).

When opening the project, assign the PackedScene exports on the Aquarium root node (ShippingContainer.tscn, Organ.tscn, Pet.tscn, and optionally the legacy Egg.tscn) in the inspector if they are not set. The egg path is no longer used for the standard initial loop.

### Running
1. Open in Godot editor (any 4.6+ build is fine now — no .NET requirement).
2. Press F5. Changes to .gd are picked up instantly.

The visual style (all primitives) remains the same for now. The core loop is now "comic feed catalog ad → tank with normal goldfish present → order exotic feed shipments → autonomous eating + player holds → mutations via consumption/evolution → death yields Fragments for prestige." No egg/hatch. Strict "resources ONLY from specimen collision eating" is the rule. See updated Game_Vision.md and DESIGN_HISTORY for the pivot.

## Current Known Good State (Theme Pivot Applied)

- Title screen is the main scene and is the comic "exotic fish feed & supplements" catalog/ad for ordering mutation-inducing food. New runs use a fresh pitch; continuing runs show dynamic "re-stock" updates.
- All visuals use only Godot primitives (plus a few real icons for resources). No egg or hatch visuals in the standard path.
- Start/Exit on title + Menu (pause) button in-game are functional.
- **No egg / no hatch for initial loop**: New runs start directly with a fully formed, visually normal goldfish specimen already in the tank. The core fantasy is ordering exotic feed to cause mutations in an ordinary fish.
- Core systems in place for the loop:
  - 6-slot bottom feed catalog (BASE free+20s CD, SILVER, GOLD with tiered quantity + rarity).
  - Autonomous seek + collision eating (hunger_timer, bites_to_consume on feed items, register_pet_consumed_organ as the authoritative resource source via spawned globs).
  - Clickable ResourceGlobs that fly collected value to the HUD.
  - Feed items with size_category + 5 rarities, decay bar, size-scaled Pollution on rot.
  - Dynamic title/catalog behavior.
- **Playable initial loop (start to death/Fragments)**: Title ad click → Aquarium with normal goldfish present + catalog visible → Order feed (catalog clicks or SPACE) → Drops (including special starter sample feed for first run) → Goldfish autonomously eats (player clicks globs) → Consumption builds toward evolutions/mutations (scaffolded) → Pollution + health pressure → Death grants Fragments (via current threshold or improved HP path).
- Strict "resources generated only via specimen collision-eating" is enforced in the main paths.
- Legacy direct grants and old egg/opening code exist but are not part of the recommended initial loop flow.

**Important for running the current build (post-pivot)**:
- The ResourceDisplay shows Insight (primary, from eating), Biomatter, Shards/Fragments, and Pollution.
- To play the initial loop: Launch → Title comic feed catalog ("ORDER EXOTIC FEED" or similar) → enter tank. A normal goldfish is already present and swimming (no egg, no wait). Use SPACE or click the bottom catalog slots (BASE free with cooldown, SILVER/GOLD paid) to order exotic feed shipments. Food drops, goldfish autonomously seeks and collision-eats (bites required per piece), click the released globs to collect resources (they fly to HUD). Hold mechanics (when implemented) let you accelerate hunger on the fish or decay on uneaten food. Watch consumption drive evolution/mutation stages. Pollution builds; mismanagement leads to death and Fragments.
- Press T in the tank to return to Title and see dynamic catalog updates.
- MENU button pauses or returns to title.
- Right-click is legacy/debug (adds Biomatter; does not generate core Insight).
- order_shipment costs Insight first (with Biomatter fallback). Starter sample feed for the very first drop uses special visual types (reframed as "intro mutation primer" packets).
