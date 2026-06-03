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

func _physics_process(delta: float) -> void:
	if _game_manager == null:
		return

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()

	# Simple steering toward wander target
	var direction: Vector2 = (_wander_target - global_position).normalized()
	velocity = direction * swim_speed

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
		# Debug fallback feed
		if _game_manager.get_resource(GameEnums.ResourceType.BIOMASS) > 0:
			feed(1)

## Feed this pet. Called from Organ collection or drag-drop later.
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