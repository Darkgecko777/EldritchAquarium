# scripts/entities/Pet.gd
# A pet living in the tank.
# Starts simple, grows by being fed organs, eventually evolves.
#
# Current behavior: gentle swimming + basic hunger that accepts any organ.
# This is the heart of the "watch them grow" fantasy — make feeding and evolution feel great.
extends CharacterBody2D

@export var pet_name: String = "Unnamed Horror"
@export var current_stage: GameEnums.EvolutionStage = GameEnums.EvolutionStage.LARVAL

@export_group("Growth")
@export var organs_fed: int = 0
@export var organs_to_next_stage: int = 6

@export_group("Movement")
@export var swim_speed: float = 65.0
@export var wander_radius: float = 180.0

var _game_manager: Node
var _controller: Node
var _wander_target: Vector2
var _wander_timer: float = 0.0
var _tank_center: Vector2 = Vector2.ZERO

# Placeholder visual
var _body: ColorRect

# === AUTONOMOUS EATING (collision-based, only source of Insight per v1.3) ===
var _current_food_target: Node = null
var _hits_on_current_food: int = 0
var _eats_required_for_larva: int = 4
var _eat_radius: float = 22.0  # distance at which a "collision"/bump is counted
var _seek_speed_multiplier: float = 1.0  # larva is eager

func _ready() -> void:
	_body = get_node_or_null("Body")
	if _body == null:
		_body = ColorRect.new()
		_body.name = "Body"
		_body.size = Vector2(32, 24)
		_body.position = Vector2(-16, -12)
		_body.color = Color(0.4, 0.7, 0.5)
		add_child(_body)

	# Make the pet clickable for future "inspect" or direct feed UI
	var area: Area2D = Area2D.new()
	area.name = "InteractArea"
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 28
	area.add_child(shape)
	add_child(area)

	area.input_event.connect(_on_interact_area_input)

	_pick_new_wander_target()

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller

	# Larval Sea Monkey (the first one from the ad) is particularly driven toward food
	if current_stage == GameEnums.EvolutionStage.LARVAL:
		_seek_speed_multiplier = 1.35
		swim_speed = max(swim_speed, 78.0)

func _physics_process(delta: float) -> void:
	if _game_manager == null:
		return

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()

	# Find food target if none or invalid (STARTER packets or normal organs)
	_update_food_target()

	var effective_speed: float = swim_speed * _seek_speed_multiplier
	var direction: Vector2

	if _current_food_target and is_instance_valid(_current_food_target) and not _is_food_collected(_current_food_target):
		# Strong seek toward food for the autonomous collision demo
		direction = (_current_food_target.global_position - global_position).normalized()
		effective_speed = swim_speed * (1.6 if current_stage == GameEnums.EvolutionStage.LARVAL else 1.2)
	else:
		# Normal wander
		direction = (_wander_target - global_position).normalized()
		_current_food_target = null
		_hits_on_current_food = 0

	velocity = direction * effective_speed

	# Very basic "stay in water" — controller can provide better clamping
	move_and_slide()

	if _controller and _controller.has_method("clamp_to_tank"):
		global_position = _controller.clamp_to_tank(global_position)

	# Gentle bobbing / idle animation on the visual
	if _body:
		var bob: float = sin(Time.get_ticks_msec() / 420.0) * 1.5
		_body.position = Vector2(-16, -12 + bob)

	# TODO: React to high pollution (faster movement, temporary extra "eyes", etc.)

func _pick_new_wander_target() -> void:
	# Simple random point within a radius of current position or tank center
	var center: Vector2 = _tank_center if _tank_center != Vector2.ZERO else global_position
	var angle: float = randf() * TAU
	var dist: float = randf_range(40.0, wander_radius)

	_wander_target = center + Vector2(cos(angle), sin(angle)) * dist
	_wander_timer = randf_range(2.5, 5.5)

func _update_food_target() -> void:
	if _current_food_target and is_instance_valid(_current_food_target) and not _is_food_collected(_current_food_target):
		# Check for collision "bump" while close
		var dist := global_position.distance_to(_current_food_target.global_position)
		if dist < _eat_radius:
			_hits_on_current_food += 1
			# Visual bump feedback (subtle scale on pet)
			if _body:
				var bump := create_tween()
				bump.tween_property(_body, "scale", Vector2(1.15, 0.85), 0.06)
				bump.tween_property(_body, "scale", Vector2.ONE, 0.12)

			if _hits_on_current_food >= _get_required_hits():
				_eat_current_food()
			return

	# Find closest valid food (prefer STARTER packets for the opening demo)
	var closest: Node = null
	var closest_dist := 9999.0

	# Find candidates: prefer group (added by Organ), fallback to layer walk
	var candidates: Array = get_tree().get_nodes_in_group("organs")
	if candidates.is_empty() and _controller and _controller.has_node("Entities"):
		var entities := _controller.get_node("Entities")
		for child in entities.get_children():
			if is_instance_valid(child) and child is Area2D and child.has_method("collect") and "type" in child:
				if not _is_food_collected(child):
					candidates.append(child)

	for food in candidates:
		if _is_food_collected(food):
			continue
		var d := global_position.distance_to(food.global_position)
		if d < closest_dist and d < 320.0:
			closest_dist = d
			closest = food

	_current_food_target = closest
	_hits_on_current_food = 0

func _is_food_collected(food: Node) -> bool:
	if food == null or not is_instance_valid(food):
		return true
	# Organ has private _collected
	if "_collected" in food and food._collected:
		return true
	return false

func _get_required_hits() -> int:
	if current_stage == GameEnums.EvolutionStage.LARVAL:
		return _eats_required_for_larva
	return 2  # later stages eat faster

func _eat_current_food() -> void:
	if _current_food_target == null or not is_instance_valid(_current_food_target):
		return

	var food_type: int = GameEnums.OrganType.TENTACLE
	if "type" in _current_food_target:
		food_type = _current_food_target.type

	# Call the authoritative resource generator (only place Insight should come from)
	if _game_manager and _game_manager.has_method("register_pet_consumed_organ"):
		var pet_data := {
			"species": "sea_monkey",
			"stage": current_stage,
			"pet_name": pet_name
		}
		_game_manager.register_pet_consumed_organ(pet_data, food_type)

		# Demo title change on first eat
		if _game_manager.has_method("mark_first_pet_hatched") and not _game_manager.first_pet_hatched:
			_game_manager.mark_first_pet_hatched()

	# Remove the food (the "eat")
	if _current_food_target.has_method("collect"):
		_current_food_target.collect()
	else:
		_current_food_target.queue_free()

	# Comic MUNCH effect + tiny growth
	feed(1)  # reuses growth + the bridge (but register already called, bridge is idempotent-ish)

	if _controller and _controller.has_method("_spawn_floating_text"):
		_controller._spawn_floating_text("MUNCH!", global_position + Vector2(-20, -30), Color(0.9, 0.85, 0.5), 1.1)

	_current_food_target = null
	_hits_on_current_food = 0

	print("[Pet] ", pet_name, " ate via collisions!")

func _on_interact_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_pet_clicked()

func _on_pet_clicked() -> void:
	print("[Pet] ", pet_name, " clicked. Current stage: ", GameEnums.EvolutionStage.keys()[current_stage], ", Organs fed: ", organs_fed)

	if _controller and _controller.has_method("try_feed_held_to_pet"):
		_controller.try_feed_held_to_pet(self)
	elif _game_manager != null and _game_manager.has_method("get_resource"):
		# Debug fallback feed. In full vision the larva should primarily eat autonomously via collisions.
		# This path is for testing growth/evolution visuals only during transition.
		feed(1)

## Feed / grow this pet.
## Legacy: called from held-organ direct path.
## Target (v1.3+): called internally by the Pet itself when it completes the required number of collisions with an attractive food item.
## After successful eat, the Pet should call _game_manager.register_pet_consumed_organ(...) with its data so resources are generated.
func feed(organ_count: int = 1) -> void:
	organs_fed += organ_count

	# Growth feedback
	var scale_factor: float = 1.0 + (organs_fed * 0.04)
	scale_factor = min(scale_factor, 2.2)
	scale = Vector2(scale_factor, scale_factor)

	# Change color slightly toward the uncanny
	if _body and current_stage < GameEnums.EvolutionStage.ELDRITCH:
		_body.color = _body.color.lerp(Color(0.5, 0.3, 0.6), 0.15)

	print("[Pet] ", pet_name, " fed. Total organs: ", organs_fed)

	# Bridge during transition: make legacy feed also trigger the proper consumption resource path
	# so you can still earn Insight while testing growth. Remove or gate behind a flag once real collision eating exists.
	if _game_manager and _game_manager.has_method("register_pet_consumed_organ"):
		var pet_data := {
			"species": "sea_monkey",  # placeholder until we have real species
			"stage": current_stage,
			"pet_name": pet_name
		}
		# Use a generic organ type for legacy; real calls will pass the actual eaten organ.
		_game_manager.register_pet_consumed_organ(pet_data, GameEnums.OrganType.TENTACLE)

		# Demo the dynamic title change: mark first hatch on first successful eat of the starter pet.
		if _game_manager.has_method("mark_first_pet_hatched") and not _game_manager.first_pet_hatched:
			_game_manager.mark_first_pet_hatched()

	_check_for_evolution()

func _check_for_evolution() -> void:
	if organs_fed >= organs_to_next_stage and current_stage < GameEnums.EvolutionStage.ELDRITCH:
		_evolve()

func _evolve() -> void:
	current_stage += 1
	organs_fed = 0  # Reset counter for next stage (or carry over partially)
	organs_to_next_stage = int(organs_to_next_stage * 1.6) + 2

	print_rich("[EVOLUTION] ", pet_name, " has reached ", GameEnums.EvolutionStage.keys()[current_stage], "!")

	# Big juicy evolution moment
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.6, 0.2)
	tween.tween_property(self, "scale", scale * 0.9, 0.15)
	tween.tween_property(self, "scale", scale, 0.25)

	# TODO: Swap sprite / play evolution VFX / trigger a madness-flavored popup
	# TODO: Unlock new abilities or passive resource generation based on stage

	if _game_manager:
		if _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.VOID_ESSENCE, 1)
		if _game_manager.has_method("trigger_madness_event"):
			_game_manager.trigger_madness_event(pet_name + " briefly existed in three places at once.")

# Future expansion:
# - Different species with unique feeding preferences and abilities
# - Synergies when multiple pets are near each other
# - Personality quirks (some hate pollution, some love it)