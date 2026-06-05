# scripts/managers/GameManager.gd
# Central game state manager (Autoload singleton).
# Handles all resources, pollution, ordering shipments, and high-level progression.
extends Node

signal resources_changed
signal pollution_changed(new_pollution: float)
signal shipment_ordered

# Core resources
var _resources: Dictionary = {}

# Pollution (0-100). High pollution = faster growth + funny madness events
@export_range(0, 100, 0.1) var pollution: float = 0.0

# Simple stats for this run (expand for prestige)
var total_shipments_ordered: int = 0
var total_organs_collected: int = 0

# Run state for dynamic title/catalog behavior (v1.3+)
var first_pet_hatched: bool = false
# When true, the TitleScreen should show an updated "catalog" version of the ad instead of the brand-new Sea Monkey kit pitch.

# Set by TitleScreen "ORDER SEA MONKEY KIT" (or equivalent) for brand new runs.
# AquariumController consumes it on ready to launch the egg + complimentary opening sequence.
var pending_opening_sequence: bool = false

func _ready() -> void:
	_initialize_resources()
	print("[GameManager] Initialized with starting resources.")

func _initialize_resources() -> void:
	# Start with zero resources. Everything is earned via pet collision-eating (per design).
	_resources[GameEnums.ResourceType.ELDRITCH_INSIGHT] = 0
	_resources[GameEnums.ResourceType.BIOMASS] = 0
	_resources[GameEnums.ResourceType.VOID_ESSENCE] = 0
	_resources[GameEnums.ResourceType.SANITY_SHARDS] = 0
	_resources[GameEnums.ResourceType.POLLUTION] = 0  # We track Pollution separately

	resources_changed.emit()

## Returns current amount for a resource type.
## Pollution is tracked via the pollution property.
func get_resource(type: GameEnums.ResourceType) -> int:
	if type == GameEnums.ResourceType.POLLUTION:
		return int(pollution)
	return _resources.get(type, 0)

## Add (or subtract with negative) a resource. Clamps pollution.
## Emits resources_changed and pollution_changed when relevant.
func add_resource(type: GameEnums.ResourceType, amount: int) -> void:
	if type == GameEnums.ResourceType.POLLUTION:
		var old: float = pollution
		pollution = clamp(pollution + amount, 0.0, 100.0)
		if not is_equal_approx(old, pollution):
			pollution_changed.emit(pollution)
			resources_changed.emit()
		return

	if not _resources.has(type):
		_resources[type] = 0

	_resources[type] += amount
	if _resources[type] < 0:
		_resources[type] = 0

	resources_changed.emit()

## Attempts to spend the resource. Returns true on success.
func try_spend(type: GameEnums.ResourceType, amount: int) -> bool:
	if amount <= 0:
		return true

	if type == GameEnums.ResourceType.POLLUTION:
		# Pollution is usually gained, not spent directly. Allow "spend" to reduce it.
		if pollution >= amount:
			add_resource(type, -amount)
			return true
		return false

	if _resources.get(type, 0) >= amount:
		add_resource(type, -amount)
		return true
	return false

## Core action: Spend resources to order a shipment.
## The actual container drop is handled by the AquariumController listening to the signal.
## TODO (new vision): Switch primary cost to ELDRITCH_INSIGHT. The first "complimentary" shipment in the opening sequence should be free/zero-cost.
func order_shipment(insight_cost: int = 8) -> bool:
	# Prefer Eldritch Insight (new basic currency). Fall back to Biomass for current prototype compatibility.
	var cost_type := GameEnums.ResourceType.ELDRITCH_INSIGHT
	if not try_spend(cost_type, insight_cost):
		if not try_spend(GameEnums.ResourceType.BIOMASS, insight_cost):
			print("[GameManager] Not enough Eldritch Insight (or legacy Biomass) to order shipment.")
			return false

	total_shipments_ordered += 1
	add_resource(GameEnums.ResourceType.POLLUTION, 3)  # Every shipment adds a little pollution

	shipment_ordered.emit()
	print("[GameManager] Shipment ordered! Total this run: %d" % total_shipments_ordered)
	return true

## Resets per-run stats while preserving any future meta-progression.
## Called when starting a fresh session from the title screen.
func start_new_run() -> void:
	# Fresh run for the comic ad opening experience.
	# Start with no resources. Insight etc. earned only from the larva eating the starter packets.
	_resources[GameEnums.ResourceType.ELDRITCH_INSIGHT] = 0
	_resources[GameEnums.ResourceType.BIOMASS] = 0
	_resources[GameEnums.ResourceType.VOID_ESSENCE] = 0
	_resources[GameEnums.ResourceType.SANITY_SHARDS] = 0
	pollution = 1.0  # Starts low; rises with activity

	total_shipments_ordered = 0
	total_organs_collected = 0

	resources_changed.emit()
	pollution_changed.emit(pollution)

	print("[GameManager] New run started (comic ad opening flow).")
	first_pet_hatched = false
	pending_opening_sequence = true  # Will trigger the egg + hatch sequence in Aquarium for the first moments.

## Legacy direct collection (organs picked up by player before being eaten).
## Per v1.3 vision, this should grant *nothing* to the economy. Food exists to be eaten by pets.
## The only way to generate Insight / resources is via register_pet_consumed_organ below.
func register_organ_collected(organ_type: GameEnums.OrganType) -> void:
	total_organs_collected += 1
	# Do NOT grant Insight or other economy resources here anymore.
	# Optional: still add a tiny bit of POLLUTION or legacy Biomass for prototype compatibility during transition.
	add_resource(GameEnums.ResourceType.POLLUTION, 1)
	# add_resource(GameEnums.ResourceType.BIOMASS, 1)  # commented — prefer to remove

## Called by Pet when it successfully completes the required collisions and consumes food.
## Main Insight is emitted *gradually* one (per-bite) at a time from Organ.on_pet_bump (so tokens fly individually to UI).
## This function adds a small +1 final bonus on full consume (plus side effects like pollution, void RNG, totals).
## The final +1 is the "appropriate amount" for the consume event itself (kept small to preserve one-at-a-time releases).
func register_pet_consumed_organ(pet_data: Dictionary, organ_type: GameEnums.OrganType) -> void:
	# pet_data example: { "species": "sea_monkey", "stage": GameEnums.EvolutionStage.LARVAL, "pet_name": "..." }
	# Small final bonus insight on full consume (the "eat" event / completing the organ).
	# Kept to +1 so releases stay one at a time (in addition to the per-bite amounts from Organ.on_pet_bump).
	# The per-bite amounts already provide the main "insight_value" defined on the organ.
	add_resource(GameEnums.ResourceType.ELDRITCH_INSIGHT, 1)

	# Small chance for secondary resources from certain eats (pet variety hook).
	if randf() < 0.15:
		add_resource(GameEnums.ResourceType.VOID_ESSENCE, 1)

	total_organs_collected += 1  # reuse for now; could track consumed vs collected separately
	add_resource(GameEnums.ResourceType.POLLUTION, 1)

	print("[GameManager] Pet consumed organ (from %s eating %s). +1 final insight bonus. RNG secondaries possible." % [pet_data.get("species", "unknown"), GameEnums.OrganType.keys()[organ_type]])

## Example madness trigger hook. Call from AquariumController when Pollution is high.
func trigger_madness_event(description: String) -> void:
	print_rich("[MADNESS] " + description)
	# TODO: Emit a signal that AquariumController or UI can react to with fun effects.

## Call this (e.g. from the first Pet hatch or first successful consumption) so the TitleScreen knows
## to show a continuing-run catalog page instead of the initial "new kit" ad on next visit to title.
func mark_first_pet_hatched() -> void:
	first_pet_hatched = true
	print("[GameManager] First pet hatched — future title screens should use updated catalog/ad content.")

# --- Future expansion hooks ---

func prestige() -> void:
	# TODO: Calculate multipliers, reset run, apply permanent bonuses
	print("[GameManager] Prestige not yet implemented.")

func save_game() -> void:
	# TODO: Use FileAccess or JSON to persist resources + pet states + upgrades
	print("[GameManager] SaveGame stub.")

func load_game() -> void:
	print("[GameManager] LoadGame stub.")