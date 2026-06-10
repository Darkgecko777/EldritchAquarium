# Pets & Evolutions - Eldritch Aquarium
**Version**: 1.2  
**Date**: 2026-06-09

## Evolution Rules (All Pets)
- 5 stages, 2 mutually exclusive choices per stage (10 total decisions per pet).
- Triggered by cumulative consumption (Biomatter + matched food processed).
- Prestige tree nodes dramatically reduce thresholds for faster fresh-run scaling.
- Starter evolutions fully reset on prestige (fresh builds every run).
- All starters strictly prefer one exclusive primary food size until evolutions open secondary access.
- **Pet HP**: Goldfish baseline 5, Remora 3, 1 per individual Minnow. Dynamic hunger conditions (prolonged max hunger without eating) and Pollution exposure (for sensitive pets) deplete HP over time. Reaching 0 HP causes death and grants stage-scaled rewards. This enables more dynamic hostile interactions between future pets.
- **Evolution Resource Multipliers**: Reaching a new stage provides a persistent default multiplier to resources (Insight + Biomatter) produced via that pet's future consumption. Some evolution choices multiply the bonus further or add conditional (e.g. size-matched) bonuses.
- **Stage-Scaled Mnemonic Shards on Death**: When a pet dies it grants Forgotten Mnemonic Fragments scaled to its reached evolution stage (base + current_stage factor) plus any path-specific bonuses. As a consequence, the initial play loop is tuned so a typical first-run Goldfish death occurs around the completion of its first evolution (providing meaningful early Fragments for the prestige tree before a full 5-stage run).

## Starters (One per Run – Goldfish default, RNG after prestige unlocks)

### 1. Freaky Goldfish (Aggressive Playstyle – Medium Food Preference)
**Baseline**: Solid Insight + Biomatter output. Moderate Pollution. Efficient on medium chunks; struggles with small/large.
**HP**: 5 (depletes from prolonged starvation/hunger and high Pollution exposure).
**Player Interaction**: The player can **hold the left mouse button on the Goldfish** to increase its hunger rate. This drives faster food-seeking and raises its food consumption rate (more eats per unit time). This is the primary direct way to push Goldfish output and growth.

**Stage 1 – Early Adaptation**  
- **A: Voracious Appetite** – Faster consumption speed + higher medium-chunk yield.  
- **B: Resilient Scales** – Slight Pollution tolerance + minor rot resource leak reduction.

**Stage 2 – Growth Spurt**  
- **A: Bulking Horror** – Large multiplicative Biomatter multiplier; increased Pollution output.  
- **B: Adaptive Palate** – Gains ability to eat **Small** food (reduced efficiency).

**Stage 3 – Behavioral Shift**  
- **A: Frenzied Feeder** – Temporary output bursts on big matched shipments; higher mismatch rot risk.  
- **B: Symbiotic Feeder** – Small aura that boosts nearby pets’ consumption efficiency.

**Stage 4 – Morphological Change**  
- **A: Tentacle Mass** – Extreme medium-chunk multipliers + visual tentacle swarm; high Pollution ramp.  
- **B: Expansive Jaws** – Gains ability to eat **Large** food (reduced efficiency).

**Stage 5 – Apex Mutation**  
- **A: Abyssal Devourer** – Global production multiplier + Madness event synergy.  
- **B: Sacrificial Specimen** – Releases **3 Forgotten Mnemonic Fragments** on death.

### 2. Abyssal Minnows (Chaotic Swarm Playstyle – Small Food Preference)
**Baseline**: Collective school (counts as 1 "unit" for certain death/Fragment prestige bonuses). Thrives on volume of tiny bits. Lower individual output that scales with school density. Visually chaotic.
**HP**: 1 per individual minnow (fragile; the swarm's total "health" is the sum of its members).
**Spawning Item**: Minnows arrive with a dedicated **spawning item** (a persistent timer-driven entity such as a breeding pouch, incubator node, or fractal coral). This item periodically produces new 1-HP minnows that join the school. The player can **hold the left mouse button on the spawning item** to speed up its production timer. 
**Minnows Themselves Cannot Be Interacted With**: Direct holds/clicks target only the spawner for acceleration. Individual minnows are autonomous swarm units and are not selectable for player rate manipulation. The spawner is the control point for population growth.

**Stage 1 – School Formation**  
- **A: Tight Schooling** – Faster collective consumption of small bits + minor global speed boost.  
- **B: Dispersal Instinct** – Better spread to catch scattered small bits; slight Pollution dilution.

**Stage 2 – Population Boom**  
- **A: Explosive Breeding** – More minnows = higher total output.  
- **B: Efficient Foragers** – Improved handling of medium food (secondary access).

**Stage 3 – Fractal Patterns**  
- **A: Swarm Frenzy** – Temporary massive output spike on many small organs; visual chaos + Madness tick.  
- **B: Symbiotic Cloud** – Small aura that helps other pets consume small bits faster.

**Stage 4 – Aberrant Forms**  
- **A: Cannibal Surge** – Converts uneaten/rotting small bits into extra Biomatter (rot mitigation).  
- **B: Adaptive Morphs** – Gains ability to eat **Large** food (slowly, high Pollution contribution).

**Stage 5 – Apocalyptic School**  
- **A: Fractal Overrun** – Extreme multipliers scaling with total pets in tank; high Pollution ramp.  
- **B: Eternal Shoal** – On death, splits into bonus temporary small organs + minor carry-over bonuses.

### 3. Remora Horror (Stable Cleaner Playstyle – Large Food Preference)
**Baseline**: Ignores normal food. Strictly prefers **Large** organs (big Pollution spikes on decay). Converts Pollution clouds into Insight + Biomatter. Low output without Pollution to process. 
**HP**: 3. The Remora experiences **stress** and loses HP when it attempts to feed on Pollution at 0% levels. Autonomous attempts cause 1 HP loss every 5 seconds of trying; player-directed consumption (see below) causes loss every 1 second. Death occurs at 0 HP (no separate Overburden meter). Ambient high Pollution is generally tolerated or even beneficial; the danger is a "hungry cleaner with nothing to clean."

**Player Interaction (Core Risk/Reward)**: The player can **hold the left mouse button on the Remora** to make it consume/process Pollution significantly faster. This is essential for high-output cleaning runs but carries real risk—if Pollution reaches 0% while the Remora is still trying to feed (auto or directed), stress/HP damage ticks much faster under player direction. Holding is a powerful but deliberate choice.

**Stage 1 – Attachment**  
- **A: Scavenger Instinct** – Bonus conversion rate/speed when consuming Pollution from recently rotted large organs.  
- **B: Stress-Adapted Gills** – Reduces HP loss rate from 0-Pollution feeding attempts; provides a small buffer before damage begins.

**Stage 2 – Hunger Expansion**  
- **A: Voracious Cleaner** – Faster Pollution munching + higher conversion rate.  
- **B: Efficient Symbiont** – Higher baseline conversion (Insight/Biomatter per unit Pollution processed) and lower stress generation when player-directed.

**Stage 3 – Symbiotic Defense**  
- **A: Aura of Purity** – Reduces global Pollution generation for all pets.  
- **B: Catalytic Release** – While processing Pollution (especially when player holds), occasional controlled micro-vents award bonus resources without adding net Pollution or extra stress.

**Stage 4 – Deep Adaptation**  
- **A: Reinforced Carapace** – Increased max HP (+2–3) and/or reduced HP drain from ambient high-Pollution exposure.  
- **B: Contagious Hunger** – Increases the hunger/consumption rate of nearby pets (unchanged from prior; still useful for synergies).

**Stage 5 – Eternal Purifier**  
- **A: Eldritch Siphon** – Dramatically increased Pollution processing throughput and yield when the player holds the Remora, but directed over-feeding at low/zero Pollution causes accelerated stress and HP loss. High reward, high player-skill risk expression. (Replaces prior vacuum that accelerated a removed Overburden meter.)
- **B: Final Purge** – On death (0 HP), instantly consumes a large portion of current tank Pollution and awards bonus Fragments scaled by Pollution level at the moment of death (or by lifetime Pollution successfully processed). Flavorful "goes out in a blaze of cleanliness" that still rewards good Remora play. (Replaces prior scaling by Overburden fullness.)

## Player Hold Interactions (Summary for All Current Starters)
- **Goldfish**: Hold LMB on the pet → accelerates hunger_timer → faster autonomous seeking and higher consumption rate.
- **Food / Organs**: Hold LMB on uneaten food → speeds its decay timer (decay bar visually accelerates). Primary method to rapidly generate Pollution "clouds" that the Remora consumes.
- **Remora**: Hold LMB on the pet → accelerates Pollution consumption/processing rate. Risk: zero-Pollution feeding attempts (auto or held) cause stress HP loss (1 HP / 5s autonomous, 1 HP / 1s while player-directed).
- **Minnow Spawning Item**: Hold LMB on the spawner (not on individual minnows) → accelerates the timer that births new 1-HP minnows into the school. Minnows themselves are non-interactable autonomous units.

These holds are the main active "driving" layer on top of the autonomous collision-eating economy. They make the player a direct participant in tuning hunger, rot, cleaning speed, and swarm growth.

## Remaining Pets (Boosters + Interactors)
[To be fully detailed next — high-level: 3 Boosters (Jellyfish, Axolotl, Anglerfish), 3 Interactors (Betta deathmatches, Cuttlefish, etc.)]

See **Game_Vision.md** and **Resources_Economy.md** for broader context.