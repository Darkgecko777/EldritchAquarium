# scripts/entities/Organ.gd
# An organ / loot piece released from a shipping container.
# Player can click to collect. Later we can support drag-to-feed directly onto pets.
extends RigidBody2D

@export var type: GameEnums.OrganType = GameEnums.OrganType.TENTACLE
@export var biomass_value: int = 5  # Legacy value for direct collection (economy no longer uses this for Insight). Starter packets may use different values or a separate system.
@export var insight_value: int = 5
@export var bites_to_consume: int = 4

@export_group("Physics")
@export var buoyancy: float = 0.0  # upward force for floating (only useful if gravity_scale > 0). 0 = neutral "no gravity" floating.
@export var tank_resistance: float = 1.0  # linear_damp - generic resistance/drag of the tank liquid. Lower = organs travel/bounce farther from their spawn origin before damping to rest.
@export var angular_resistance: float = 2.8  # angular_damp - how quickly spinning resists.

var _game_manager: Node
var _controller: Node
var _life_time: float = 0.0
var _collected: bool = false

# Simple visual placeholder
var _visual: ColorRect

var _shrink_scale: float = 1.0  # for gradual consumption on collisions
var remaining_bites: int = 4

func _ready() -> void:
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = Vector2(22, 18)
		_visual.position = Vector2(-11, -9)
		_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_visual)

	# Randomize organ type on creation for variety (unless preset in editor or a special starter packet)
	var is_starter := type in [GameEnums.OrganType.STARTER_PRIMAL, GameEnums.OrganType.STARTER_VOID]
	if not is_starter and randf() < 0.7:
		type = randi() % GameEnums.OrganType.size() as GameEnums.OrganType

	_update_visual_for_type()

	_shrink_scale = 1.0
	remaining_bites = bites_to_consume
	if _visual:
		_visual.scale = Vector2(1, 1)

	# Physics props (can override per instance in spawn)
	# No gravity: organs are "weightless" in the tank and only move from explosion impulse,
	# wall bounces, and slow according to the tank's resistance (linear_damp).
	gravity_scale = 0.0
	linear_damp = tank_resistance
	angular_damp = angular_resistance

	# Slight bounciness so they ricochet nicely off tank walls before damping to rest.
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.55
	mat.friction = 0.08
	physics_material_override = mat

	input_event.connect(_on_input_event)

	add_to_group("organs")  # helps Pet find food targets for autonomous eating

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _collected:
		return
	# Neutral buoyancy simulation. With gravity_scale=0 this is usually disabled (buoyancy export = 0).
	# Organs get initial outward impulse from the container, bounce off the invisible TankWalls,
	# then the tank_resistance (linear_damp) brings them to a stop floating wherever they end up.
	if buoyancy > 0.01:
		state.apply_central_force(Vector2(0, -buoyancy))

func _process(delta: float) -> void:
	if _collected:
		return

	_life_time += delta

	# Gentle visual bobbing on the sprite while physics handles main movement (or after it has damped to rest).
	if _visual:
		var bob: float = sin(_life_time * 1.8) * 3.0
		_visual.position.y = -9 + bob

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

## Called by pet on each discrete collision/bump. Shrinks the organ gradually and emits small resource.
func on_pet_bump(pet: Node = null) -> void:
	if _collected or remaining_bites <= 0:
		return
	remaining_bites -= 1
	_shrink_scale = max(0.25, _shrink_scale - (1.0 / max(1, bites_to_consume)))
	if _visual:
		_visual.scale = Vector2(_shrink_scale, _shrink_scale)

	# Emit the resource released per bite
	var amount := 1
	if insight_value > 0 and bites_to_consume > 0:
		amount = max(1, insight_value / bites_to_consume)
	if _game_manager:
		_game_manager.add_resource(GameEnums.ResourceType.ELDRITCH_INSIGHT, amount)
	# Juicy feedback: the released insight flies from the bite location up to the UI Insight label.
	# This + the label pop + resource update is the core "earned" feedback.
	if _controller and _controller.has_method("_spawn_floating_resource"):
		_controller._spawn_floating_resource(global_position, "+%d" % amount, Color(0.4, 0.85, 1.0), 1.1)
	elif _controller and _controller.has_method("_spawn_floating_text"):
		# Fallback
		_controller._spawn_floating_text("+%d" % amount, global_position - Vector2(0, 15), Color(0.4, 0.85, 1.0), 0.9)

func get_remaining_bites() -> int:
	return remaining_bites

func is_fully_consumed() -> bool:
	return remaining_bites <= 0

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _collected:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if remaining_bites > 0:
				# Enforce design: organs persist in the scene until *fully consumed* by pets (via bumps).
				# Direct/legacy pickup only for leftovers or debug. Give subtle feedback.
				if _controller and _controller.has_method("_spawn_floating_text"):
					_controller._spawn_floating_text("for the pet...", global_position - Vector2(0, 8), Color(0.55, 0.5, 0.45), 0.5)
				get_viewport().set_input_as_handled()
				return
			if _controller and _controller.has_method("pickup_organ"):
				_controller.pickup_organ(type, biomass_value, self)
			else:
				collect()
			get_viewport().set_input_as_handled()

func collect(legacy: bool = true) -> void:
	if _collected:
		return
	_collected = true

	if legacy and _game_manager:
		if _game_manager.has_method("register_organ_collected"):
			_game_manager.register_organ_collected(type)
		# Per v1.3 strict vision: direct collection grants NOTHING to the economy.
		# Food is for pets to eat. Only register_pet_consumed_organ (called from Pet on successful collisions) generates Insight.
		if _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, biomass_value)  # legacy only, if still used for anything visual

	# TODO: Nice collection particle / sound / floating +X text (in comic style: "SPLORCH!" "FOR THE TANK!" etc. — no +Insight text here)
	if legacy:
		print("[Organ] Collected ", GameEnums.OrganType.keys()[type], " (legacy Biomass only — no Insight. Must be eaten by a pet for resources.)")
	else:
		print("[Organ] Fully consumed by pet.")

	# Quick pop + fade out (used both for legacy pickup and final pet consumption)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

# Future ideas:
# - Drag and drop onto a pet to feed directly (bypass inventory)
# - Different values / special effects per organ type
# - "Freshness" that decays if left too long