# Design History - Eldritch Aquarium

**Purpose**: Scannable record of key decisions, pivots, and state across development sessions.  
Especially useful when new sessions start with fresh context but the codebase is at a known git state.

This complements:
- [Game_Vision.md](Game_Vision.md) — the living "what we want to build" design.
- [SCAFFOLDING_NOTES.md](SCAFFOLDING_NOTES.md) — practical "how to run / current implementation notes + immediate todos".
- [Assets.md](Assets.md) — asset priorities.

Keep entries **brief**. Focus on *why*, major choices, and what was working at the time. Date + short title.

## 2026-06 (Pivot): No Egg / Normal Goldfish Start + Exotic Feed Mutation Theme (Initial Loop Focus)
**What was added/changed**:
- Major theme pivot: Game is now about ordering **exotic pet food / mutation-inducing supplements** through comic ads, not acquiring exotic pets. All specimens (starting with Goldfish) begin as **perfectly normal, ordinary aquarium pets**. They mutate and become eldritch horrors as they consume the feed across evolution stages.
- Removed egg, hatch timer, incubation, "Sea Monkey kit", and larval start from the initial loop. New runs now start with a **fully formed normal goldfish already present** in the tank the moment you enter from the title/catalog ad.
- Rethemed language across docs and code: "shipments" → exotic feed orders, "organs" often called feed/pellets/supplements/chunks in prose, "pets" often "specimens" in high-level descriptions. Starter packets reframed as complimentary "sample mutation primer" feed for the first run.
- Updated Game_Vision.md (to 1.6), Readme.md, Shop.md (to 1.3), Art_Direction.md, SCAFFOLDING_NOTES.md, and this history. TitleScreen ad pitch, button text, and dynamic content shifted to feed catalog. AquariumController simplified (egg path bypassed for standard new runs; direct normal goldfish spawn + rethemed intro comic).
- Initial loop emphasis: Title (comic feed ad) → Tank with normal goldfish + bottom catalog → Order feed → Autonomous collision eating + globs → Consumption drives mutations/evolutions → Pollution/HP pressure → Death yields stage-scaled Fragments → (future) prestige reset to fresh normal specimen.

**Rationale**: Egg/hatch created a wait that distanced the player from the mutation fantasy. Starting with a normal, active goldfish + immediate ability to order feed makes "watch ordinary become extraordinary" immediate and visceral. The comic catalog aesthetic remains core (now as a shady exotic fish food supplier). This tightens the "game start to first prestige reset" loop for focused iteration.

**State at end of work**:
- Docs fully reflect the change. Code has the no-egg direct spawn path as the primary flow (old egg/ opening code remains but is not exercised for new runs). First food drop can still use the special STARTER_* types for visual distinction (now "sample feed").
- Playable: Ad click → normal goldfish in tank → order food via catalog/SPACE → eating + resource globs work → death path (pollution threshold) grants Fragments.
- Next immediate for loop completeness: Hold interactions, real HP + varied death, visible stage mutations on the goldfish primitive, eat-path pollution, and wiring a simple prestige/reset that returns you to a fresh normal goldfish.

**References**:
- Direct user request in this session to shift theme and remove egg for better iteration on the initial loop.
- Aligns with prior autonomous + comic ad foundation while dropping the Sea Monkeys egg acquisition model.

**Rationale**: Stronger player agency to "drive the mechanics" while keeping the autonomous collision-eating economy as the core engine. Remora becomes a high-skill, high-attention Pollution processor with clear risk (self-damage on empty tank) instead of a passive meter. Stage-scaled shards + multipliers tighten the early loop and make evolution feel immediately rewarding for prestige progress. HP opens future design space for hostile inter-pet interactions.

**State**: Vision documents now fully reflect the 8 requested adjustments. No Overburden language remains in active descriptions. Ready for implementation phase (hold input handling, HP tracking + depletion, accelerated timers on Pet/Organ/Spawner, pollution math on eat path, evolution multiplier application in register_pet_consumed_organ, Remora stress logic, Minnow spawner entity, shard scaling on death).

**References**:
- Direct user request in session (the numbered 1-8 points).
- Aligns with prior autonomous + collision-eating foundation (Pet.gd hunger_timer + InteractArea, Organ size_category + decay bar + _decay_and_rot, GameManager register_pet_consumed_organ).

## 2026-06-08: Starter Trio + Consumption Loop Lock
**What was added/changed**:
- Locked 3 starters with full 5-stage/2-choice evolutions (Goldfish, Minnows, Remora with Overburden).
- Active consumption: starter-matched shipments, player click collection, rot → Pollution.
- One starter per run (RNG after unlocks), prestige tree as central upgrade hub.
- Death always inevitable if unmanaged.

**Rationale**: Strong distinct playstyles, meaningful active layer, iteration-friendly foundation.

**State**: Starters fully designed. Ready for prestige tree + remaining pets.

## 2026-06-05: Resource Lock & Pollution/Madness Refinement

**What was added / changed**:
- Locked 4 resources: Eldritch Insight, Abyssal Biomatter, Forgotten Mnemonic Fragments, Pollution.
- Pollution: Dampener on gains (no subtraction), compounding from food, nudges prestige.
- Madness: Hidden meta for goofy event rate; communicated via alien scientist comics + visuals.
- Onboarding: Comic ad → first pet + food bundle; threshold-based 4-panel comics for progression guidance (no explicit tutorial).
- Pet evolutions: Mutually exclusive paths with production vs. cleaning trade-offs.

**Design Decisions & Rationale**:
- 4 resources strike balance between depth and clarity.
- Pollution as soft dampener maintains player agency and optimization feel.
- Comic-driven reveals ensure intuitive progression and strong narrative immersion.

**State at end of work**:
- High-level systems fully defined. Ready for resource manager implementation + comic integration stubs.

## 2026-06-05: Universal Ad Acquisition, Strict Eating-Only Economy, Dynamic Title, Food-Accelerated Hatch

**What was added / changed**:
- **All pets** (first and every future one) are acquired exclusively via the comic book "order" ad/catalog page. The first uses the classic "Sea Monkey kit" sales pitch + egg. Later ones are gated behind development conditions but use the same flow (egg drop → hatch).
- Title screen *is* the ad for brand-new runs. For continuing games (after first hatch or on load), it dynamically changes to vibe-consistent catalog updates ("Re-stock your tank!", current pets as comic panels, new exotic offers unlocked) instead of repeating the first-kit pitch.
- **Resources (Insight + secondaries) are generated ONLY by pet collision-eating**. No grants from organ pickup, direct player actions, or anywhere else. Pet variety provides RNG in yields (different pets produce different quantities/types for flavor and strategy).
- Starter "organs" for the first hatch are **unique** items created just for the opening/complimentary shipment (special incubation packets, not the standard random organs from later containers).
- Egg hatch timer (~30s base, arbitrary) is reduced by the arrival of food in the tank. Ordering/ opening the complimentary shipment during incubation now has a direct mechanical benefit on hatching speed.

**Design Decisions & Rationale**:
- Making the ad/catalog the *only* way to get pets turns the title screen into core gameplay UI rather than a throwaway menu. It keeps the comic aesthetic central forever.
- Dynamic title content for ongoing runs prevents repetition while staying in the "shady catalog in the void" fiction (no jarring switch to a generic menu).
- Strict "only pets produce resources by eating" makes the autonomous tank the literal economy engine and creates nice differentiation (a "greedy" pet vs. an efficient one, or eldritch forms that occasionally spit out premium resources).
- Unique starter packets keep the very first experience special and tutorial-focused without polluting the general organ system.
- Food reducing the hatch timer makes the "complimentary shipment" feel generous and interactive instead of just flavor during a dead wait.

**State at end of work**:
- Game_Vision.md updated to v1.3 with revised Opening Sequence, Core Loop, Economy (strict only-from-eating + pet variance), Pets (universal ad acquisition + gating), and Key Interaction Model (title dynamism + timer acceleration).
- DESIGN_HISTORY now documents the refinement on top of the 2026-06-04 ad + autonomous entries.
- **Prototype now implements the first few moments**:
  - TitleScreen button ("ORDER SEA MONKEY KIT" for fresh) triggers pending flag + load.
  - Aquarium detects and runs full opening: egg drops from top with tween + pulsing comic "INCUBATING" label + timer bar.
  - Order button repurposed to "CLAIM COMPLIMENTARY SHIPMENT (FREE!)" → drops container with exactly 2 unique STARTER_PRIMAL + STARTER_VOID packets (distinct green/purple visuals).
  - Food arrival reduces egg timer (mechanically useful complimentary).
  - On hatch (or reduced to 0): larva "Sea Monkey" spawns, configured LARVAL + eager.
  - Pet now has real autonomous seek-to-food + collision counting (4 bumps for larva) → eat removes food, calls register_pet_consumed_organ (the *only* Insight source), floating "MUNCH!" comic text, growth.
  - After hatch, UI restores to normal paid orders; T key returns to title showing dynamic "ORDER MORE SPECIMENS" + catalog footer.
  - Legacy paths neutralized for economy; floating text helper, starter visuals, etc.
- New files: Egg.gd + Egg.tscn (primitive but fully functional for the sequence).
- Still no full gating or multiple species, but the core "ad → egg → wait+food → hatch → autonomous eat for Insight" is playable end-to-end with primitives.

**References**:
- Direct user clarifications building on prior comic ad + autonomous vision.
- Keeps strong alignment with Art_Direction.md (comic catalog is now the persistent acquisition UI).

---

## 2026-06-04: Comic Book Ad Opening Sequence + Eldritch Insight as Foundational Currency

**What was added / changed**:
- The game now *opens* as a literal vintage comic book page advertisement for a Sea Monkey kit.
- First action: click the ad button → egg drops into tank.
- ~30 second real-time hatch timer for the first "weird larval critter" (Sea Monkey larva).
- During incubation: player can trigger a one-time **complimentary shipment** (free container drop) that provides the initial two basic organs.
- Feeding for the larva is fully autonomous and collision-driven: the pet is attracted to organs; an organ is consumed only after 3–4 collisions.
- **Eldritch Insight** is established as the basic earned currency generated by successful pet consumption. This is what you spend on future orders/shipments.

**Design Decisions & Rationale**:
- The comic ad + egg wait creates strong "the catalog is real" fantasy and a built-in moment of anticipation that makes the first autonomous feeding moment magical rather than abstract.
- "Complimentary shipment" is a brilliant low-stakes way to introduce physical container delivery + organ release while the player is waiting on the hatch.
- Requiring multiple collisions for the baby creature sells the "it's learning / it's a baby" feel and makes the autonomous system visible and charming from minute one.
- Eldritch Insight earned *by the pet acting* rather than direct player clicking inverts the usual "you feed the pet" loop into "the pet works for you in the tank."
- Keeps early game extremely focused (one larva + two organs) so the core fantasy teaches itself.

**State at end of work**:
- Game_Vision.md updated to v1.2 with dedicated "Opening Sequence (The Comic Book Ad Experience)" section.
- Art_Direction.md already locked the retro comic / Sea Monkeys visual language that this opening depends on.
- Current prototype code (direct clicks, Biomass primary, instant collection) is now noticeably behind this vision and will need targeted updates (egg entity or special Pet spawn, attraction steering on larval Pet, collision counter + consume on N hits, new ResourceType.ELDRITCH_INSIGHT, TitleScreen or new scene as the ad page, complimentary shipment special case in GameManager).

**References**:
- User's direct clarification in session.
- Aligns with prior 2026-06-04 autonomous tank and art direction entries.

---

## 2026-06-04: Dedicated Art Direction & Comic Book Aesthetic

**Major Addition**:
- Created standalone **Art_Direction.md** as the single source of truth for visual style.
- Locked in retro comic book / Sea Monkeys mail-order catalog aesthetic as core identity.
- UI is now treated as an active part of the world (comic panels, ad-style shop, speech bubbles).

**Rationale**:
- Comic style is AI-asset friendly, highly distinctive, and perfectly matches the Uncanny Mercantile tone.
- Strong integration between visuals and mechanics (UI as shady distributor catalog).
- Provides focused reference for asset generation sessions in this chat.

**Impact**:
- First 5 minutes now framed as a comic book ad experience.
- Future mechanics (madness, prestige decorations, shop) will springboard from this aesthetic.

## 2026-06-04: Autonomous Tank & Interaction Refinements

**What was added / changed**:
- Shifted to primarily autonomous tank behaviors (organs drawn to pets, pets actively seek food).
- Player interaction model locked to UI buttons + container clicks only.
- Pollution introduced early with visible effects and risk/reward.
- Prestige redefined as single tank receiving new cosmetic layers (ornamental structures, divers, etc.) tied to permanent bonuses.
- Emphasized resource allocation decisions between shipments and upgrades.

**Design Decisions & Rationale**:
- Autonomous behaviors reduce physics/click-detection complexity in Godot while making the tank feel alive and satisfying to watch.
- Single tank + cosmetic prestige layers gives strong visual progression without complicating the playspace.
- Early pollution creates immediate decision-making and ties into the "legitimate aquarium in high speed" fantasy.
- Maintains idle-friendly pacing with other activities to pivot to during waits.

**State at end of work**:
- Vision now tightly aligned for Grok Build implementation.
- Ready for next implementation phase focused on AquariumController refinements.

---
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

This entry (2026-06 pivot) locks the "normal goldfish + exotic feed drives mutations, no egg" direction for all subsequent work on the initial loop to first prestige.

This file should stay short — aim for 1-2 screens of text even after many sessions. Detailed design lives in Game_Vision.md; implementation notes in SCAFFOLDING_NOTES.md.