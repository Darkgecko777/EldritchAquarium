# scripts/data/enums.gd
# Shared enums for the game.
# Because of `class_name`, these are available project-wide as `GameEnums.ResourceType.BIOMASS` etc.
# No need to preload in most cases.
class_name GameEnums

enum ResourceType {
	BIOMASS,        # Primary growth/food resource
	VOID_ESSENCE,   # Premium / rare currency
	SANITY_SHARDS,  # Used for special upgrades or risk mitigation
	POLLUTION       # Risk/reward meter (not a spendable in the traditional sense)
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
	# Add more eldritch varieties
}