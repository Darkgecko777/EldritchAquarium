# Game Vision - Eldritch Aquarium
**Version**: 1.6 (No-Egg Food-Mutation Theme + Normal Goldfish Start)  
**Date**: 2026-06 (updated for initial loop focus)  
**Brand**: Uncanny Mercantile

## Core Fantasy
You run a shady home aquarium operation experimenting with exotic, mutation-inducing fish food. Order "special blends" and suspicious supplement shipments through vintage comic book ads. Your tank begins with an ordinary, fully-formed goldfish (or other normal aquarium pet). As it consumes the exotic feed it mutates, grows, and evolves through increasingly bizarre stages. Manage resources (Insight from consumption, Biomatter for growth), balance Pollution, and scale through prestige resets when your specimen inevitably dies. Every run ends in death (via HP depletion from Pollution, prolonged hunger, or stress) that fuels Fragments and permanent upgrades to future shipments and tolerance.

**Tone**: Playful uncanny horror with light humor. Madness events are fun and useful. The horror comes from what ordinary pets become after eating the "good stuff."

## Core Gameplay Loop
1. **Comic Ad / Shipment** → Order exotic feed shipment (themed drops with controllable size/rarity mix via prestige).
2. **Exotic Food Drops** → Mixed sizes (small/medium/large "pellets", "supplements", "chunks") with RNG (60-85% preferred via prestige).
3. **Active Tank Tending** → The goldfish (and future specimens) auto-consume matched sizes; player hovers over released resource globs to collect them (no click required). Player can **hold the mouse button** on the Goldfish (accelerates its hunger → faster consumption and mutation progress), on food (speeds decay, generating Pollution "clouds" for pollution-processing pets), on the Remora (speeds Pollution consumption), or on the Minnow spawning item (speeds new minnow production). Mismatches lead to rot → Pollution.
4. **Mutation & Evolution** → Consumption-gated (5 stages, 2 choices each). The specimen starts as a perfectly normal aquarium goldfish. Evolutions apply visible mutations and grant resource production multipliers. Starter evolutions reset on prestige.
5. **Pollution Management** → Dampens gains; high levels trigger comics and death.
6. **Prestige/Reset** → Via Fragments from specimen deaths + set completions. Spend in main upgrade tree (better feed shipments, faster mutations, Pollution tolerance, unlock new normal starter species, etc.).
7. **Discovery** → RNG feed shipments, comic panels with alien scientists commenting on the mutations, madness events.

## Key Systems

### Resources (4 Core + Meta)
See **Resources_Economy.md**.

### Shipments & Consumption
- Starter-matched themes with prestige-improved ratios (60/40 base → 85/15).
- Player clicks released Insight/Biomatter globs.
- Pollution is added relative to food size both when eaten (by pets) and when it decays/rots.
- Rot releases partial resources but spikes Pollution (size-scaled).
- Remora: Large preference + player-directed Pollution processing. Hold to accelerate consumption; attempts to feed at 0% Pollution cause stress and HP loss (faster when player-directed). No Overburden meter.

### Pets & Evolutions (Specimens & Mutations)
- **One Specimen per Run** (starts as a perfectly normal Goldfish; RNG unlocks for other ordinary aquarium species after prestige).
- **9 Total Specimens** in 3 categories: Starters (tone-setters that mutate uniquely), Boosters, Interactors.
- **5 Stages × 2 Choices** (10 decisions). Consumption-based thresholds (reduced by prestige tree). The fish begins visually as a standard cute/normal goldfish. Each evolution stage adds visible mutations (extra fins, eyes, color shifts, tentacles, etc.).
- Specimens have **HP** (Goldfish starts at 5, Remora at 3, 1 per Minnow). Dynamic hunger and Pollution (for some) can deplete HP, enabling more varied death and future hostile interactions.
- Evolution grants a **default multiplier** to resources produced via future consumption (some paths multiply it further).
- Specimens grant **Mnemonic Fragments** on death scaled to their reached evolution stage (plus bonuses). Consequence: the initial play loop is tuned to fit in roughly one Goldfish evolution (or a bit more with good play) before a natural reset/death fuels early prestige progress.
- Full details in **Pets.md**.

### Prestige & Main Upgrade Tree
- Fragments from pet deaths + set completions.
- Central tree unlocks shop improvements, Pollution tolerance, evolution speed, starter RNG, multi-pet scaling, etc.
- Resets pet states for fresh evolution paths.

### Comics & Madness
- Threshold-triggered 4-panel scientist comics guide progression and show escalating madness.
- Hidden Madness tracker drives goofy events and visuals.

### Direct Interaction / Hold Mechanics (Player-Driven Rate Manipulation)
The core loop is primarily autonomous (pets seek and collide-eat), but the player has meaningful **hold interactions** to drive pacing and strategy:
- Hold on **Goldfish**: Increases its hunger rate, causing faster food-seeking and higher overall consumption rate.
- Hold on **uneaten food/organs**: Accelerates the decay timer (visual decay bar speeds up). Essential to rapidly generate Pollution clouds that the Remora can process.
- Hold on **Remora**: Increases its Pollution consumption/processing rate.
- Hold on **Minnow spawning item**: Accelerates the timer that produces additional minnows. Individual Minnows themselves cannot be interacted with.
These holds trade player attention for faster resource/Pollution cycles and are the primary way the player "tends" the living tank beyond collecting globs.

## Design Goals
- Active but forgiving tank tending.
- Distinct playstyles per starter.
- Clear progression via comics/tree without tutorials.
- Strong replay via resets and builds.

**References**: Resources_Economy.md, Pets.md, Shop.md, DESIGN_HISTORY.md.

**Initial Loop Focus (to first prestige reset)**: Title (comic feed catalog ad) → Tank with normal goldfish already present → Order first exotic feed shipment(s) via bottom catalog or input → Autonomous eating + player holds for pacing → Visible mutations on evolutions → Pollution and HP pressure build → Death at 0 HP yields stage-scaled Fragments → Prestige tree spend → Reset to fresh normal goldfish + upgraded feed options. No egg, no hatch wait. The mutation fantasy is front-and-center from minute one.