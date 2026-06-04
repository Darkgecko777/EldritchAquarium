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
@export var egg_scene: PackedScene  # For the opening comic ad egg (fallback load if not assigned)

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

# === OPENING SEQUENCE (first few moments from comic ad) ===
var _in_opening: bool = false
var _egg_node: Node = null
var _incubating_label: Label = null
var _incubating_bar: ProgressBar = null  # simple visual timer
var _complimentary_claimed: bool = false
var _force_starter_next_drop: bool = false
var _opening_order_button_original_text: String = ""

# Pause state
var _is_paused: bool = false
var _pause_overlay: Control = null

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
	if egg_scene == null:
		egg_scene = load("res://scenes/entities/Egg.tscn")

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

	# Opening sequence or normal starter?
	if _game_manager and _game_manager.get("pending_opening_sequence"):
		_game_manager.pending_opening_sequence = false
		start_opening_sequence()
	else:
		# Normal / continuing run - spawn a generic larval pet (will be replaced by full ad flow later)
		_spawn_starter_pet()

	print("[AquariumController] Ready. Press SPACE (if enabled) or use the Order button to drop containers.")

func _process(_delta: float) -> void:
	if held_organ_type != -1 and held_indicator and is_instance_valid(held_indicator):
		held_indicator.position = get_viewport().get_mouse_position() - held_indicator.size / 2

	# Keep incubation UI in sync during opening (the first few moments)
	if _in_opening:
		_update_incubation_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not enable_test_input:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo):
		if _in_opening and not _complimentary_claimed:
			_claim_complimentary_shipment()
		elif _game_manager and _game_manager.has_method("order_shipment"):
			_game_manager.order_shipment()
		get_viewport().set_input_as_handled()

	# Debug: press T to return to TitleScreen (useful to demo the dynamic comic ad/catalog content after first pet eat).
	if event is InputEventKey and event.keycode == KEY_T and event.pressed:
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
		get_viewport().set_input_as_handled()

	# Quick debug: right click (now mostly for legacy Biomass or pollution testing).
	# Per v1.3: do NOT grant Insight here — only pets eating via collisions generate resources.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if held_organ_type != -1:
			# Cancel held organ
			held_organ_type = -1
			held_organ_value = 0
			if held_indicator:
				held_indicator.visible = false
		elif _game_manager and _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, 25)  # legacy only
			print("[Debug] Right-click added legacy Biomass. Remember: real Insight only comes from pet eating.")

func _on_order_button_pressed() -> void:
	if _in_opening and not _complimentary_claimed:
		_claim_complimentary_shipment()
		return

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
## Enhanced to support the opening sequence: complimentary drop uses unique starter packets
## and any food arrival during incubation reduces the egg timer.
func spawn_organs_from_container(position: Vector2, count: int = 3) -> void:
	if organ_scene == null:
		printerr("OrganScene not assigned!")
		return

	var is_starter_drop := _in_opening and (_force_starter_next_drop or not _complimentary_claimed)

	if is_starter_drop:
		_force_starter_next_drop = false
		_spawn_starter_packets(position)
		# Reduce egg timer because food arrived!
		if _egg_node and _egg_node.has_method("reduce_timer"):
			_egg_node.reduce_timer(10.0)
		return

	# Normal shipment organs - pop out in different directions to occupy space
	for i in range(count):
		var organ: Node = organ_scene.instantiate()
		_entities_layer.add_child(organ)

		# Start at container, pop in random dir (tween would fight organ bobbing, so spread placement)
		var angle := randf() * TAU
		var dist := randf_range(45.0, 95.0)
		var offset := Vector2(cos(angle) * dist, sin(angle) * dist * 0.7)

		organ.global_position = position + offset
		if organ.has_method("initialize"):
			organ.initialize(_game_manager, self)

	# Any food arrival while egg is active helps it hatch sooner (even normal shipments during opening)
	if _in_opening and _egg_node and _egg_node.has_method("reduce_timer"):
		_egg_node.reduce_timer(4.5)

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

	# Legacy direct "pickup into held" path. In v1.3 vision the larva (and all pets) will autonomously collide-eat.
	# Do not grant Insight here. Only the Pet's consumption callback should.
	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(GameEnums.ResourceType.BIOMASS, value)  # legacy raw only
		print("[AquariumController] Held organ picked — legacy Biomass only. No Insight (must be fed/eaten by pet).")

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
		GameEnums.OrganType.STARTER_PRIMAL:
			return Color(0.25, 0.58, 0.22)
		GameEnums.OrganType.STARTER_VOID:
			return Color(0.48, 0.22, 0.65)
		_:
			return Color(0.7, 0.5, 0.6)

func try_feed_held_to_pet(pet: Node) -> void:
	"""Feed the currently held organ to the given pet."""
	if held_organ_type == -1 or not pet:
		return

	if pet.has_method("feed"):
		pet.feed(1)  # base growth; could scale with held_organ_value or type

	# Bonus resources or effects based on organ type could go here.
	# In v1.3 vision, the *only* real economy payout comes from Pet's collision-eating → register_pet_consumed_organ().
	# Legacy direct feed path should eventually be removed or become visual-only (no resource grant).
	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(GameEnums.ResourceType.VOID_ESSENCE, 1)  # small bonus on legacy feed path (temporary)

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

# === FIRST MOMENTS / COMIC AD OPENING SEQUENCE ===

func start_opening_sequence() -> void:
	_in_opening = true
	_complimentary_claimed = false

	print("[AquariumController] Starting comic ad opening sequence (egg + complimentary).")

	# Update instructions to comic ad flavor
	var instr: Label = get_node_or_null("UI/Instructions")
	if instr:
		instr.text = "Your Sea Monkey kit has arrived in the tank...\nWatch the egg incubate.\nCLAIM the complimentary shipment to get food in the water!"

	# Repurpose Order button for the free claim during opening
	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn:
		_opening_order_button_original_text = order_btn.text
		order_btn.text = "CLAIM COMPLIMENTARY SHIPMENT (FREE!)"
		# style it more "ad like" temporarily if wanted

	# Spawn the egg from the "ad" (top centerish)
	if egg_scene == null:
		egg_scene = load("res://scenes/entities/Egg.tscn")
	if egg_scene:
		_egg_node = egg_scene.instantiate()
		_entities_layer.add_child(_egg_node)
		_egg_node.global_position = Vector2(0, tank_top_y - 60)
		if _egg_node.has_method("initialize"):
			_egg_node.initialize(self)
	else:
		# Fallback: build a primitive egg inline (rare)
		_create_fallback_egg()

	# Create simple incubation UI (comic label + progress)
	_create_incubation_ui()

	# Optional: auto-hint or just let player click the (now free) button
	# In a fuller version we could auto-drop the complimentary after a few seconds.

func _create_incubation_ui() -> void:
	var ui_layer := get_node_or_null("UI")
	if ui_layer == null:
		return

	# Big readable "INCUBATING" label (comic style)
	_incubating_label = Label.new()
	_incubating_label.name = "IncubatingLabel"
	_incubating_label.text = "INCUBATING..."
	_incubating_label.position = Vector2(20, 210)
	_incubating_label.add_theme_font_size_override("font_size", 22)
	_incubating_label.modulate = Color(0.95, 0.9, 0.7)
	ui_layer.add_child(_incubating_label)

	# Simple bar to show progress (0 = just started, full = about to hatch)
	_incubating_bar = ProgressBar.new()
	_incubating_bar.name = "IncubatingBar"
	_incubating_bar.position = Vector2(20, 238)
	_incubating_bar.size = Vector2(220, 18)
	_incubating_bar.max_value = 100.0
	_incubating_bar.value = 0.0
	_incubating_bar.show_percentage = false
	ui_layer.add_child(_incubating_bar)

func _update_incubation_ui() -> void:
	if _egg_node and _egg_node.has_method("get_remaining_time") and _incubating_bar:
		var remaining: float = _egg_node.get_remaining_time()
		# Progress = how much time has passed (inverted for bar)
		var progress: float = 1.0 - clamp(remaining / 30.0, 0.0, 1.0)
		_incubating_bar.value = progress * 100.0

		if _incubating_label:
			if remaining < 5:
				_incubating_label.text = "HATCHING ANY MOMENT..."
				_incubating_label.modulate = Color(1, 0.6, 0.5)
			elif remaining < 12:
				_incubating_label.text = "INCUBATING... (something's moving)"
			else:
				_incubating_label.text = "INCUBATING..."

func _claim_complimentary_shipment() -> void:
	if _complimentary_claimed or not _in_opening:
		return

	print("[AquariumController] Claiming complimentary shipment for the opening (unique starter packets).")

	# Force the next drop (the one we just spawned or direct) to use starters.
	_force_starter_next_drop = true

	# Spawn a "free" container visually for the satisfying drop.
	var container: Node = null
	if shipping_container_scene:
		container = shipping_container_scene.instantiate()
		_entities_layer.add_child(container)
		var x: float = randf_range(-150, 150)
		container.global_position = Vector2(x, tank_top_y - 80)
		if container.has_method("initialize"):
			container.initialize(self, organ_scene)
		# spawn_organs will see the force flag and do the two unique packets + reduce timer.
	else:
		_spawn_starter_packets(Vector2(0, 80))

	_complimentary_claimed = true

	# For the opening sequence, auto-open the complimentary container after drop time so the starter packets are guaranteed to be released (clicking should work, but this ensures the first moments flow even if input has prototype issues).
	if container:
		var drop_time := 1.5
		if "drop_duration" in container:
			drop_time = container.drop_duration + 0.5
		var t := get_tree().create_timer(drop_time)
		t.timeout.connect(func():
			if is_instance_valid(container) and container.has_method("open"):
				var is_opened := false
				if "_is_opened" in container:
					is_opened = container._is_opened
				if not is_opened:
					print("[AquariumController] Auto-opening complimentary shipment to release the unique starter packets.")
					container.open()
		)

	# Change button back toward normal (player can still order paid after)
	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn and _opening_order_button_original_text != "":
		order_btn.text = "Order more food (costs Insight)"
	else:
		order_btn.text = "Order Shipment"

	# Immediately help the egg a little (food is "arriving")
	if _egg_node and _egg_node.has_method("reduce_timer"):
		_egg_node.reduce_timer(6.0)

func _spawn_starter_packets(at_position: Vector2) -> void:
	"""Spawns exactly the two unique starter incubation packets for the first egg/larva."""
	if organ_scene == null:
		return

	var starter_types := [
		GameEnums.OrganType.STARTER_PRIMAL,
		GameEnums.OrganType.STARTER_VOID
	]

	for i in range(2):
		var packet: Node = organ_scene.instantiate()
		_entities_layer.add_child(packet)

		# Pop out in different directions for the opening demo
		var angle := randf() * TAU
		var dist := randf_range(50.0, 100.0)
		var offset := Vector2(cos(angle) * dist, sin(angle) * dist * 0.65)
		packet.global_position = at_position + offset

		if packet.has_method("initialize"):
			packet.initialize(_game_manager, self)

		# Force the special starter type (bypass random in Organ._ready)
		if packet.has_method("set_organ_type"):
			packet.set_organ_type(starter_types[i])
		else:
			# Direct set + force visual update if possible
			packet.set("type", starter_types[i])
			if packet.has_method("_update_visual_for_type"):
				packet.call("_update_visual_for_type")

	print("[AquariumController] Spawned 2 unique starter packets at ", at_position)

# Called from Egg when its timer hits zero (or was reduced to zero).
func hatch_egg_at(pos: Vector2) -> void:
	if not _in_opening or _egg_node == null:
		return

	print("[AquariumController] Hatching the first Sea Monkey larva...")

	# Clean incubation UI
	if _incubating_label:
		_incubating_label.queue_free()
		_incubating_label = null
	if _incubating_bar:
		_incubating_bar.queue_free()
		_incubating_bar = null

	# Spawn the special first pet (larva Sea Monkey) - eager, special name
	if pet_scene:
		var larva: Node = pet_scene.instantiate()
		_pets_layer.add_child(larva)
		larva.global_position = pos + Vector2(0, 20)  # slightly below egg

		# Configure as the iconic starter *before* initialize so larval eager logic runs
		if "pet_name" in larva:
			larva.pet_name = "Sea Monkey"
		if "current_stage" in larva:
			larva.current_stage = GameEnums.EvolutionStage.LARVAL
		# Make the larva more driven for the demo (we enhance seeking in Pet.gd)
		if "swim_speed" in larva:
			larva.swim_speed = 85.0

		if larva.has_method("initialize"):
			larva.initialize(_game_manager, self)

		# Mark the hatch for title dynamism and economy
		if _game_manager and _game_manager.has_method("mark_first_pet_hatched"):
			_game_manager.mark_first_pet_hatched()

	# Restore normal order button + instructions
	_restore_normal_ui_after_hatch()

	_in_opening = false
	_egg_node = null

func _restore_normal_ui_after_hatch() -> void:
	var instr: Label = get_node_or_null("UI/Instructions")
	if instr:
		instr.text = "SPACE or Order button: drop container\nWatch your larva seek & eat the starter packets (collisions!)\nEarn Insight only when pets eat."

	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn:
		order_btn.text = "Order Shipment (Insight)"

	# Optional: small comic popup "The kit is alive!"
	_spawn_floating_text("THE SEA MONKEY LIVES!", Vector2(0, 60), Color(0.7, 0.9, 0.6), 2.2)

func _create_fallback_egg() -> void:
	# Rare fallback if no Egg scene - primitive egg using same logic as indicator
	_egg_node = Node2D.new()
	_egg_node.name = "FallbackEgg"
	_entities_layer.add_child(_egg_node)
	_egg_node.global_position = Vector2(0, tank_top_y - 50)
	# For brevity, the real Egg.gd is preferred; this just prevents crash.
	print("[AquariumController] Using fallback egg (add Egg.tscn to avoid).")

# Simple floating comic-style text (MUNCH!, +Insight, CRACK!, etc.)
func _spawn_floating_text(text: String, world_pos: Vector2, color: Color = Color(1, 0.95, 0.7), lifetime: float = 1.6) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 16)
	label.z_index = 50
	add_child(label)  # or UI layer, but world for now
	label.global_position = world_pos - Vector2(40, 0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 55, lifetime)
	t.tween_property(label, "modulate:a", 0.0, lifetime * 0.7).set_delay(lifetime * 0.3)
	t.tween_callback(label.queue_free).set_delay(lifetime)

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
	if _is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	_is_paused = true
	if _pause_overlay == null:
		_create_pause_overlay()
	_pause_overlay.visible = true
	var mb := get_node_or_null("UI/MenuButton") as Button
	if mb:
		mb.text = "RESUME"

func _resume_game() -> void:
	get_tree().paused = false
	_is_paused = false
	if _pause_overlay:
		_pause_overlay.visible = false
	var mb := get_node_or_null("UI/MenuButton") as Button
	if mb:
		mb.text = "MENU"

func _create_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.03, 0.03, 0.06, 0.88)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.z_index = 200
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var ui_layer := get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(_pause_overlay)
	else:
		add_child(_pause_overlay)

	# Paused title
	var title := Label.new()
	title.text = "— PAUSED —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 120
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.85, 0.8, 0.7)
	_pause_overlay.add_child(title)

	# Resume button
	var resume := Button.new()
	resume.text = "RESUME"
	resume.set_anchors_preset(Control.PRESET_CENTER)
	resume.position.y = -20
	resume.custom_minimum_size = Vector2(220, 52)
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_pause_button(resume)
	resume.pressed.connect(_resume_game)
	_pause_overlay.add_child(resume)

	# Quit to title
	var quit := Button.new()
	quit.text = "QUIT TO TITLE"
	quit.set_anchors_preset(Control.PRESET_CENTER)
	quit.position.y = 50
	quit.custom_minimum_size = Vector2(220, 52)
	quit.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_pause_button(quit)
	quit.pressed.connect(func():
		_resume_game()
		return_to_title()
	)
	_pause_overlay.add_child(quit)

func _style_pause_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.55, 0.5, 0.65, 0.9)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.2, 0.3, 0.98)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	button.add_theme_font_size_override("font_size", 18)

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