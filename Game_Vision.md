# Game Vision - Eldritch Aquarium
**Version**: 1.3 (Universal Pet Acquisition via Ad + Strict Eating-Only Economy)  
**Date**: 2026-06-05  
**Brand**: Uncanny Mercantile

## Core Fantasy
You run a shady interstellar pet supply business under the Uncanny Mercantile brand. All pets are acquired exclusively through the comic book "order" interface (starting as a "Sea Monkey" kit ad). The first pet arrives as an egg that hatches into a larval critter after a short incubation (accelerated by food arrival). Future pets are gated behind development conditions but still ordered through evolving versions of the same ad/catalog page. While your pets autonomously collide with and consume organs in the tank, they generate Eldritch Insight and other resources. The more you scale, the weirder, more powerful, and reality-bending they become. The tank is your ever-expanding storefront and laboratory in the void.

**Tone**: Playful uncanny horror with light humor. Madness effects are fun and mechanically useful rather than punishing.

## Core Gameplay Loop
1. **The Ad / Order Screen** — All pet acquisition happens through the comic book advertisement / catalog page (TitleScreen for the first pet; dynamically updated version for subsequent pets and continuing runs).
2. **The Egg (First Pet)** — Clicking "order" drops a special egg. It hatches after a variable incubation period (base ~30s, reduced by food/organs arriving in the tank) into the Sea Monkey larva.
3. **Unique Starter Food** — The complimentary shipment releases unique starter "incubation packets" (not standard organs) that the larva is attracted to.
4. **Autonomous Collision Eating** — Pets (starting with the larva) are drawn to food. Consumption requires multiple collisions (e.g. 3-4 for larva). Only successful eating generates resources.
5. **Resource Generation from Eating** — Eldritch Insight (and occasionally secondary resources) is produced only when pets collide-eat. Different pets/species/stages can yield different quantities or types via RNG for variety and replay.
6. **Growth & Evolution** — Pets progress through stages, unlocking better yields, new abilities, and weirder visuals.
7. **Order More** — Once conditions are met, use the (evolving) ad/catalog interface to acquire additional gated pets.
8. **Manage & Optimize** — Spend generated Insight on more orders/shipments/upgrades, balance Pollution, enjoy madness events.
9. **Scale** — Prestige for cosmetic tank layers and bonuses.

## Key Interaction Model
- **Player primarily interacts with UI**: The comic ad / "Order Specimen" catalog page (the primary way to acquire every pet), shipment orders, upgrades, etc. The title screen serves this role and changes dynamically based on run state (full sales-pitch ad for brand new games; catalog updates, "re-stock exotic specimens," or tank-status comic panels for continuing games after the first hatch).
- **Tank is strictly autonomous for economy**: Pets swim, seek, and collide-eat on their own. **All Insight and resource generation happens exclusively here** — no direct collection or external grants.
- **Limited direct clicks in tank**: Mainly shipping containers (to open and release food). The egg and starter packets are for the opening tutorial only.
- Food arrival (from any container) during an active egg incubation actively reduces the hatch timer, making the complimentary shipment mechanically useful for speeding up your first pet.

## Opening Sequence (The Comic Book Ad Experience)
This is the signature first impression, tutorial, and the permanent method for acquiring every future pet.

- The game launches into (or the TitleScreen *is*) a full-page retro comic book advertisement in the "ACME Void Supply Co." / classic Sea Monkeys mail-order style.
- Prominent call-to-action: **"ORDER YOUR SEA MONKEY KIT — CLICK HERE!"** (thematically cheap or "free with cosmic shipping" for the first one).
- Clicking the button in the ad causes the **egg** to physically drop into the tank view (smooth transition or the ad is the background of the tank area for the first run).
- A comic-style incubation indicator ("INCUBATING... 30s", progress bar, or twitching egg visuals) counts down. The base time is approximate/arbitrary (~30s); **arrival of food in the tank reduces the remaining timer**.
- A second prominent element (or revealed panel) offers the **complimentary shipment** — a one-time zero-cost container that drops, is clicked open, and releases **unique starter incubation packets** (special "Sea Monkey food" items created just for the opening — not standard random organs from later shipments).
- When the timer hits zero (or is accelerated to zero), the egg hatches with a satisfying effect into the weird larval Sea Monkey critter.
- The larva demonstrates the core loop immediately: drawn toward the unique starter packets. Multiple collisions (e.g. 3–4) are required before consumption. On successful eat: comic "MUNCH!" / impact VFX + resource generation popup.
- **Critical rule**: Resources (primarily Eldritch Insight) are generated *only* by pet collision-eating. The starter packets exist solely to bootstrap this first demonstration.
- After the first successful eats, the player has Insight to spend on normal (paid) shipments via the same ad/catalog interface, which now transitions into ongoing "order more specimens" mode.
- For subsequent pets (once development conditions are met): the title/catalog page updates its pitch ("Now with more tentacles!", "Exotic Void Variants now available!", current tank comic summary) but uses the same core "order → egg → hatch" flow. The title screen content changes dynamically for players returning to an existing run (no more the brand-new "first kit" sales pitch; instead a "replenish your stock" or "expand your collection" catalog page consistent with the comic aesthetic).

The entire experience — first run and ongoing — reinforces that the comic ad is the storefront and every pet literally comes from ordering out of the page.

This sequence teaches physical delivery, autonomous collision-based eating as the sole economy engine, timer interaction with food arrival, and the universal acquisition method.

## Key Systems

### Visual Style
- Single persistent **underwater tank** view (side-view with vertical expansion potential).
- Prestiges add cosmetic layers (sunken castles, deep-sea diver statues, eldritch coral, sunken ships, etc.).
- Vibrant yet eerie aesthetic with particles, bubbles, water distortion, and glowing effects.

### Economy & Resources
- **Four Core Resources**: Eldritch Insight (shipments/upgrades), Abyssal Biomatter (pet growth/evolutions), Forgotten Mnemonic Fragments (prestige), Pollution (dampening risk/reward).
- Pollution accumulates from consumption with compounding, slows all gains at high levels → prompts prestige.
- Madness as hidden meta-resource driving event frequency.
- Multiple currencies with clear roles and pet-driven loops.

### Pets
- Central focus. **Every single pet is acquired through the comic book ad / "Order Specimen" catalog interface** (the TitleScreen for the first; an updated, state-aware version of the same screen for all future acquisitions and for continuing existing games).
- The very first pet is always the "Sea Monkey" larva hatched from the initial ad egg + unique starter packets.
- Future pets are gated behind development conditions (examples: total Eldritch Insight earned, number of successful evolutions, specific organ types consumed, pollution level reached, rare mutations witnessed, etc.). Gating keeps the ad exciting as new "catalog pages" or "exotic imports" unlock.
- All pets start in larval form (Sea Monkey is the iconic starter) and evolve through juvenile → mature → eldritch stages with increasingly grotesque yet playful comic-book visuals.
- Active behaviors: swimming, seeking food via attraction, repeated collisions to eat (larval stage makes the "learning" collisions especially prominent and charming), pet-specific resource yields on consumption (RNG variance), synergies, special abilities, and madness interactions.

### Pollution & Madness
- Pollution ramps with activity and acts like "high-speed aquarium maintenance."
- Triggers humorous events (helpful glitches, UI gags, bonus resources).
- Mitigation through specific upgrades and certain pets.

### Madness Mechanics
- Humorous fourth-wall breaks, visual gags, and quirky events.
- Triggered by Madness tracker (scales with progress/Pollution).
- Revealed primarily through 4-panel comic pages: scientists becoming progressively more alien as thresholds crossed.
- Temporary mechanical effects that are fun/absurd and mechanically useful where possible.

### Progression & Prestige
- **Single tank** that visually evolves with prestige tiers.
- Each prestige grants a new themed cosmetic pack + global mechanical bonuses.
- Creates satisfying visual progression while keeping the core playspace simple.

## Design Goals
- Addictive "one more shipment" incremental gameplay.
- Strong visual feedback and juicy autonomous tank activity.
- Accessible but deep strategic choices (resource allocation, pollution management).
- Anti-stall activities: monitor pollution, plan upgrades, watch evolutions, trigger small madness events.

## Success Criteria
- Core loop satisfying within first 10 minutes.
- Tank feels alive and reactive.
- Players excited to prestige for new visual layers and stronger bonuses.

## Art Direction
See **Art_Direction.md** (primary reference for all visual assets, UI, and comic book style).

**Summary for Implementation**:
- Retro comic book advertisement / Sea Monkeys aesthetic with eldritch horror twists.
- UI is fully integrated as part of the fantasy (comic panels, catalog pages, vintage ads).
- This style is central — it influences mechanics like madness events (speech bubbles), shop presentation, and prestige cosmetic layers.
This document is the living source of truth.