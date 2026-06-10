class_name GameEnums

enum ResourceType {
	ELDRITCH_INSIGHT,
	ABYSSAL_BIOMATTER,
	FORGOTTEN_MNEMONIC_SHARDS,
	POLLUTION
}

enum EvolutionStage {
	LARVAL,
	JUVENILE,
	MATURE,
	ELDRITCH
}

enum PetSpecies {
	FREAKY_GOLDFISH  # Starts as a perfectly normal aquarium goldfish. Mutations happen via consumption/evolution stages.
}

enum OrganType {
	TENTACLE,
	EYE,
	HEART,
	SCALE,
	NEURAL_CLUSTER,
	STARTER_PRIMAL,  # Used for the complimentary first-run sample feed pack (visually distinct "exotic primer" food)
	STARTER_VOID     # Second special sample packet. Reframed as mutation kickstart feed, not incubation packets.
}

enum OrganRarity {
	COMMON,     # insight = 2
	UNCOMMON,   # insight = 4
	RARE,       # insight = 8
	EPIC,       # insight = 16
	LEGENDARY   # insight = 32
}