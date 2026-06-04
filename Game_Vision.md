# Game Vision - Eldritch Aquarium
**Version**: 1.1 (Autonomous Tank Refinement)  
**Date**: 2026-06-04  
**Brand**: Uncanny Mercantile

## Core Fantasy
You run a shady interstellar pet supply business. Your ever-expanding underwater tank is the heart of the operation. Order suspicious shipments from the eldritch void, watch shipping containers physically drop into the tank, crack them open for random organs, and watch your cosmic pets actively hunt, consume, and evolve. The more you scale, the weirder, more powerful, and reality-bending your pets become.

**Tone**: Playful uncanny horror with light humor. Madness effects are fun and mechanically useful rather than punishing.

## Core Gameplay Loop
1. **Acquire** — Use UI buttons to order shipments (costs Biomass).
2. **Delivery** — Containers physically drop from the top of the tank.
3. **Unboxing** — Click landed containers to release random organs.
4. **Autonomous Feeding** — Organs float/sink and are drawn toward nearby pets (collision-based eating).
5. **Growth & Evolution** — Pets consume organs, grow, gain stats, and evolve when thresholds are met.
6. **Manage & Optimize** — Balance Biomass spending (shipments vs upgrades), monitor Pollution, trigger minor madness events.
7. **Scale** — Prestige for new cosmetic tank layers + permanent bonuses.

## Key Interaction Model
- **Player primarily interacts with UI**: Order shipments, buy upgrades, prestige, etc.
- **Tank is mostly autonomous**: Pets swim and seek organs on their own. Organs are attracted to pets.
- **Limited direct clicks**: Only on shipping containers (to open) and UI elements. This avoids click-detection issues with animated sprites.
- Optional future: Toggleable auto-collect or minor drag-to-feed.

## Key Systems

### Visual Style
- Single persistent **underwater tank** view (side-view with vertical expansion potential).
- Prestiges add cosmetic layers (sunken castles, deep-sea diver statues, eldritch coral, sunken ships, etc.).
- Vibrant yet eerie aesthetic with particles, bubbles, water distortion, and glowing effects.

### Economy & Resources
- **Biomass** (main currency) — spent on shipments and upgrades.
- **Void Essence** & **Sanity Shards** (prestige currencies).
- **Pollution** — introduced early (visible ~minute 3-5). Boosts growth/speed but increases madness frequency. Creates meaningful spending decisions (more shipments = faster pollution).

### Pets
- Central focus. Start as simple larvae, evolve into complex eldritch forms.
- Active behaviors: swimming, seeking organs, synergies, special abilities.

### Pollution & Madness
- Pollution ramps with activity and acts like "high-speed aquarium maintenance."
- Triggers humorous events (helpful glitches, UI gags, bonus resources).
- Mitigation through specific upgrades and certain pets.

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

This document is the living source of truth.