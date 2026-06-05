# Resources & Economy - Eldritch Aquarium

**Version**: 1.1 (Post-Resource Lock)  
**Date**: 2026-06-05

## Core Resources (4 Locked)

### Eldritch Insight
- **Role**: Primary persistent currency. Used for ordering shipments, basic upgrades, and shop interactions.
- **Acquisition**: Mainly from pet activity (autonomous + manual feeding synergies).
- **Persistence**: Carries through prestige (with possible Pollution modifiers).
- **Theming**: Represents growing "awareness" or research data from the aquarium.

### Abyssal Biomatter
- **Role**: Primary production driver. Fuels pet evolutions, growth, and many upgrades.
- **Acquisition**: Generated/consumed by pets metabolizing food/organs from shipments.
- **Key Interaction**: Pets evolve based on cumulative Biomatter released/consumed.

### Forgotten Mnemonic Fragments
- **Role**: Prestige/meta currency. Spent on permanent bonuses, divergent evolution paths, and unlocking new madness/comic layers.
- **Acquisition**: Earned via tank upgrade thresholds and successful prestige runs.

### Pollution
- **Role**: Risk/reward dampener. Accumulates from food consumption with slight compounding.
- **Mechanics**:
  - Acts as global multiplier on resource gains: `effective_gain = base * (1 / (1 + pollution_factor))` (soft dampening).
  - High levels make play suboptimal → encourages prestige reset.
  - No direct subtraction from other resources on reset; instead influences carry-over Insight.
- **Pet Synergies**: High-output evolutions ramp Pollution faster; "cleaner" pets (e.g., sucker-fish style) reduce it but rely on main producers.
- **Theming**: Murky water, visual effects, madness triggers.

## Meta Resource: Madness
- **Role**: Hidden tracker controlling frequency/rate of goofy crazy events.
- **Visibility**: Not directly shown to player. Communicated via:
  - Increasingly alien scientist comic panels.
  - Adjusted visuals (e.g., intensified shaders, particle chaos).
  - Frequency of humorous fourth-wall/madness happenings.
- **Acquisition**: Scales with overall progress, Pollution levels, and certain pet evolutions.
- **Purpose**: Delivers fun discovery and replayability without punishing core loop.

## Design Principles
- Max 4 visible resources for clarity.
- Strong loops: Shipments (Insight) → Food/Organs → Biomatter (pets) → Pollution management → Prestige (Fragments).
- Mutually exclusive pet evolution paths create build variety.
- All tied to comic narrative reveals at thresholds.

This doc serves as quick reference for implementation and balancing.