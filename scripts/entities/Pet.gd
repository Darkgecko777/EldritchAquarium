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
var _body: CanvasItem

# === AUTONOMOUS EATING (collision-based, only source of Insight per v1.3) ===
var _current_food_target: Node = null
var _hits_on_current_food: int = 0
var _eats_required_for_larva: int = 1  # one bite per homing session; organ controls how many bites it takes
var _eat_radius: float = 22.0  # distance at which a "collision"/bump is counted
var _seek_speed_multiplier: float = 1.0  # larva is eager

# Hunger system: individual timers that make pets seek food when hungry
var hunger: float = 0.0
var hunger_increase_rate: float = 0.8  # per second; tuned so ~10s between bites for 45-60s total consumption of starters
var hunger_to_seek: float = 8.0
var hunger_max: float = 40.0
var _was_in_eat_range: bool = false  # for counting discrete collisions on enter

func _ready() -> void:
	_body = get_node_or_null("Body")
	if _body == null:
		var rect := ColorRect.new()
		rect.name = "Body"
		rect.size = Vector2(50, 50)
		rect.position = Vector2(-25, -25)
		rect.color = Color(0.4, 0.7, 0.5)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_body = rect

	# Make the pet clickable for future "inspect" or direct feed UI
	var area: Area2D = Area2D.new()
	area.name = "InteractArea"
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 30
	area.add_child(shape)
	add_child(area)

	area.input_event.connect(_on_interact_area_input)
	area.input_pickable = true

	_pick_new_wander_target()

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller

	# Larval Sea Monkey (the first one from the ad) is particularly driven toward food
	if current_stage == GameEnums.EvolutionStage.LARVAL:
		_seek_speed_multiplier = 1.35
		swim_speed = max(swim_speed, 78.0)
		hunger = 12.0  # start somewhat hungry

	hunger = randf_range(3.0, 10.0)  # individual starting hunger
	if current_stage == GameEnums.EvolutionStage.LARVAL:
		hunger = max(hunger, 10.0)

func _physics_process(delta: float) -> void:
	if _game_manager == null:
		return

	# Update hunger - individual timer per pet
	hunger = min(hunger_max, hunger + delta * hunger_increase_rate)

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()

	# Only seek food when hungry (or already have a target to finish eating)
	var hungry := hunger > hunger_to_seek
	if hungry or _current_food_target != null:
		_update_food_target()
	else:
		_current_food_target = null
		_hits_on_current_food = 0
		_was_in_eat_range = false

	var direction: Vector2

	if _current_food_target and is_instance_valid(_current_food_target) and not _is_food_collected(_current_food_target):
		# Strong seek toward food for the autonomous collision demo
		direction = (_current_food_target.global_position - global_position).normalized()
	else:
		# Normal wander
		direction = (_wander_target - global_position).normalized()
		_current_food_target = null
		_hits_on_current_food = 0
		_was_in_eat_range = false

	var speed_mult := 1.0
	if _current_food_target:
		speed_mult = 1.6 if current_stage == GameEnums.EvolutionStage.LARVAL else 1.2
	var effective_speed: float = swim_speed * speed_mult * _seek_speed_multiplier

	velocity = direction * effective_speed

	# Very basic "stay in water" — controller can provide better clamping
	move_and_slide()

	if _controller and _controller.has_method("clamp_to_tank"):
		global_position = _controller.clamp_to_tank(global_position)

	# Gentle bobbing / idle animation on the visual
	if _body:
		var bob: float = sin(Time.get_ticks_msec() / 420.0) * 1.5
		if _body is Sprite2D:
			_body.position = Vector2(0, bob)
		else:
			_body.position = Vector2(-25, -25 + bob)

	# TODO: React to high pollution (faster movement, temporary extra "eyes", etc.)

func _pick_new_wander_target() -> void:
	# Simple random point within a radius of current position or tank center
	var center: Vector2 = _tank_center if _tank_center != Vector2.ZERO else global_position
	var angle: float = randf() * TAU
	var dist: float = randf_range(40.0, wander_radius)

	_wander_target = center + Vector2(cos(angle), sin(angle)) * dist
	_wander_timer = randf_range(2.5, 5.5)

func _update_food_target() -> void:
	var is_hungry := hunger > hunger_to_seek
	if _current_food_target and is_instance_valid(_current_food_target) and not _is_food_collected(_current_food_target):
		# Check for collision "bump" - count only on ENTERING the radius (discrete collisions)
		var target := _current_food_target as Node2D
		var dist: float = global_position.distance_to(target.global_position if target else global_position)
		var now_close := dist < _eat_radius
		if now_close and not _was_in_eat_range:
			_was_in_eat_range = true
			_hits_on_current_food += 1
			# Visual bump feedback (subtle scale on pet visual) - relative to current to avoid exploding sprite size
			if _body:
				var current_scale: Vector2 = _body.scale
				var bump := create_tween()
				bump.tween_property(_body, "scale", current_scale * Vector2(1.15, 0.85), 0.06)
				bump.tween_property(_body, "scale", current_scale, 0.12)

			# Notify organ to shrink and emit small resource on collision (per bite)
			var organ_finished := false
			if _current_food_target.has_method("on_pet_bump"):
				_current_food_target.on_pet_bump(self)
				if _current_food_target.has_method("get_remaining_bites"):
					organ_finished = _current_food_target.get_remaining_bites() <= 0
				elif "_collected" in _current_food_target:
					organ_finished = _current_food_target._collected

			# Small repulsion on bump so it doesn't stick (encourages multiple collisions)
			var t := _current_food_target as Node2D
			var target_pos := t.global_position if t else global_position
			var away: Vector2 = (global_position - target_pos).normalized()
			velocity += away * 80.0

			# For larva: each homing = one bite. If this bite finished the organ, full eat; else sate and wander until hungry again.
			if organ_finished:
				_eat_current_food()
			else:
				# Partial bite on multi-bite organ: sate for now, wander randomly until hunger builds for next bite
				hunger = 0.0
				_current_food_target = null
				_hits_on_current_food = 0
				_was_in_eat_range = false
				return
			return
		elif not now_close:
			_was_in_eat_range = false

		if not is_hungry:
			_current_food_target = null
			_hits_on_current_food = 0
			_was_in_eat_range = false
			return

	# Find closest valid food only if hungry
	if not is_hungry:
		_current_food_target = null
		_hits_on_current_food = 0
		_was_in_eat_range = false
		return

	# Find closest valid food (prefer STARTER packets for the opening demo)
	var closest: Node = null
	var closest_dist: float = 9999.0

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
		var f := food as Node2D
		var d: float = global_position.distance_to(f.global_position if f else global_position)
		if d < closest_dist and d < 320.0:
			closest_dist = d
			closest = food

	_current_food_target = closest
	_hits_on_current_food = 0
	_was_in_eat_range = false

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

		# The +1 final bonus insight is added here (appropriate amount for the consume event).
		# No separate token spawn (to keep visual releases one-at-a-time from the bite tokens);
		# the label juice/pop in ResourceDisplay will still provide feedback on the increment.

		# Demo title change on first eat
		if _game_manager.has_method("mark_first_pet_hatched") and not _game_manager.first_pet_hatched:
			_game_manager.mark_first_pet_hatched()

	# Remove the food (the "eat") -- use non-legacy path so no extra biomass/pollution spam
	if _current_food_target.has_method("collect"):
		_current_food_target.collect(false)
	else:
		_current_food_target.queue_free()

	# Comic MUNCH effect + tiny growth
	feed(1, true)  # skip the inner register call (we already did the authoritative one above for the collision consume)

	if _controller and _controller.has_method("_spawn_floating_text"):
		_controller._spawn_floating_text("MUNCH!", global_position + Vector2(-20, -30), Color(0.9, 0.85, 0.5), 1.1)

	# Reduce hunger after successful eat (sate after finishing an organ)
	hunger = 0.0

	_current_food_target = null
	_hits_on_current_food = 0
	_was_in_eat_range = false

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
## Legacy: called from held-organ direct path (will trigger register unless skipped).
## Target (v1.3+): called internally by the Pet itself when it completes the required number of collisions with an attractive food item.
## After successful eat (from _eat_current_food), the register is called explicitly first, then feed(..., true) to skip duplicate.
## The register adds the small final +1 "appropriate amount" on consume.
func feed(organ_count: int = 1, skip_consume_register: bool = false) -> void:
	organs_fed += organ_count

	# Growth feedback
	var scale_factor: float = 1.0 + (organs_fed * 0.04)
	scale_factor = min(scale_factor, 2.2)
	scale = Vector2(scale_factor, scale_factor)

	# Change color slightly toward the uncanny (only for primitive rect fallback)
	if _body is ColorRect and current_stage < GameEnums.EvolutionStage.ELDRITCH:
		_body.color = _body.color.lerp(Color(0.5, 0.3, 0.6), 0.15)

	print("[Pet] ", pet_name, " fed. Total organs: ", organs_fed)

	# Bridge during transition: make legacy feed also trigger the proper consumption resource path
	# so you can still earn Insight while testing growth. Remove or gate behind a flag once real collision eating exists.
	if not skip_consume_register and _game_manager and _game_manager.has_method("register_pet_consumed_organ"):
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

	# Reduce hunger on legacy feed too
	hunger = max(0.0, hunger - 10.0)

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