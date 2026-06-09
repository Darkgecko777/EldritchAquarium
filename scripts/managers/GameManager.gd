extends Node

signal resources_changed
signal pollution_changed(new_pollution: float)
signal shipment_ordered

var _resources: Dictionary = {}

@export_range(0, 100, 0.1) var pollution: float = 0.0

var total_shipments_ordered: int = 0
var total_organs_collected: int = 0

var first_pet_hatched: bool = false
var pending_opening_sequence: bool = false

func _ready() -> void:
	_initialize_resources()
	print("[DEBUG] GameManager init - Insight: %d, Biomatter: %d, Shards: %d" % [_resources.get(GameEnums.ResourceType.ELDRITCH_INSIGHT, 0), _resources.get(GameEnums.ResourceType.ABYSSAL_BIOMATTER, 0), _resources.get(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 0)])

func _initialize_resources() -> void:
	_resources[GameEnums.ResourceType.ELDRITCH_INSIGHT] = 0
	_resources[GameEnums.ResourceType.ABYSSAL_BIOMATTER] = 0
	_resources[GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS] = 0
	_resources[GameEnums.ResourceType.POLLUTION] = 0

	resources_changed.emit()

func get_resource(type: GameEnums.ResourceType) -> int:
	if type == GameEnums.ResourceType.POLLUTION:
		return int(pollution)
	return _resources.get(type, 0)

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

	if type == GameEnums.ResourceType.ELDRITCH_INSIGHT or type == GameEnums.ResourceType.ABYSSAL_BIOMATTER or type == GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS:
		print("[DEBUG] Added %d to %s, now %d" % [amount, GameEnums.ResourceType.keys()[type], _resources[type]])

func try_spend(type: GameEnums.ResourceType, amount: int) -> bool:
	if amount <= 0:
		return true

	if type == GameEnums.ResourceType.POLLUTION:
		if pollution >= amount:
			add_resource(type, -amount)
			return true
		return false

	if _resources.get(type, 0) >= amount:
		add_resource(type, -amount)
		return true
	return false

func order_shipment(insight_cost: int = 8) -> bool:
	var cost_type := GameEnums.ResourceType.ELDRITCH_INSIGHT
	if not try_spend(cost_type, insight_cost):
		if not try_spend(GameEnums.ResourceType.ABYSSAL_BIOMATTER, insight_cost):
			return false

	total_shipments_ordered += 1
	add_resource(GameEnums.ResourceType.POLLUTION, 3)

	shipment_ordered.emit()
	return true

func start_new_run() -> void:
	_resources[GameEnums.ResourceType.ELDRITCH_INSIGHT] = 0
	_resources[GameEnums.ResourceType.ABYSSAL_BIOMATTER] = 0
	_resources[GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS] = 0
	pollution = 1.0

	total_shipments_ordered = 0
	total_organs_collected = 0

	resources_changed.emit()
	pollution_changed.emit(pollution)

	print("[DEBUG] New run reset - Insight: %d, Biomatter: %d, Shards: %d" % [_resources.get(GameEnums.ResourceType.ELDRITCH_INSIGHT, 0), _resources.get(GameEnums.ResourceType.ABYSSAL_BIOMATTER, 0), _resources.get(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 0)])
	first_pet_hatched = false
	pending_opening_sequence = true

func register_organ_collected(organ_type: GameEnums.OrganType) -> void:
	total_organs_collected += 1
	add_resource(GameEnums.ResourceType.POLLUTION, 1)

func register_pet_consumed_organ(pet_data: Dictionary, organ_type: GameEnums.OrganType) -> void:
	if randf() < 0.15:
		add_resource(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 1)

	total_organs_collected += 1
	add_resource(GameEnums.ResourceType.POLLUTION, 1)

func trigger_madness_event(description: String) -> void:
	pass

func mark_first_pet_hatched() -> void:
	first_pet_hatched = true

func prestige() -> void:
	pass

func save_game() -> void:
	pass

func load_game() -> void:
	pass
