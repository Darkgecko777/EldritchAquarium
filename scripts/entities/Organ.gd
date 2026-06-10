extends RigidBody2D

@export var type: GameEnums.OrganType = GameEnums.OrganType.TENTACLE
@export var biomass_value: int = 5
@export var insight_value: int = 5
@export var bites_to_consume: int = 4

# Size category for feed preference matching (Goldfish likes medium).
# Used for the initial sample packets and all later exotic feed drops.
# "medium" for the complimentary starter sample (larger visual + preference bonus).
# Other values: "small", "large".
@export var size_category: String = "medium"

# Rarity for shipments / yields / starter linking (lowest = COMMON for goldfish starter shipment).
@export var rarity: GameEnums.OrganRarity = GameEnums.OrganRarity.COMMON

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

# Visual decay timer bar (shows time until rot/pollution spike)
var _decay_bar: ColorRect

var _shrink_scale: float = 1.0  # for gradual consumption on collisions
var remaining_bites: int = 4

const DECAY_TIME: float = 20.0  # fixed uneaten lifetime before rot adds pollution (small/medium/large = 5/10/15). Tune or make @export later.

# Hold-to-tend support: player holding LMB on uneaten food accelerates decay (4x _life_time)
# This rapidly generates Pollution "food" for Remora-style play.
var decay_multiplier: float = 1.0
var _original_visual_color: Color = Color(0.55, 0.52, 0.47)

func _ready() -> void:
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = Vector2(22, 18)
		_visual.position = Vector2(-11, -9)
		_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_visual)

	# Randomize feed type on creation for variety (unless preset as a special sample packet).
	# Note: type no longer controls the primary visual (color/size). Visuals are driven by
	# rarity + size_category so that feed items with the same size and rarity look identical.
	var is_starter := type in [GameEnums.OrganType.STARTER_PRIMAL, GameEnums.OrganType.STARTER_VOID]
	if not is_starter and randf() < 0.7:
		type = randi() % GameEnums.OrganType.size() as GameEnums.OrganType

	# Visuals are now determined by size + rarity for consistency:
	# All organs with the same size_category and rarity look identical at spawn.
	_update_visual_for_rarity_and_size()

	_shrink_scale = 1.0
	remaining_bites = bites_to_consume
	if _visual:
		_visual.scale = Vector2(1, 1)

	# Add a small decay timer bar above the food (visible progress toward rot/pollution).
	# This makes the decay timer on food obvious to the player.
	_decay_bar = ColorRect.new()
	_decay_bar.name = "DecayBar"
	_decay_bar.size = Vector2(18, 2)
	_decay_bar.position = Vector2(-9, -20)  # positioned above the main visual
	_decay_bar.color = Color(0.85, 0.25, 0.15, 0.85)  # rotting red-orange
	_decay_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_decay_bar)
	_decay_bar.visible = true  # will be driven by _process decay progress

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

	# Use a dedicated larger Area2D for mouse input (hold to decay, click to pickup).
	# This makes "holding mouse on food" reliable even if the physics collision is small.
	_setup_input_area()

	add_to_group("organs")  # helps Pet find food targets for autonomous eating

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller

	# Belt-and-suspenders: ensure food is always findable by pets via the group
	# (in addition to the authoritative get_valid_food_in_tank bounds check in controller).
	if not is_in_group("organs"):
		add_to_group("organs")

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

	_life_time += delta * decay_multiplier

	# Gentle visual bobbing on the sprite while physics handles main movement (or after it has damped to rest).
	if _visual:
		var bob: float = sin(_life_time * 1.8) * 3.0
		_visual.position.y = -9 + bob

	# Drive the decay timer visual on the food.
	if _decay_bar and not _collected and remaining_bites > 0:
		var decay_prog: float = clamp(_life_time / DECAY_TIME, 0.0, 1.0)
		_decay_bar.size.x = 18.0 * (1.0 - decay_prog)  # depletes as decay approaches
		_decay_bar.visible = true

	# Decay / rot for uneaten organs: adds Pollution (size-scaled) then self-destructs.
	# Only for positive remaining bites (uneaten / not fully consumed) and not already collected.
	if not _collected and remaining_bites > 0 and _life_time >= DECAY_TIME:
		_decay_and_rot()

	# Very slight pollution aura when many organs are out (flavor)

# Determines the initial visual (color + rect size) based on rarity and size_category.
# This guarantees that any two organs with identical size + rarity have identical appearance
# when they first appear ("to begin with"), regardless of their internal OrganType.
func _update_visual_for_rarity_and_size() -> void:
	if _visual == null:
		return

	# Color is driven by rarity so that rarity is visually recognizable and consistent.
	var col: Color
	match rarity:
		GameEnums.OrganRarity.COMMON:
			col = Color(0.55, 0.52, 0.47)      # muted, earthy
		GameEnums.OrganRarity.UNCOMMON:
			col = Color(0.40, 0.62, 0.45)      # vibrant green
		GameEnums.OrganRarity.RARE:
			col = Color(0.30, 0.52, 0.78)      # clear blue
		GameEnums.OrganRarity.EPIC:
			col = Color(0.62, 0.35, 0.72)      # mystical purple
		GameEnums.OrganRarity.LEGENDARY:
			col = Color(0.82, 0.28, 0.35)      # wrong/red
		_:
			col = Color(0.55, 0.52, 0.47)

	_visual.color = col
	_original_visual_color = col

	# Base dimensions driven by size_category (rarity may get slight future embellishments).
	var sz := Vector2(22, 18)
	match size_category:
		"small":
			sz = Vector2(15, 12)
		"large":
			sz = Vector2(30, 24)
		"medium", _:
			sz = Vector2(23, 19)

	_visual.size = sz

	# Update collision radius to match the new visual size for consistent targeting/feel.
	var col_node := get_node_or_null("CollisionShape2D")
	if col_node and col_node.shape is CircleShape2D:
		(col_node.shape as CircleShape2D).radius = max(sz.x, sz.y) * 0.52

# Legacy name kept for any external callers; now forwards to the size+rarity visual.
func _update_visual_for_type() -> void:
	_update_visual_for_rarity_and_size()

# Legacy size scaling helper kept for compatibility. The primary sizing now lives in
# _update_visual_for_rarity_and_size so that size+rarity organs are identical.
func _apply_size_visual() -> void:
	_update_visual_for_rarity_and_size()

## Force a specific type (used for unique starter packets from complimentary shipment).
## Prevents the randomizer. Visuals are now driven by rarity + size (see _update_visual_for_rarity_and_size),
## so organs with matching size/rarity will have identical appearance regardless of type.
func set_organ_type(new_type: GameEnums.OrganType) -> void:
	type = new_type
	_update_visual_for_type()  # forwards to rarity+size visual for consistency

## Set size category explicitly (used by AquariumController when spawning the gold starter's medium packets).
func set_size_category(new_size: String) -> void:
	size_category = new_size
	_update_visual_for_rarity_and_size()

## Set rarity explicitly (used for starter shipments linked to pet type, future shop generation, yields).
func set_rarity(new_rarity: GameEnums.OrganRarity) -> void:
	rarity = new_rarity
	_update_visual_for_rarity_and_size()

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

# Called by AquariumController when the player holds (or releases) LMB on this uneaten food item.
# mult=4.0 while held → _life_time advances 4x faster → decay bar and rot happen much quicker.
# This is the primary way to rapidly generate Pollution for pollution-processing pets.
func set_hold_multiplier(mult: float) -> void:
	decay_multiplier = mult
	_update_hold_visual()

func _update_hold_visual() -> void:
	if _visual and _visual is ColorRect:
		if decay_multiplier > 1.0:
			# "Overheating"/faster rotting visual while player tends it
			_visual.color = _original_visual_color.lerp(Color(0.85, 0.35, 0.15), 0.6)
		else:
			_visual.color = _original_visual_color

# Setup a dedicated Area2D (larger than the physics collision) for reliable mouse input.
# This allows the player to easily "hold the mouse on food" to accelerate decay (4x),
# and click when ready for legacy pickup. The physics collision stays small for natural bouncing.
func _setup_input_area() -> void:
	var area := Area2D.new()
	area.name = "InputArea"
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	# Size the input area to comfortably cover the visual (larger than physics radius ~0.52)
	var sz := _visual.size if _visual else Vector2(22, 18)
	circ.radius = max(sz.x, sz.y) * 0.75 + 4
	shape.shape = circ
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_input_event)

func _decay_and_rot() -> void:
	"""Uneaten organ rots after DECAY_TIME.
	Only adds Pollution (size-scaled). Decay produces NO resources (no globs).
	Resources are only obtained via pet collisions (Insight) or full consumption (Biomatter).
	"""
	if _collected:
		return
	_collected = true

	if _decay_bar:
		_decay_bar.visible = false

	# Pollution cost/spike of letting food rot (size-scaled)
	var poll_amt := 10
	match size_category:
		"small":
			poll_amt = 5
		"large":
			poll_amt = 15
		"medium", _:
			poll_amt = 10

	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(GameEnums.ResourceType.POLLUTION, poll_amt)

	# Visual rot + cleanup. No resource release on decay.
	if _visual:
		var t := create_tween()
		t.tween_property(_visual, "modulate:a", 0.0, 0.25)
		t.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), 0.2)
		t.tween_callback(queue_free)
	else:
		queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _collected:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if remaining_bites > 0:
				# Holding the mouse (LMB sustained) on uneaten food increases its decay rate (4x via decay_multiplier).
				# This is the core "active tending" mechanic for generating Pollution quickly from rot.
				# The hold is maintained by the controller polling the mouse button state (you can drag away).
				if _controller and _controller.has_method("start_hold_on"):
					_controller.start_hold_on(self)

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

	if _decay_bar:
		_decay_bar.visible = false

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