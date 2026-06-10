extends CharacterBody2D

@export var pet_name: String = "Unnamed Horror"
@export var current_stage: GameEnums.EvolutionStage = GameEnums.EvolutionStage.LARVAL
@export var species: GameEnums.PetSpecies = GameEnums.PetSpecies.FREAKY_GOLDFISH  # gold starter default for this playloop revision

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

# Smoother pathing state (reduces jitter when idling or switching targets)
var _smoothed_velocity: Vector2 = Vector2.ZERO
var _arrival_radius: float = 50.0  # larger for ~100px sprite fish
var _idle_damping: float = 6.0
var _steering_accel: float = 11.0  # higher = snappier, lower = floatier/smoother
var _bump_kick: Vector2 = Vector2.ZERO  # decayed external impulse from collisions

# === AUTONOMOUS EATING (collision-based, only source of Insight per v1.3) ===
var _current_food_target: Node = null
var _hits_on_current_food: int = 0
var _eats_required_for_larva: int = 1  # one bite per homing session; organ controls how many bites it takes
var _eat_radius: float = 50.0  # distance at which a "collision"/bump is counted (larger for ~100px sprite fish)
var _seek_speed_multiplier: float = 1.0  # larva is eager

# Hunger timer (individual per pet). When >= hunger_timer_max the pet seeks nearest food (organs group).
# Resets to 0 on consumption (full eat or per-bite for multi-bite organs). Default 5s per spec.
@export_group("Hunger")
@export var hunger_timer_max: float = 7.5  # seconds until max hunger; pet seeks nearest food at/after this (increased 50% for goldfish)
var hunger_timer: float = 0.0
var _hunger_bar_bg: ColorRect
var _hunger_bar_fill: ColorRect

var _was_in_eat_range: bool = false  # for counting discrete collisions on enter

# Hold-to-tend support (4x hunger rate when player holds LMB on this pet)
var hunger_rate_multiplier: float = 1.0
var _original_body_color: Color = Color(1.0, 0.65, 0.2)

func _ready() -> void:
	_body = get_node_or_null("Sprite") as CanvasItem
	if _body == null:
		# Use the newly added Goldfish_Stage_One_Idle sprite sequence (53 frames) for the base normal goldfish animation.
		# This replaces the previous primitive ColorRect visuals. The animation provides the swimming/idle motion.
		# Later evolution stages can swap to different sprite sets or add effects on top.
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)

		var sprite_frames := SpriteFrames.new()
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_loop("idle", true)
		sprite_frames.set_animation_speed("idle", 12.0)  # ~4.4s loop for 53 frames; smooth idle swim

		for i in range(1, 54):
			var path := "res://assets/sprites/pets/starter/Goldfish_Stage_One_Idle/%04d.png" % i
			var tex := load(path) as Texture2D
			if tex:
				sprite_frames.add_frame("idle", tex)

		sprite.sprite_frames = sprite_frames
		sprite.play("idle")

		# Center the sprite on the pet origin using offset (frames are drawn from top-left by default)
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			var frame_count: int = sprite.sprite_frames.get_frame_count("idle")
			if frame_count > 0:
				var first_tex: Texture2D = sprite.sprite_frames.get_frame_texture("idle", 0)
				if first_tex:
					var native_size = first_tex.get_size()
					# Base centering for the frame (top-left origin)
					sprite.offset = -native_size / 2.0

					# Scale the goldfish to roughly 100x100 pixels (maintain aspect)
					var target_size = 100.0
					var sf = target_size / max(native_size.x, native_size.y)
					sprite.scale = Vector2(sf, sf)

					# Additional alignment in final pixels to center the fish art (not the whole frame) on the pet origin (0,0).
					# This aligns the visual goldfish with the collision shape (InteractArea circle at (0,0)) and the hunger bar.
					# The shift (120, -120) is based on the screenshot with collision debug: move sprite visual +120 X, -120 Y.
					var alignment_final = Vector2(120, -120)
					var alignment_in_texture = alignment_final / sf
					sprite.offset += alignment_in_texture

		_body = sprite
		_original_body_color = Color(1, 1, 1)

	_ensure_hunger_bar()

	# Make the pet clickable for future "inspect" or direct feed UI
	# Reuse existing InteractArea from scene if present (to avoid duplicates), otherwise create.
	var area: Area2D = get_node_or_null("InteractArea")
	if area == null:
		area = Area2D.new()
		area.name = "InteractArea"
		add_child(area)

	# Ensure a collision shape with appropriate radius for the ~100px fish.
	var shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D")
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		area.add_child(shape)
	var circ := CircleShape2D.new()
	circ.radius = 60  # sized for ~100px goldfish visual (covers the sprite + some margin for interaction)
	shape.shape = circ

	area.input_event.connect(_on_interact_area_input)
	area.input_pickable = true

	# Ensure hunger bar is positioned under the newly scaled sprite immediately
	_update_hunger_bar()

	_pick_new_wander_target()

func initialize(game_manager: Node, controller: Node = null) -> void:
	_game_manager = game_manager
	_controller = controller

	# v1.6: The specimen starts as a normal, formed goldfish (not a hyper-eager larva fresh from an egg).
	# Hunger bias is mild so it feels like an established fish in the tank that is ready to eat the exotic feed you order.
	# Future species (normal minnow school, normal remora, etc.) will branch here.
	if species == GameEnums.PetSpecies.FREAKY_GOLDFISH:
		_seek_speed_multiplier = 1.15
		swim_speed = max(swim_speed, 72.0)
	else:
		_seek_speed_multiplier = 1.1
		swim_speed = max(swim_speed, 70.0)

	# Individual starting offset so multiple fish won't sync perfectly on the hunger cycle.
	hunger_timer = randf_range(0.4, hunger_timer_max * 0.6)

func _physics_process(delta: float) -> void:
	if _game_manager == null:
		return

	# Update hunger timer - individual per pet. At/above max the pet will seek nearest food.
	# Player can hold LMB on the pet (Goldfish) to run this at 4x rate (faster seeking + eating).
	hunger_timer = min(hunger_timer_max, hunger_timer + delta * hunger_rate_multiplier)

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()

	# Only seek food when hunger is at max (or already have a target to finish eating)
	var hungry := hunger_timer >= hunger_timer_max
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

	# Desired velocity with arrival slowing for smooth stops near targets (big jitter reducer)
	var desired: Vector2 = direction * effective_speed
	var dist_to_target := 9999.0
	if _current_food_target and is_instance_valid(_current_food_target):
		dist_to_target = global_position.distance_to(_current_food_target.global_position)
	elif not _current_food_target:
		# Wander arrival
		dist_to_target = global_position.distance_to(_wander_target)
	if dist_to_target < _arrival_radius and dist_to_target > 1.0:
		desired *= (dist_to_target / _arrival_radius)

	# Apply decayed bump kick (from collisions) then steer smoothly toward desired
	_bump_kick = _bump_kick.lerp(Vector2.ZERO, delta * 7.0)
	var target_vel := desired + _bump_kick

	# Smooth steering (lerp velocity instead of instant snap) — main fix for jittery "in place" behavior
	_smoothed_velocity = _smoothed_velocity.lerp(target_vel, delta * _steering_accel)

	# Extra damping when truly idle (no food target and close to wander point) so it settles instead of micro-jittering
	if not _current_food_target and dist_to_target < 18.0:
		_smoothed_velocity = _smoothed_velocity.lerp(Vector2.ZERO, delta * _idle_damping)

	velocity = _smoothed_velocity

	# Very basic "stay in water" — controller can provide better clamping
	move_and_slide()

	if _controller and _controller.has_method("clamp_to_tank"):
		global_position = _controller.clamp_to_tank(global_position)

	# Gentle bobbing / idle animation on the visual
	if _body:
		var bob: float = sin(Time.get_ticks_msec() / 420.0) * 1.5
		if _body is AnimatedSprite2D or _body is Sprite2D:
			# Bob the pivot (0,0) + small Y bob. The fish visual is centered on the pivot via offset (including alignment shift).
			# This keeps the visual goldfish aligned with the collision at pet origin (0,0) and hunger bar under it.
			_body.position = Vector2(0, bob)
		else:
			_body.position = Vector2(-21, -14 + bob)  # legacy primitive support

	_update_hunger_bar()

	# TODO: React to high pollution (faster movement, temporary extra "eyes", etc.)

func _pick_new_wander_target() -> void:
	# Simple random point within a radius of current position or tank center
	var center: Vector2 = _tank_center if _tank_center != Vector2.ZERO else global_position
	var angle: float = randf() * TAU
	var dist: float = randf_range(40.0, wander_radius)

	_wander_target = center + Vector2(cos(angle), sin(angle)) * dist
	_wander_timer = randf_range(2.5, 5.5)

func _ensure_hunger_bar() -> void:
	if get_node_or_null("HungerBarBG") != null:
		return
	var bg := ColorRect.new()
	bg.name = "HungerBarBG"
	bg.size = Vector2(70, 6)  # wider for ~100px goldfish
	bg.position = Vector2(-34, 30)  # initial for ~100px fish centered at (0,0); will be adjusted in _update_hunger_bar based on bob + scale
	bg.color = Color(0.10, 0.07, 0.05, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_hunger_bar_bg = bg

	var fill := ColorRect.new()
	fill.name = "HungerBarFill"
	fill.size = Vector2(68, 4)
	fill.position = Vector2(1, 1)
	fill.color = Color(0.92, 0.62, 0.25)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	_hunger_bar_fill = fill

func _update_hunger_bar() -> void:
	if _hunger_bar_fill == null or _hunger_bar_bg == null:
		return
	var t: float = 0.0
	if hunger_timer_max > 0.0:
		t = clampf(hunger_timer / hunger_timer_max, 0.0, 1.0)

	# Keep bar roughly under the (bobbing) visual
	var bar_base_width := 68.0
	if _body:
		var body_h: float = 14.0
		var body_bottom: float = _body.position.y + body_h + 2.0
		if _body is ColorRect:
			body_h = _body.size.y
			body_bottom = _body.position.y + body_h + 2.0
			bar_base_width = 36.0  # legacy small bar for primitive
		elif _body is AnimatedSprite2D or _body is Sprite2D:
			# Use current (scaled) frame size for accurate under-body placement
			var tex_size := Vector2(40, 26)
			if _body is AnimatedSprite2D and _body.sprite_frames != null:
				var anim: String = "idle"
				if _body.sprite_frames.has_animation(anim):
					var fcount: int = _body.sprite_frames.get_frame_count(anim)
					if fcount > 0:
						var fidx: int = clampi(_body.frame, 0, fcount - 1)
						var tex: Texture2D = _body.sprite_frames.get_frame_texture(anim, fidx)
						if tex:
							tex_size = tex.get_size()
			# Account for the scale we applied to the sprite (so bar sits under the rendered ~100px fish)
			var scaled_h = tex_size.y * _body.scale.y
			body_bottom = _body.position.y + scaled_h / 2.0 + 4.0
			bar_base_width = 68.0
			# Center the bar under the sprite (sprite position is 0 + bob, visual centered via offset + alignment)
			_hunger_bar_bg.position.x = -bar_base_width / 2.0

		_hunger_bar_bg.position.y = max(14.0, body_bottom)

	# Set proportional bar width (after positioning logic so we have the right base)
	_hunger_bar_bg.size.x = bar_base_width
	_hunger_bar_fill.size.x = (bar_base_width - 2.0) * t
	_hunger_bar_fill.position.x = 1.0

	# Subtle hungry shift (amber calm → warning red as hunger maxes)
	if t >= 0.85:
		_hunger_bar_fill.color = Color(0.85, 0.28, 0.22)
	elif t >= 0.55:
		_hunger_bar_fill.color = Color(0.95, 0.72, 0.25)
	else:
		_hunger_bar_fill.color = Color(0.92, 0.62, 0.25)

func _update_food_target() -> void:
	var is_hungry: bool = hunger_timer >= hunger_timer_max
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

			# Small repulsion on bump so it doesn't stick (encourages multiple collisions).
			# Feed into _bump_kick so the steering lerp smooths it out instead of causing velocity snap/jitter.
			var t: Node2D = _current_food_target as Node2D
			var target_pos: Vector2 = t.global_position if t else global_position
			var away: Vector2 = (global_position - target_pos).normalized()
			_bump_kick += away * 55.0  # a bit gentler; steering will blend it nicely

			# For larva: each homing = one bite. If this bite finished the organ, full eat; else sate and wander until hungry again.
			if organ_finished:
				_eat_current_food()
			else:
				# Partial bite on multi-bite organ: sate (reset timer), wander randomly until hunger timer builds again for next bite
				hunger_timer = 0.0
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

	# Find closest valid food.
	# We now use the controller's get_valid_food_in_tank() so pets reliably detect
	# ANY valid uneaten food that is inside the tank bounds (no more missed food due to
	# group timing, bounce distance, or outdated Area2D fallback).
	var closest: Node = null
	var closest_dist: float = 9999.0

	var candidates: Array = []
	if _controller and _controller.has_method("get_valid_food_in_tank"):
		candidates = _controller.get_valid_food_in_tank()
	if candidates.is_empty():
		# Fallback to group for robustness (e.g. during init or if controller not ready)
		candidates = get_tree().get_nodes_in_group("organs")

	for food in candidates:
		if _is_food_collected(food):
			continue
		var f := food as Node2D
		var d: float = global_position.distance_to(f.global_position if f else global_position)
		var pref_bonus := _get_food_preference_score(food)  # goldfish medium bias (minimal size hint preview)
		var effective_d := d + pref_bonus
		if effective_d < closest_dist:
			closest_dist = effective_d
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

# Minimal preference bias for the gold starter (Freaky Goldfish = medium).
# Returns a score modifier (lower is better for "closest" selection) so medium packets win ties.
func _get_food_preference_score(food: Node) -> float:
	if species != GameEnums.PetSpecies.FREAKY_GOLDFISH:
		return 0.0
	if food == null or not is_instance_valid(food):
		return 0.0
	var cat := ""
	if "size_category" in food:
		cat = food.size_category
	if cat == "medium":
		return -45.0  # strong preference for the matched size in the initial playloop
	if cat == "small" or cat == "large":
		return +35.0  # mild penalty (struggles until later evolutions)
	return 0.0

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
			"species": "freaky_goldfish",  # gold starter per Pets.md + current playloop revision
			"stage": current_stage,
			"pet_name": pet_name,
			"species_enum": species
		}
		_game_manager.register_pet_consumed_organ(pet_data, food_type)

		# Biomatter is emitted ONLY when a food source is fully consumed (organ_finished path).
		# Decay produces NO resources (only pollution). Insight is released per-bite in Organ.on_pet_bump().
		if _controller and _controller.has_method("spawn_resource_glob"):
			_controller.spawn_resource_glob(global_position + Vector2(0, 8), 1, GameEnums.ResourceType.ABYSSAL_BIOMATTER)

		# Demo title change on first eat
		if _game_manager.has_method("mark_first_pet_hatched") and not _game_manager.first_pet_hatched:
			_game_manager.mark_first_pet_hatched()

	# Remove the food (the "eat") -- use non-legacy path so no extra biomatter/pollution spam
	if _current_food_target.has_method("collect"):
		_current_food_target.collect(false)
	else:
		_current_food_target.queue_free()

	# Comic MUNCH effect + tiny growth
	feed(1, true)  # skip the inner register call (we already did the authoritative one above for the collision consume)

	if _controller and _controller.has_method("_spawn_floating_text"):
		_controller._spawn_floating_text("MUNCH!", global_position + Vector2(-20, -30), Color(0.9, 0.85, 0.5), 1.1)

	# Reset hunger timer after successful eat (sate after finishing an organ)
	hunger_timer = 0.0

	_current_food_target = null
	_hits_on_current_food = 0
	_was_in_eat_range = false

	# print("[Pet] ", pet_name, " ate via collisions!")  # cleared for resource debug focus

func _on_interact_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Start sustained hold: this accelerates hunger_rate (4x) while LMB is held.
				# This is the core "tend the goldfish" mechanic.
				if _controller and _controller.has_method("start_hold_on"):
					_controller.start_hold_on(self)
				_on_pet_clicked()  # existing click-to-feed-held or debug still works (brief hold is harmless)

func _on_pet_clicked() -> void:
	# print("[Pet] ", pet_name, " clicked. Current stage: ", GameEnums.EvolutionStage.keys()[current_stage], ", Organs fed: ", organs_fed)  # cleared for resource debug focus
	pass
	if _controller and _controller.has_method("try_feed_held_to_pet"):
		_controller.try_feed_held_to_pet(self)
	elif _game_manager != null and _game_manager.has_method("get_resource"):
		# Debug fallback feed. Primary path is autonomous collision eating (the fish works for you).
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

	# Change color slightly toward the uncanny (only for primitive rect fallback; sprites use animation instead)
	if _body is ColorRect and current_stage < GameEnums.EvolutionStage.ELDRITCH:
		_body.color = _body.color.lerp(Color(0.5, 0.3, 0.6), 0.15)

	# print("[Pet] ", pet_name, " fed. Total organs: ", organs_fed)  # cleared for resource debug focus

	# Bridge during transition: make legacy feed also trigger the proper consumption resource path
	# so you can still earn Insight while testing growth. Remove or gate behind a flag once real collision eating exists.
	if not skip_consume_register and _game_manager and _game_manager.has_method("register_pet_consumed_organ"):
		var pet_data := {
			"species": "freaky_goldfish",  # gold starter (distinct primitive playloop)
			"stage": current_stage,
			"pet_name": pet_name,
			"species_enum": species
		}
		# Use a generic organ type for legacy; real calls will pass the actual eaten organ.
		_game_manager.register_pet_consumed_organ(pet_data, GameEnums.OrganType.TENTACLE)

		# Demo the dynamic title change: mark first hatch on first successful eat of the starter pet.
		if _game_manager.has_method("mark_first_pet_hatched") and not _game_manager.first_pet_hatched:
			_game_manager.mark_first_pet_hatched()

	# Reset hunger timer on legacy/manual feed too (full sate)
	hunger_timer = 0.0

	_check_for_evolution()

func _check_for_evolution() -> void:
	if organs_fed >= organs_to_next_stage and current_stage < GameEnums.EvolutionStage.ELDRITCH:
		_evolve()

func _evolve() -> void:
	current_stage += 1
	organs_fed = 0  # Reset counter for next stage (or carry over partially)
	organs_to_next_stage = int(organs_to_next_stage * 1.6) + 2

	# print_rich("[EVOLUTION] ", pet_name, " has reached ", GameEnums.EvolutionStage.keys()[current_stage], "!")  # cleared for resource debug focus

	# Big juicy evolution moment
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.6, 0.2)
	tween.tween_property(self, "scale", scale * 0.9, 0.15)
	tween.tween_property(self, "scale", scale, 0.25)

	# TODO: Swap sprite / play evolution VFX / trigger a madness-flavored popup
	# Mutation visuals: at each stage increase "weirdness" on the primitive (darker/wrong colors, scale up tail, add small extra rects for eyes or tendrils, etc.).
	# The starting visual (in _ready) is deliberately a normal aquarium goldfish.

	if _game_manager:
		if _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 1)
		if _game_manager.has_method("trigger_madness_event"):
			_game_manager.trigger_madness_event(pet_name + " briefly existed in three places at once.")

# Future expansion:
# - Different species with unique feeding preferences and abilities
# - Synergies when multiple pets are near each other
# - Personality quirks (some hate pollution, some love it)

## Called when this pet dies due to pollution threshold (goldfish at 75%, etc.).
## Plays a death visual before removal. The caller (usually AquariumController pollution reaction) is responsible
## for granting the mnemonic fragment so the "why" (pollution threshold) is in one place.
func die_from_pollution() -> void:
	# Death visual + cleanup (keeps it lightweight; controller spawns floating text + grants shard).
	if _body:
		var t := create_tween()
		t.tween_property(_body, "scale", _body.scale * Vector2(0.4, 0.3), 0.15)
		t.parallel().tween_property(_body, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)
	else:
		queue_free()

# Called by AquariumController when player holds/releases LMB on this pet.
# mult = 4.0 while held (accelerates hunger_timer buildup → faster seeking/eating).
# mult = 1.0 when released.
func set_hold_multiplier(mult: float) -> void:
	hunger_rate_multiplier = mult
	_update_hold_visual()

func _update_hold_visual() -> void:
	if _body == null:
		return
	if _body is AnimatedSprite2D:
		if hunger_rate_multiplier > 1.0:
			# Brighter, more "agitated" look while being tended (tint the whole animation)
			_body.modulate = Color(1.3, 1.15, 0.7)
		else:
			_body.modulate = Color(1, 1, 1)
	elif _body is ColorRect:
		if hunger_rate_multiplier > 1.0:
			# Brighter, more "agitated" look while being tended
			_body.color = _original_body_color.lerp(Color(1.0, 0.85, 0.4), 0.7)
		else:
			_body.color = _original_body_color
