extends RigidBody2D

@export var type: GameEnums.OrganType = GameEnums.OrganType.TENTACLE
@export var biomass_value: int = 5
@export var insight_value: int = 5
@export var bites_to_consume: int = 4

# Minimal size category for the initial gold starter playloop (previews Medium preference).
# "medium" for the Goldfish's complimentary starter packets (larger visual + future match bonus).
# Other values: "small", "large". Normal organs default "medium" or random for now.
@export var size_category: String = "medium"

@export_group("Physics")
@export var buoyancy: float = 0.0
@export var tank_resistance: float = 1.0
@export var angular_resistance: float = 2.8

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

	# Apply size_category to initial visual scale for the gold starter medium packets (and future mixed sizes).
	_apply_size_visual()

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
			# Unique "incubation packet" for the very first egg - medium food for the gold starter (Freaky Goldfish).
			_visual.color = Color(0.25, 0.58, 0.22)
			_visual.size = Vector2(30, 24)  # chunkier base (will be further scaled by size_category)
		GameEnums.OrganType.STARTER_VOID:
			# Unique "incubation packet" - eerie purple void kelp / broth (also medium for gold starter preview).
			_visual.color = Color(0.48, 0.22, 0.65)
			_visual.size = Vector2(28, 26)
			# Slight transparency for "ethereal" packet feel
			_visual.modulate.a = 0.85
		_:
			_visual.color = Color(0.7, 0.5, 0.6)
			_visual.size = Vector2(22, 18)

	_apply_size_visual()  # ensure size_category affects final rect size for medium preference preview

# Apply minimal size visual scaling. Starter packets for the gold playloop are "medium" (larger, distinct).
# This gives immediate visual distinction without a full OrganSize enum yet.
func _apply_size_visual() -> void:
	if _visual == null:
		return
	var factor := 1.0
	match size_category:
		"small":
			factor = 0.7
		"large":
			factor = 1.45
		"medium", _:
			factor = 1.15  # slightly larger than generic for the gold starter's matched food
	_visual.size *= factor
	# Also bump the collision shape slightly for larger targets (helps distinct "feel" when seeking).
	var col := get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius *= factor

## Force a specific type (used for unique starter packets from complimentary shipment).
## Prevents the randomizer and forces visual refresh.
## Also reapplies size_category (callers set size_category before or after this for the gold starter medium packets).
func set_organ_type(new_type: GameEnums.OrganType) -> void:
	type = new_type
	_update_visual_for_type()  # Tentacle default

## Set size category explicitly (used by AquariumController when spawning the gold starter's medium packets).
func set_size_category(new_size: String) -> void:
	size_category = new_size
	_apply_size_visual()

## Called by pet on each discrete collision/bump. Shrinks the organ gradually and emits small resource.
func on_pet_bump(pet: Node = null) -> void:
	if _collected or remaining_bites <= 0:
		return
	remaining_bites -= 1
	_shrink_scale = max(0.25, _shrink_scale - (1.0 / max(1, bites_to_consume)))
	if _visual:
		_visual.scale = Vector2(_shrink_scale, _shrink_scale)

	var amount := 1
	if insight_value > 0 and bites_to_consume > 0:
		amount = max(1, insight_value / bites_to_consume)

	if _controller and _controller.has_method("spawn_resource_glob"):
		_controller.spawn_resource_glob(global_position, amount, GameEnums.ResourceType.ELDRITCH_INSIGHT)
	elif _controller and _controller.has_method("_spawn_floating_text"):
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
			_game_manager.add_resource(GameEnums.ResourceType.ABYSSAL_BIOMATTER, biomass_value)

	if legacy:
		pass
	else:
		pass

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)