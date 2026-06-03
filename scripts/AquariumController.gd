# scripts/AquariumController.gd
# Main scene controller for the underwater tank.
# Attach this to your root Node2D scene (e.g. Aquarium.tscn).
# Responsibilities:
# - Spawns and manages containers
# - Handles test input for ordering shipments (Space or button)
# - Wires up pets, organs, pollution reactions
# - Contains the "physical" play space
extends Node2D

@export_group("Spawning")
@export var shipping_container_scene: PackedScene
@export var organ_scene: PackedScene
@export var pet_scene: PackedScene

@export_group("Tank Settings")
@export var tank_top_y: float = -300.0
@export var tank_bottom_y: float = 280.0
@export var spawn_x_min: float = -400.0
@export var spawn_x_max: float = 400.0

@export_group("Debug")
@export var enable_test_input: bool = true

var _game_manager: Node
var _entities_layer: Node
var _pets_layer: Node

# Held organ for feeding (simple mouse-follow "inventory" using primitives)
var held_organ_type: int = -1
var held_organ_value: int = 0
var held_indicator: ColorRect

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager == null:
		printerr("GameManager autoload not found! Make sure it is registered in Project Settings > Autoload.")

	# Fallbacks so the scene is playable even if the PackedScenes aren't assigned in the inspector yet
	if shipping_container_scene == null:
		shipping_container_scene = load("res://scenes/entities/ShippingContainer.tscn")
	if organ_scene == null:
		organ_scene = load("res://scenes/entities/Organ.tscn")
	if pet_scene == null:
		pet_scene = load("res://scenes/entities/Pet.tscn")

	# Create a simple held organ indicator (primitive, follows mouse when you have an organ picked up)
	# Add to UI layer so it's always on top and uses screen coordinates
	var ui_layer = get_node_or_null("UI")
	held_indicator = ColorRect.new()
	held_indicator.size = Vector2(18, 14)
	held_indicator.visible = false
	held_indicator.z_index = 100
	if ui_layer:
		ui_layer.add_child(held_indicator)
	else:
		add_child(held_indicator)

	# Create layers if they don't exist in the scene tree
	_entities_layer = get_node_or_null("Entities")
	if _entities_layer == null:
		_entities_layer = Node.new()
		_entities_layer.name = "Entities"
		add_child(_entities_layer)

	_pets_layer = get_node_or_null("Pets")
	if _pets_layer == null:
		_pets_layer = Node.new()
		_pets_layer.name = "Pets"
		add_child(_pets_layer)

	# Connect to manager signals (GDScript style)
	if _game_manager:
		if _game_manager.has_signal("shipment_ordered"):
			_game_manager.shipment_ordered.connect(_on_shipment_ordered)
		if _game_manager.has_signal("pollution_changed"):
			_game_manager.pollution_changed.connect(_on_pollution_changed)

	# Wire the Order button from the scene (if present)
	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn:
		_style_order_button(order_btn)
		order_btn.pressed.connect(_on_order_button_pressed)

	# Wire the primitive MENU button (top right)
	var menu_btn: Button = get_node_or_null("UI/MenuButton")
	if menu_btn:
		_style_menu_button(menu_btn)
		menu_btn.pressed.connect(_on_menu_button_pressed)

	# TODO: Spawn initial starter pets here (1-2 larval pets)
	_spawn_starter_pet()

	print("[AquariumController] Ready. Press SPACE (if enabled) or use the Order button to drop containers.")

func _process(_delta: float) -> void:
	if held_organ_type != -1 and held_indicator and is_instance_valid(held_indicator):
		held_indicator.position = get_viewport().get_mouse_position() - held_indicator.size / 2

func _unhandled_input(event: InputEvent) -> void:
	if not enable_test_input:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo):
		if _game_manager and _game_manager.has_method("order_shipment"):
			_game_manager.order_shipment()
		get_viewport().set_input_as_handled()

	# Quick debug: right click to add biomass
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if held_organ_type != -1:
			# Cancel held organ
			held_organ_type = -1
			held_organ_value = 0
			if held_indicator:
				held_indicator.visible = false
		elif _game_manager and _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, 25)

func _on_order_button_pressed() -> void:
	if _game_manager and _game_manager.has_method("order_shipment"):
		_game_manager.order_shipment()

func _on_shipment_ordered() -> void:
	if shipping_container_scene == null:
		printerr("ShippingContainerScene not assigned in AquariumController inspector!")
		return

	# Spawn a container that "drops" from the top
	var container: Node = shipping_container_scene.instantiate()
	_entities_layer.add_child(container)

	var x: float = randf_range(spawn_x_min, spawn_x_max)
	var spawn_pos: Vector2 = Vector2(x, tank_top_y - 80.0)

	container.global_position = spawn_pos
	if container.has_method("initialize"):
		container.initialize(self, organ_scene)  # Pass controller + organ scene so it can spawn organs on open

	print("[AquariumController] Container dropped at ", spawn_pos)

func _on_pollution_changed(new_pollution: float) -> void:
	# React to high pollution with humorous effects
	if new_pollution > 65.0 and randf() < 0.15:
		if _game_manager and _game_manager.has_method("trigger_madness_event"):
			_game_manager.trigger_madness_event("A faint whisper echoes through the tank... your UI feels watched.")
		# TODO: Trigger actual visual madness (screen shake, temporary sprite swap, etc.)

## Called by ShippingContainer when it is opened.
## Spawns organs at the container's location.
func spawn_organs_from_container(position: Vector2, count: int = 3) -> void:
	if organ_scene == null:
		printerr("OrganScene not assigned!")
		return

	for i in range(count):
		var organ: Node = organ_scene.instantiate()
		_entities_layer.add_child(organ)

		# Slight random offset so they don't stack perfectly
		var offset: Vector2 = Vector2(
			randf_range(-30, 30),
			randf_range(-10, 40)
		)

		organ.global_position = position + offset
		if organ.has_method("initialize"):
			organ.initialize(_game_manager, self)

func pickup_organ(organ_type: int, value: int, organ_node: Node = null) -> void:
	"""Pick up an organ for feeding (instead of auto-collecting to inventory)."""
	if held_organ_type != -1:
		return  # already holding something

	held_organ_type = organ_type
	held_organ_value = value

	if organ_node and is_instance_valid(organ_node):
		organ_node.queue_free()

	if held_indicator:
		held_indicator.visible = true
		held_indicator.color = _get_organ_color(organ_type)

	# Give the base biomass immediately (or move this to feed time)
	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, value)

func _get_organ_color(organ_type: int) -> Color:
	match organ_type:
		GameEnums.OrganType.EYE:
			return Color(0.9, 0.3, 0.3)
		GameEnums.OrganType.HEART:
			return Color(0.6, 0.1, 0.2)
		GameEnums.OrganType.NEURAL_CLUSTER:
			return Color(0.4, 0.8, 0.9)
		GameEnums.OrganType.SCALE:
			return Color(0.3, 0.6, 0.5)
		_:
			return Color(0.7, 0.5, 0.6)

func try_feed_held_to_pet(pet: Node) -> void:
	"""Feed the currently held organ to the given pet."""
	if held_organ_type == -1 or not pet:
		return

	if pet.has_method("feed"):
		pet.feed(1)  # base growth; could scale with held_organ_value or type

	# Bonus resources or effects based on organ type could go here
	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(GameEnums.ResourceType.VOID_ESSENCE, 1)  # small bonus on feed

	# Clear held state
	held_organ_type = -1
	held_organ_value = 0
	if held_indicator:
		held_indicator.visible = false

func _spawn_starter_pet() -> void:
	if pet_scene == null:
		print("[AquariumController] No PetScene assigned — skipping starter pet (add one in inspector later).")
		return

	var pet: Node = pet_scene.instantiate()
	_pets_layer.add_child(pet)

	# Place it in a nice starting spot
	pet.global_position = Vector2(0, 100)
	if pet.has_method("initialize"):
		pet.initialize(_game_manager, self)

## Helper for other objects to stay inside the tank area.
func clamp_to_tank(pos: Vector2) -> Vector2:
	var x: float = clamp(pos.x, spawn_x_min, spawn_x_max)
	var y: float = clamp(pos.y, tank_top_y, tank_bottom_y)
	return Vector2(x, y)

# === TITLE SCREEN INTEGRATION (pure shape UI) ===

## Call this to return to the title screen. Can be wired from a menu button.
func return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _on_menu_button_pressed() -> void:
	return_to_title()

func _style_menu_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.92)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.45, 0.6, 0.7)

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

func _style_order_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.22, 0.28, 0.95)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.4, 0.65, 0.75, 0.6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.32, 0.38, 0.98)
	hover.border_color = Color(0.55, 0.8, 0.9, 0.85)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)