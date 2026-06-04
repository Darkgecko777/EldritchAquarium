# scripts/data/enums.gd
# Shared enums for the game.
# Because of `class_name`, these are available project-wide as `GameEnums.ResourceType.BIOMASS` etc.
# No need to preload in most cases.
class_name GameEnums

enum ResourceType {
	ELDRITCH_INSIGHT,  # Primary basic currency. **Generated EXCLUSIVELY by pets successfully consuming via collisions.** Different pets can yield different amounts or secondary resources via RNG. Spent on ad/catalog orders, shipments, upgrades.
	BIOMASS,           # Legacy / possible secondary "raw material". Do not grant Insight or economy resources directly anymore.
	VOID_ESSENCE,      # Premium / rare currency (prestige). Can rarely be produced by high-tier pet eating.
	SANITY_SHARDS,     # Used for special upgrades or risk mitigation. Can rarely drop from eating.
	POLLUTION          # Risk/reward meter (not a spendable in the traditional sense). Rises with activity and consumption.
}

enum EvolutionStage {
	LARVAL,
	JUVENILE,
	MATURE,
	ELDRITCH
}

enum OrganType {
	TENTACLE,
	EYE,
	HEART,
	SCALE,
	NEURAL_CLUSTER,
	# Unique starter "incubation packets" for the very first egg / complimentary shipment only.
	# These are not normal random organs from later containers. They exist purely to bootstrap the larval collision-eating demo.
	STARTER_PRIMAL,   # e.g. "Primordial Broth Packet"
	STARTER_VOID,     # e.g. "Cosmic Kelp Wafer" or "Eldritch Algae Pouch"
	# Add more eldritch varieties for normal shipments
}

# Future: Species or PetType enum for different comic ad "catalog" creatures.
# Each species can have different base yields, collision counts to eat, attraction strength, RNG tables for resources on consumption.
# Example: SEA_MONKEY (starter), then later ABYSS_WORM, VOID_JELLY, etc.