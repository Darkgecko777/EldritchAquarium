# Design History - Eldritch Aquarium

**Purpose**: Scannable record of key decisions, pivots, and state across development sessions.  
Especially useful when new sessions start with fresh context but the codebase is at a known git state.

This complements:
- [Game_Vision.md](Game_Vision.md) — the living "what we want to build" design.
- [SCAFFOLDING_NOTES.md](SCAFFOLDING_NOTES.md) — practical "how to run / current implementation notes + immediate todos".
- [Assets.md](Assets.md) — asset priorities.

Keep entries **brief**. Focus on *why*, major choices, and what was working at the time. Date + short title.

---

## 2026-06-03: Initial Bootstrap & "Early Prototype Build"

**Context**: Fresh project start. High iteration, prototype stage. Expect many context resets.

**Major Decisions**:
- **Genre/Pitch**: Incremental "cosmic pet supply simulator" — shady interstellar PetSmart in the void. Brand: Uncanny Mercantile.
- **Core Fantasy** (from Game_Vision v1.0): Order shady shipments → physical containers drop into tank → unbox random organs → feed/evolve increasingly bizarre pets → manage economy + pollution risk/reward → prestige/scale.
- **Tone**: Playful uncanny horror + light humor. Madness effects should be fun/absurd (UI-eating pets, helpful glitches) rather than frustrating or purely grim.
- **Visual Style Pivot**: Main playspace is a **zoomed-in underwater tank** (physical side-view). Lab/ship elements de-emphasized to secondary UI or background.
- **Tech Stack**: Godot 4.6+ (Forward+). Started scaffolding with C# for structure, then **switched fully to GDScript**.
  - Why GDScript: Lower friction, excellent hot-reload, no .NET dependency or .csproj hassle, simpler signals/tweens integration, faster iteration in prototype phase.
- **Core Systems Skeletons** (all with primitive/ColorRect visuals so it's playable immediately):
  - `GameManager` (autoload singleton): resource tracking (Biomass, Void Essence, Sanity Shards, Pollution), `order_shipment()`, signals, run reset, stubs for save/prestige.
  - `AquariumController`: physical tank space, container spawning from top with tweens, click-to-open, organ collection, simple "held organ" drag-to-feed primitive, pet management wiring.
  - `ShippingContainer`, `Organ`, `Pet` entities with basic behaviors (drop, float, swim, growth thresholds, evolution).
  - `ResourceDisplay` HUD + pollution bar.
- **Resources & Risk**: Pollution as central mechanic (gained on actions, boosts growth, triggers "madness" flavor at high levels).
- **MVP Loop Verified Playable**:
  - Title screen → Aquarium.
  - SPACE / button → order shipment (costs Biomass) → container drops physically.
  - Click container → releases 2-3 organs.
  - Click organs → collect (gain Biomass + pollution).
  - Click/feed pet → grows, eventually evolves (grants Void Essence).
  - Debug: right-click +Biomass, high pollution madness logs.
- **Known Good State** (end of session): Fully functional core loop with placeholders. Title + in-game menu functional. All logic GDScript. No real art, no shop UI, no persistence, no multiple pets/species yet.
- **Immediate Next Items** (from scaffolding): real background/water effects, sprite replacements (start with container + larval pet), draggable feeding, basic shop, save/load, more madness VFX, pet species variety.

**Commit**: "Early prototype build" (after "Initial Commit").

---

## Template for Future Entries

```
## YYYY-MM-DD: Short Descriptive Title

**What was added / changed**:
- Bullet key features or refactors.

**Design Decisions & Rationale**:
- Why this approach? Tradeoffs considered?
- Any pivots from Game_Vision or prior plan?

**State at end of work**:
- What is now playable / stable?
- Any known issues or scope cuts?

**References**:
- Links to relevant PRs, issues, or other docs if applicable.
```

---

**Maintenance**: Append new sections at the top (reverse chrono) when a session produces meaningful design or scope decisions. Update the "Current Known Good State" summary in SCAFFOLDING_NOTES.md when the playable bar moves significantly.

This file should stay short — aim for 1-2 screens of text even after many sessions. Detailed design lives in Game_Vision.md; implementation notes in SCAFFOLDING_NOTES.md.