# Eldritch Aquarium

**An Uncanny Mercantile incremental economy sim**  
Built in Godot 4.x — [GitHub Repo](https://github.com/Darkgecko777/EldritchAquarium)

## Overview
Run a shady home aquarium experimenting with exotic, mutation-inducing fish food ordered through vintage comic ads. Your tank starts with a perfectly ordinary goldfish. Feed it the "special stuff," watch it mutate and evolve, manage Pollution and its health, and push specimens to their breaking point for permanent upgrades via prestige.

**Core Fantasy**: Ordinary aquarium pets mutate into tentacled horrors after consuming exotic feed. Every run is a fresh experiment that ends in glorious, inevitable death — fueling your shady research through prestige resets. The horror (and humor) is in what normal pets become.

**Target**: Short-to-medium sessions with meaningful active tending, strategic depth, and high replayability via distinct starter builds.

## Core Loop (Initial Run to First Prestige)
1. Title screen is the comic feed catalog ad → Click to order your first exotic feed shipment (or use in-tank catalog).
2. Exotic food drops into the tank (mixed sizes/qualities with controllable RNG). A normal goldfish is already swimming in the tank.
3. **Active Tending**: The goldfish auto-consumes preferred sizes; **hover over released resource globs** (Insight/Biomatter) to collect (no click needed). Player holds on the Goldfish (accelerates hunger/mutation rate), on food (speeds decay for Pollution generation), on the Remora (speeds cleaning), or on Minnow spawner to drive mechanics. Mismatches rot → Pollution.
4. The specimen mutates and evolves through 5 stages (10 total choices) via consumption. It starts as a completely normal aquarium goldfish; evolutions add visible mutations.
5. Pollution builds (on eat and decay, size-relative) and dampens gains → comics warn you → specimen loses HP from hunger/Pollution/stress and eventually dies at 0 HP.
6. Spend **Forgotten Mnemonic Fragments** in the main prestige tree to improve feed shipments, mutation speed, Pollution tolerance, unlock new normal starter species, etc.
7. Reset → Fresh normal goldfish + new mutation paths. Scale higher.

## Key Features
- **3 Starter Playstyles** (one per run, RNG after unlocks):
  - **Freaky Goldfish** – Aggressive medium-food pusher. Starts as a perfectly normal goldfish; mutates aggressively.
  - **Abyssal Minnows** – Chaotic small-bit swarm (starts as normal minnow school).
  - **Remora Horror** – Stable large-food Pollution converter. Starts normal; player holds to accelerate cleaning with stress risk at 0% Pollution. Dies at 0 HP.
- **9 Total Specimens** across Starters / Boosters / Interactors. All begin visually as ordinary aquarium pets.
- **5-Stage Evolutions / Mutations** (2 choices per stage) — reset on prestige. Visual transformation is the core fantasy.
- **Active + Idle Balance**: Hover collection for globs early, prestige unlocks more automation.
- **Comic-Driven Narrative**: 4-panel scientist banter at thresholds — escalating madness and humor as mutations progress.
- **No Lose States**: Suboptimal play just shortens runs and accelerates Fragments.

## Resources
- **Eldritch Insight** – Shipments & actions.
- **Abyssal Biomatter** – Growth & evolutions.
- **Forgotten Mnemonic Fragments** – Prestige spending.
- **Pollution** – Global dampener that pressures resets.

See:
- [Game_Vision.md](Game_Vision.md)
- [Resources_Economy.md](Resources_Economy.md)
- [Pets.md](Pets.md)
- [Shop.md](Shop.md)
- [DESIGN_HISTORY.md](DESIGN_HISTORY.md)

**Play the initial loop**: Launch → comic feed catalog title → enter tank with normal goldfish already present → use bottom catalog or SPACE to order feed shipments → watch autonomous eating, click globs, hold to tend → evolve/mutate the fish through stages → it will die from mismanagement → collect Fragments on death. Prestige (when wired) resets to a fresh normal specimen with upgrades.

## Development Status
- Initial loop (title ad → normal goldfish in tank → order exotic feed → autonomous eating + holds → mutation evolutions → death at 0 HP → Fragments) is the current focus.
- No egg/hatch sequence (tank starts with a formed normal goldfish).
- Theme: Ordering exotic pet food/supplements that drive mutations (not acquiring exotic pets).
- Core systems (consumption, shipments as feed, Pollution on eat+rot, globs) in place; active player hold tending, full HP/death, and multi-stage visible mutations next priorities for the loop.
- Next after initial loop solid: Prestige tree + remaining specimens.

**Playstyle Goal**: Fast aggressive Fragment farming vs. careful long stable runs vs. chaotic volume management.

Join the experiment. The tank is waiting... and it's getting hungry. 🐟🌊🐙