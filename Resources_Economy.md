# Resources & Economy - Eldritch Aquarium
**Version**: 1.3  
**Date**: 2026-06-09

## Core Resources (4 Locked)
- **Eldritch Insight**: Shipments & basic actions. Persistent.
- **Abyssal Biomatter**: Pet evolutions & growth.
- **Forgotten Mnemonic Fragments**: Prestige tree spending & unlocks.
- **Pollution**: Dampener on gains (`effective = base / (1 + factor)`). Generated relative to food size both when pets eat and when food decays/rots. Nudges resets. Compounding risk/reward.

## Organ Rarities & Generation
- 3 sizes × **5 rarities** = 15 total organ variants (asset scope).
- **Fixed base yields** per rarity/size combination (Insight + Biomatter).
- All exponential scaling comes from:
  - Prestige tree (rarity odds, quantity bonuses, price-to-value).
  - Pet synergies / evolutions.
  - Temporary Madness buffs / events.
- **Mnemonic Fragments**: Bonus for completing all 5 rarities in one size set (visual achievement + comic unlock).

## Meta: Madness
Hidden tracker for event frequency + visuals. Revealed via comics.

## Consumption & Death
- Food is consumed by pets (collision-based) or rots if uneaten. **Pollution is added relative to the size of the food on both eat and decay** (small ~3-5, medium ~8-10, large ~12-15; exact values tunable in implementation).
- All pets have explicit **HP**. Goldfish baseline 5, Remora 3, 1 per Minnow. Dynamic hunger (prolonged max-hunger without eating) depletes HP for all; Pollution exposure depletes HP for sensitive pets (especially Goldfish and Minnows). Remora primarily loses HP from stress when attempting to process Pollution at 0%.
- Death at 0 HP (from any combination of the above) grants **Forgotten Mnemonic Fragments scaled to the pet's reached evolution stage** (plus applicable path bonuses such as Sacrificial Specimen or Final Purge). This, together with consumption thresholds, makes the initial play loop viable around one Goldfish evolution before a natural reset fuels early prestige.
- Pet evolution applies a **default multiplier** (plus choice-specific further multipliers) to the resources that pet produces via future consumption.
- Fragments also come from set completion bonuses.

See **Pets.md** for consumption preferences, HP/stress/hold details, and evolution paths. See **Shop.md** for shipments.