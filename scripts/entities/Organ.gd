# scripts/entities/Organ.gd
# An organ / loot piece released from a shipping container.
# Player can click to collect. Later we can support drag-to-feed directly onto pets.
extends Area2D

@export var type: GameEnums.OrganType = GameEnums.OrganType.TENTACLE
@export var biomass_value: int = 5  # Legacy value for direct collection (economy no longer uses this for Insight). Starter packets may use different values or a separate system.

@export_group("Movement")
@export var float_speed: float = 18.0
@export var bob_amount: float = 6.0

var _game_manager: Node
var _controller: Node
var _base_position: Vector2
var _life_time: float = 0.0
var _collected: bool = false

# Simple visual placeholder
var _visual: ColorRect

func _ready() -> void:
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = Vector2(22, 18)
		_visual.position = Vector2(-11, -9)
		add_child(_visual)

	# Randomize organ type on creation for variety (unless preset in editor or a special starter packet)
	var is_starter := type in [GameEnums.OrganType.STARTER_PRIMAL, GameEnums.OrganType.STARTER_VOID]
	if not is_starter and randf() < 0.7:
		type = randi() % GameEnums.OrganType.size() as GameEnums.OrganType

	_update_visual_for_type()

	input_event.connect(_on_input_event)

	add_to_group("organs")  # helps Pet find food targets for autonomous eating

	# Optional: auto-collect after some time floating (makes early game less clicky)
	var timer: SceneTreeTimer = get_tree().create_timer(18.0)
	timer.timeout.connect(func():
		if is_instance_valid(self) and not _collected:
			collect()
	)

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller
	_base_position = global_position

func _process(delta: float) -> void:
	if _collected:
		return

	_life_time += delta

	# Gentle bobbing + slight horizontal drift
	var bob: float = sin(_life_time * 1.8) * bob_amount
	var drift: float = sin(_life_time * 0.6) * 4.0

	global_position = _base_position + Vector2(drift, bob)

	if _controller and _controller.has_method("clamp_to_tank"):
		global_position = _controller.clamp_to_tank(global_position)

	# Very slight pollution aura when many organs are out (flavor)

func _update_visual_for_type() -> void:
	if _visual == null:
		return

	match type:
		GameEnums.OrganType.EYE:
			_visual.color = Color(0.9, 0.3, 0.3)
			_visual.size = Vector2(22, 18)
		GameEnums.OrganType.HEART:
			_visual.color = Color(0.6, 0.1, 0.2)
			_visual.size = Vector2(22, 18)
		GameEnums.OrganType.NEURAL_CLUSTER:
			_visual.color = Color(0.4, 0.8, 0.9)
			_visual.size = Vector2(22, 18)
		GameEnums.OrganType.SCALE:
			_visual.color = Color(0.3, 0.6, 0.5)
			_visual.size = Vector2(22, 18)
		GameEnums.OrganType.STARTER_PRIMAL:
			# Unique "incubation packet" for the very first egg - gooey green starter food
			_visual.color = Color(0.25, 0.58, 0.22)
			_visual.size = Vector2(30, 24)  # chunkier
		GameEnums.OrganType.STARTER_VOID:
			# Unique "incubation packet" - eerie purple void kelp / broth
			_visual.color = Color(0.48, 0.22, 0.65)
			_visual.size = Vector2(28, 26)
			# Slight transparency for "ethereal" packet feel
			_visual.modulate.a = 0.85
		_:
			_visual.color = Color(0.7, 0.5, 0.6)
			_visual.size = Vector2(22, 18)

## Force a specific type (used for unique starter packets from complimentary shipment).
## Prevents the randomizer and forces visual refresh.
func set_organ_type(new_type: GameEnums.OrganType) -> void:
	type = new_type
	_update_visual_for_type()  # Tentacle default

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _collected:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _controller and _controller.has_method("pickup_organ"):
				_controller.pickup_organ(type, biomass_value, self)
			else:
				collect()
			get_viewport().set_input_as_handled()

func collect() -> void:
	if _collected:
		return
	_collected = true

	if _game_manager:
		if _game_manager.has_method("register_organ_collected"):
			_game_manager.register_organ_collected(type)
		# Per v1.3 strict vision: direct collection grants NOTHING to the economy.
		# Food is for pets to eat. Only register_pet_consumed_organ (called from Pet on successful collisions) generates Insight.
		if _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, biomass_value)  # legacy only, if still used for anything visual

	# TODO: Nice collection particle / sound / floating +X text (in comic style: "SPLORCH!" "FOR THE TANK!" etc. — no +Insight text here)
	print("[Organ] Collected ", GameEnums.OrganType.keys()[type], " (legacy Biomass only — no Insight. Must be eaten by a pet for resources.)")

	# Quick pop + fade out
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

# Future ideas:
# - Drag and drop onto a pet to feed directly (bypass inventory)
# - Different values / special effects per organ type
# - "Freshness" that decays if left too long