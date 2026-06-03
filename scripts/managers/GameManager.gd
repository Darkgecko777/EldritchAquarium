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

func _ready() -> void:
	_initialize_resources()
	print("[GameManager] Initialized with starting resources.")

func _initialize_resources() -> void:
	_resources[GameEnums.ResourceType.BIOMASS] = 50
	_resources[GameEnums.ResourceType.VOID_ESSENCE] = 10
	_resources[GameEnums.ResourceType.SANITY_SHARDS] = 5
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
func order_shipment(biomass_cost: int = 10) -> bool:
	if not try_spend(GameEnums.ResourceType.BIOMASS, biomass_cost):
		print("[GameManager] Not enough Biomass to order shipment.")
		return false

	total_shipments_ordered += 1
	add_resource(GameEnums.ResourceType.POLLUTION, 3)  # Every shipment adds a little pollution

	shipment_ordered.emit()
	print("[GameManager] Shipment ordered! Total this run: %d" % total_shipments_ordered)
	return true

## Resets per-run stats while preserving any future meta-progression.
## Called when starting a fresh session from the title screen.
func start_new_run() -> void:
	# Keep some resources or give a fresh starting amount
	_resources[GameEnums.ResourceType.BIOMASS] = 60
	_resources[GameEnums.ResourceType.VOID_ESSENCE] = 5
	_resources[GameEnums.ResourceType.SANITY_SHARDS] = 3
	pollution = 8.0  # Small starting pollution for atmosphere

	total_shipments_ordered = 0
	total_organs_collected = 0

	resources_changed.emit()
	pollution_changed.emit(pollution)

	print("[GameManager] New run started.")

## Called when an organ is successfully collected / used.
func register_organ_collected(organ_type: GameEnums.OrganType) -> void:
	total_organs_collected += 1
	# TODO: Add small resource rewards based on organ type (e.g. more Biomass for Heart)
	add_resource(GameEnums.ResourceType.BIOMASS, 2)
	add_resource(GameEnums.ResourceType.POLLUTION, 1)

## Example madness trigger hook. Call from AquariumController when Pollution is high.
func trigger_madness_event(description: String) -> void:
	print_rich("[MADNESS] " + description)
	# TODO: Emit a signal that AquariumController or UI can react to with fun effects.

# --- Future expansion hooks ---

func prestige() -> void:
	# TODO: Calculate multipliers, reset run, apply permanent bonuses
	print("[GameManager] Prestige not yet implemented.")

func save_game() -> void:
	# TODO: Use FileAccess or JSON to persist resources + pet states + upgrades
	print("[GameManager] SaveGame stub.")

func load_game() -> void:
	print("[GameManager] LoadGame stub.")