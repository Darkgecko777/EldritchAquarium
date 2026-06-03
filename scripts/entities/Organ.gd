# scripts/entities/Organ.gd
# An organ / loot piece released from a shipping container.
# Player can click to collect. Later we can support drag-to-feed directly onto pets.
extends Area2D

@export var type: GameEnums.OrganType = GameEnums.OrganType.TENTACLE
@export var biomass_value: int = 5

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

	# Randomize organ type on creation for variety (unless preset in editor)
	if randf() < 0.7:
		type = randi() % GameEnums.OrganType.size() as GameEnums.OrganType

	_update_visual_for_type()

	input_event.connect(_on_input_event)

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
		GameEnums.OrganType.HEART:
			_visual.color = Color(0.6, 0.1, 0.2)
		GameEnums.OrganType.NEURAL_CLUSTER:
			_visual.color = Color(0.4, 0.8, 0.9)
		GameEnums.OrganType.SCALE:
			_visual.color = Color(0.3, 0.6, 0.5)
		_:
			_visual.color = Color(0.7, 0.5, 0.6)  # Tentacle default

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
		if _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, biomass_value)

	# TODO: Nice collection particle / sound / floating +X text
	print("[Organ] Collected ", GameEnums.OrganType.keys()[type], " (+", biomass_value, " Biomass)")

	# Quick pop + fade out
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

# Future ideas:
# - Drag and drop onto a pet to feed directly (bypass inventory)
# - Different values / special effects per organ type
# - "Freshness" that decays if left too long