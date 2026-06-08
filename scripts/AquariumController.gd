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
@export var resource_glob_scene: PackedScene  # Clickable floating globs for released resources (Insight/Biomatter). Player clicks to collect (then flies to UI).

@export_group("Tank Settings")
@export var tank_top_y: float = -300.0
@export var tank_bottom_y: float = 280.0
@export var spawn_x_min: float = -400.0
@export var spawn_x_max: float = 400.0

@export var organ_tank_resistance: float = 1.0  # Controls how "thick" the water feels for organs. Lower values allow organs to travel/bounce farther from their spawn point before damping to rest.
@export var insight_icon_texture: Texture2D  # Icon for flying released insight and UI display.
@export var biomatter_icon_texture: Texture2D  # Icon for Abyssal Biomatter globs (optional; falls back to color).

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
var _comic_panel: Control = null  # Reusable placeholder comic panel for tutorial phases (65% screen, 4-panel layout)

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
	if resource_glob_scene == null:
		resource_glob_scene = load("res://scenes/entities/ResourceGlob.tscn")

	# Create a simple held organ indicator (primitive, follows mouse when you have an organ picked up)
	# Add to UI layer so it's always on top and uses screen coordinates
	var ui_layer = get_node_or_null("UI")
	held_indicator = ColorRect.new()
	held_indicator.size = Vector2(18, 14)
	held_indicator.visible = false
	held_indicator.z_index = 100
	held_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Create invisible static walls so organs explode, bounce off tank bounds, and come to rest floating.
	_create_tank_bounds()

	# Prevent the large background ColorRects from consuming mouse input.
	# This allows Area2D / CollisionObject2D mouse events (e.g. ShippingContainer click-to-open, organs, egg, pets) to receive clicks.
	for n in ["Background", "WaterOverlay", "Floor"]:
		var ctrl := get_node_or_null(n) as Control
		if ctrl:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Opening sequence or normal starter?
	if _game_manager and _game_manager.get("pending_opening_sequence"):
		_game_manager.pending_opening_sequence = false
		start_opening_sequence()
	else:
		# Normal / continuing run - spawn a gold starter larval pet (Freaky Goldfish primitive)
		_spawn_starter_pet()

	# print("[AquariumController] Ready. Press SPACE (if enabled) or use the Order button to drop containers.")  # cleared for resource debug focus

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

	# Quick debug: right click (now mostly for legacy or pollution testing).
	# do NOT grant Insight here — only pets eating via collisions generate resources.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if held_organ_type != -1:
			# Cancel held organ
			held_organ_type = -1
			held_organ_value = 0
			if held_indicator:
				held_indicator.visible = false
		elif _game_manager and _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.ABYSSAL_BIOMATTER, 25)
			# print("[Debug] Right-click added legacy Biomass. Remember: real Insight only comes from pet eating.")  # cleared for resource debug focus

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

	# print("[AquariumController] Container dropped at ", spawn_pos)  # cleared for resource debug focus

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

	# Normal shipment organs - pop out in different directions to occupy space (shoot short distance)
	for i in range(count):
		var organ: Node = organ_scene.instantiate()
		organ.global_position = position  # start at container

		# Apply the tank's resistance setting before _ready runs its physics setup.
		# This lets the "generic resistance value in the tank" affect the organs.
		if "tank_resistance" in organ:
			organ.tank_resistance = organ_tank_resistance

		_entities_layer.add_child(organ)

		if organ.has_method("initialize"):
			organ.initialize(_game_manager, self)

		# Apply impulse for physics-based explosion (short distance different dirs, upward bias)
		# With gravity_scale=0 + tank walls + resistance, this makes them fly out, bounce off bounds, then slow to floating rest.
		# Increased range for more travel distance (per user feedback on short movement).
		var impulse = Vector2(randf_range(-200, 200), randf_range(-300, -50)).normalized() * randf_range(350, 550)
		organ.apply_impulse(impulse)

		# Set reasonable defaults for normal organs
		organ.bites_to_consume = 4
		organ.insight_value = 4
		organ.remaining_bites = 4

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
		_game_manager.add_resource(GameEnums.ResourceType.ABYSSAL_BIOMATTER, value)
		print("[AquariumController] Held organ picked — legacy Biomatter only. No Insight (must be fed/eaten by pet).")

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
		_game_manager.add_resource(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 1)

	# Clear held state
	held_organ_type = -1
	held_organ_value = 0
	if held_indicator:
		held_indicator.visible = false

func _spawn_starter_pet() -> void:
	if pet_scene == null:
		# print("[AquariumController] No PetScene assigned — skipping starter pet (add one in inspector later).")  # cleared for resource debug focus
		return

	var pet: Node = pet_scene.instantiate()
	_pets_layer.add_child(pet)

	# Place it in a nice starting spot (gold starter primitive for non-opening path)
	pet.global_position = Vector2(0, 100)
	if "species" in pet:
		pet.species = GameEnums.PetSpecies.FREAKY_GOLDFISH
	if "pet_name" in pet:
		pet.pet_name = "Freaky Goldfish"
	if pet.has_method("initialize"):
		pet.initialize(_game_manager, self)

# === FIRST MOMENTS / COMIC AD OPENING SEQUENCE ===

func start_opening_sequence() -> void:
	_in_opening = true
	_complimentary_claimed = false

	# print("[AquariumController] Starting comic ad opening sequence (egg + complimentary).")  # cleared for resource debug focus

	# Update instructions to comic ad flavor (exotic creatures pitch for the gold starter, Sea Monkeys aesthetic preserved)
	var instr: Label = get_node_or_null("UI/Instructions")
	if instr:
		instr.text = "Your exotic specimen kit has arrived in the tank...\nWatch the egg incubate.\nCLAIM the complimentary shipment to get food in the water!"

	# Repurpose Order button for the free claim during opening
	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn:
		_opening_order_button_original_text = order_btn.text
		order_btn.text = "CLAIM COMPLIMENTARY SHIPMENT (FREE!)"
		# style it more "ad like" temporarily if wanted

	# Introduce reusable comic panel placeholder for the current phase (65% screen, 4-panel layout).
	# This will be reused for future tutorial / phase descriptions.
	# Each panel now includes clear "how to play" instructions.
	var phase1_texts: Array[String] = [
		"1. THE AD IS YOUR SHOP\nThe comic catalog calls from the void. Click the ORDER button (or ad area) to begin your run and receive the exotic egg kit.",
		"2. INCUBATE & CLAIM\nAn egg drops into the tank. Watch it pulse and incubate. Click CLAIM COMPLIMENTARY SHIPMENT to drop food – this reduces the hatch timer!",
		"3. THE LARVA HATCHES\nYour Freaky Goldfish emerges. It is aggressive and prefers medium packets. It will swim and bump food on its own to eat (no clicking needed to feed).",
		"4. CLICK THE GLOBS\nEach bite releases floating globs. Click them in the tank to collect Insight, Biomatter and Shards. This is active tending!"
	]
	_comic_panel = _create_comic_panel("PHASE 1: THE EXOTIC ARRIVAL", phase1_texts)

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
	_incubating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_incubating_label)

	# Simple bar to show progress (0 = just started, full = about to hatch)
	_incubating_bar = ProgressBar.new()
	_incubating_bar.name = "IncubatingBar"
	_incubating_bar.position = Vector2(20, 238)
	_incubating_bar.size = Vector2(220, 18)
	_incubating_bar.max_value = 100.0
	_incubating_bar.value = 0.0
	_incubating_bar.show_percentage = false
	_incubating_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_incubating_bar)

# Reusable placeholder comic panel UI for tutorial / phase descriptions.
# Single panel ~65% of screen space, quartered into 4 text panels (2x2 comic layout).
# Call with different texts for future phases. Styled with comic borders (StyleBoxFlat) and paper tones.
# Includes a close button. Each panel now has clear "how to play" instructions for the current phase.
func _create_comic_panel(phase_title: String, panel_texts: Array[String]) -> Control:
	var ui_layer := get_node_or_null("UI")
	if ui_layer == null:
		return null

	var vp := get_viewport_rect().size
	var panel_size := vp * 0.65

	# Main comic frame as Panel with proper StyleBox for clean borders (fixes weird left-side artifacts from layered ColorRects)
	var comic := Panel.new()
	comic.name = "ComicPanelPlaceholder"
	comic.custom_minimum_size = panel_size
	comic.size = panel_size
	comic.set_anchors_preset(Control.PRESET_CENTER)
	comic.position = -panel_size / 2

	# Comic-style outer border + paper background
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0.92, 0.88, 0.78)  # aged paper
	outer_style.border_width_left = 8
	outer_style.border_width_right = 8
	outer_style.border_width_top = 8
	outer_style.border_width_bottom = 8
	outer_style.border_color = Color(0.08, 0.06, 0.05)  # thick black comic border
	comic.add_theme_stylebox_override("panel", outer_style)

	# Inner margin container for padding
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	comic.add_child(margin)

	# Content VBox: header (title + close) then the 2x2 grid
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var title := Label.new()
	title.text = phase_title
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.08, 0.06, 0.05))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color.WHITE)

	# Comic button style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.12, 0.18)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.4, 0.35, 0.45)
	close_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.2, 0.3)
	close_btn.add_theme_stylebox_override("hover", btn_hover)

	header.add_child(close_btn)

	# 2x2 grid for the four comic panels
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	# Calculate approximate cell size so each quarter gets a full text box area
	# (prevents text shrinking to a narrow left column)
	var content_w := panel_size.x - 36.0
	var content_h := panel_size.y - 80.0
	var cell_w := content_w / 2.0
	var cell_h := content_h / 2.0

	for i in 4:
		var sub := Panel.new()
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sub.custom_minimum_size = Vector2(cell_w, cell_h)

		# Sub-panel comic style (paper + black border)
		var sub_style := StyleBoxFlat.new()
		sub_style.bg_color = Color(0.98, 0.96, 0.9)
		sub_style.border_width_left = 4
		sub_style.border_width_right = 4
		sub_style.border_width_top = 4
		sub_style.border_width_bottom = 4
		sub_style.border_color = Color(0.08, 0.06, 0.05)
		sub.add_theme_stylebox_override("panel", sub_style)

		# Inner margin container that fills the sub-panel (creates the full text box area)
		var sub_margin := MarginContainer.new()
		sub_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sub_margin.add_theme_constant_override("margin_left", 12)
		sub_margin.add_theme_constant_override("margin_top", 10)
		sub_margin.add_theme_constant_override("margin_right", 12)
		sub_margin.add_theme_constant_override("margin_bottom", 10)
		sub.add_child(sub_margin)

		# The text label now fills the entire inner box (full text box per quarter)
		var txt := Label.new()
		txt.text = panel_texts[i] if i < panel_texts.size() else ""
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_font_size_override("font_size", 12)
		txt.add_theme_color_override("font_color", Color(0.08, 0.06, 0.05))
		txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Force the label rect to use the full space provided by the margin container
		txt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sub_margin.add_child(txt)

		grid.add_child(sub)

	# Close button action: remove the panel (reusable for any phase)
	close_btn.pressed.connect(comic.queue_free)

	ui_layer.add_child(comic)
	return comic

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

	# print("[AquariumController] Claiming complimentary shipment for the opening (unique starter packets).")  # cleared for resource debug focus

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
		packet.global_position = at_position  # start at container for launch

		# Apply tank resistance so starter packets also respect the water "thickness".
		if "tank_resistance" in packet:
			packet.tank_resistance = organ_tank_resistance

		_entities_layer.add_child(packet)

		if packet.has_method("initialize"):
			packet.initialize(_game_manager, self)

		# Set per organ resource values and bite counts for initial state (2 and 3 insight, 2 and 3 bites)
		var bites := 2 if i == 0 else 3
		packet.bites_to_consume = bites
		packet.insight_value = bites
		packet.remaining_bites = bites
		packet.biomass_value = bites

		# Force the special starter type (bypass random in Organ._ready)
		if packet.has_method("set_organ_type"):
			packet.set_organ_type(starter_types[i])
		else:
			packet.set("type", starter_types[i])
			if packet.has_method("_update_visual_for_type"):
				packet.call("_update_visual_for_type")

		# Mark as the gold starter's matched "medium" food (minimal size hint per plan).
		# This + Pet preference bias gives the Freaky Goldfish an early taste of its playstyle.
		if packet.has_method("set_size_category"):
			packet.set_size_category("medium")
		else:
			packet.set("size_category", "medium")

		# Apply impulse for physics-based explosion: short distance in different directions, upward bias for arc
		# (see normal organs for notes on no-gravity + bounce + resistance behavior)
		# Increased for more travel (organs were stopping too close to drop point).
		var impulse = Vector2(randf_range(-200, 200), randf_range(-300, -50)).normalized() * randf_range(350, 550)
		packet.apply_impulse(impulse)

	# print("[AquariumController] Spawned 2 unique starter (medium) packets at ", at_position)  # cleared for resource debug focus

# Called from Egg when its timer hits zero (or was reduced to zero).
func hatch_egg_at(pos: Vector2) -> void:
	if not _in_opening or _egg_node == null:
		return

	# print("[AquariumController] Hatching the Freaky Goldfish (gold starter larva)...")  # cleared for resource debug focus

	# Clean incubation UI
	if _incubating_label:
		_incubating_label.queue_free()
		_incubating_label = null
	if _incubating_bar:
		_incubating_bar.queue_free()
		_incubating_bar = null

	# Spawn the special first pet (larva Freaky Goldfish) - eager gold starter, distinct primitive
	if pet_scene:
		var larva: Node = pet_scene.instantiate()
		_pets_layer.add_child(larva)
		larva.global_position = pos + Vector2(0, 20)  # slightly below egg

		# Configure as the gold starter *before* initialize so larval eager + preference logic runs
		if "pet_name" in larva:
			larva.pet_name = "Freaky Goldfish"
		if "current_stage" in larva:
			larva.current_stage = GameEnums.EvolutionStage.LARVAL
		if "species" in larva:
			larva.species = GameEnums.PetSpecies.FREAKY_GOLDFISH
		# Make the larva more driven (aggressive goldfish baseline; we enhance seeking in Pet.gd)
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
		instr.text = "SPACE or Order button: drop container\nWatch your Freaky Goldfish seek & eat the medium packets (collisions!)\nClick the released globs to collect Insight, Biomatter and Shards (they fly to the HUD)."

	var order_btn: Button = get_node_or_null("UI/OrderButton")
	if order_btn:
		order_btn.text = "Order Shipment (Insight)"

	# Optional: small comic popup for the gold starter hatch
	_spawn_floating_text("THE GOLDFISH LIVES!", Vector2(0, 60), Color(0.95, 0.82, 0.4), 2.2)

	# Remove the phase comic panel if still present (the close button also frees it; this is a safety net for later phases)
	if _comic_panel and is_instance_valid(_comic_panel):
		_comic_panel.queue_free()
		_comic_panel = null

func _create_fallback_egg() -> void:
	# Rare fallback if no Egg scene - primitive egg using same logic as indicator
	_egg_node = Node2D.new()
	_egg_node.name = "FallbackEgg"
	_entities_layer.add_child(_egg_node)
	_egg_node.global_position = Vector2(0, tank_top_y - 50)
	# For brevity, the real Egg.gd is preferred; this just prevents crash.
	# print("[AquariumController] Using fallback egg (add Egg.tscn to avoid).")  # cleared for resource debug focus

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

## Creates invisible StaticBody2D walls around the tank play area.
## This lets RigidBody organs (etc.) physically bounce off the bounds after exploding
## from a shipment instead of sinking to the bottom or flying off-screen.
## They will ricochet a bit then (thanks to linear_damp "resistance") come to rest floating
## at whatever position their momentum dies.
func _create_tank_bounds() -> void:
	# Clean up if re-entering (e.g. editor reload scenarios)
	var old := get_node_or_null("TankWalls")
	if old:
		old.queue_free()

	var walls := StaticBody2D.new()
	walls.name = "TankWalls"
	walls.collision_layer = 1
	walls.collision_mask = 1

	# Bounciness of the tank "glass"/walls. Organs also have their own PhysicsMaterial.
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.65
	phys_mat.friction = 0.03
	walls.physics_material_override = phys_mat

	add_child(walls)

	var thickness := 36.0
	var margin := 40.0  # larger margin to give collision radius (16) + buffer room so organs don't immediately clip walls on spawn near edges, allowing fuller travel
	var left := spawn_x_min - margin
	var right := spawn_x_max + margin
	var top := tank_top_y - margin
	var bottom := tank_bottom_y + margin

	# Vertical walls (left/right) - tall
	_add_wall_rect(walls, Vector2(thickness, bottom - top + 120.0), Vector2(left - thickness * 0.5, (top + bottom) * 0.5))
	_add_wall_rect(walls, Vector2(thickness, bottom - top + 120.0), Vector2(right + thickness * 0.5, (top + bottom) * 0.5))

	# Horizontal walls (top/bottom) - wide
	_add_wall_rect(walls, Vector2(right - left + 120.0, thickness), Vector2((left + right) * 0.5, top - thickness * 0.5))
	_add_wall_rect(walls, Vector2(right - left + 120.0, thickness), Vector2((left + right) * 0.5, bottom + thickness * 0.5))

func _add_wall_rect(parent: Node, size: Vector2, pos: Vector2) -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = pos
	parent.add_child(col)

func world_to_screen(world_pos: Vector2) -> Vector2:
	# Convert world position to screen/UI coordinates for floating resource text that can target the HUD label.
	# Manual transform using canvas + camera inverse (Camera2D in Godot 4 does not have unproject_position; that's for 3D).
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return world_pos
	var canvas_xform := get_viewport().get_canvas_transform()
	var cam_inv := cam.get_global_transform().affine_inverse()
	return canvas_xform * cam_inv * world_pos

func spawn_resource_glob(world_pos: Vector2, amount: int, res_type: GameEnums.ResourceType) -> void:
	if resource_glob_scene == null or amount <= 0:
		return

	var glob: Node = resource_glob_scene.instantiate()
	_entities_layer.add_child(glob)
	glob.global_position = world_pos
	if has_method("clamp_to_tank"):
		glob.global_position = clamp_to_tank(glob.global_position)

	var icon_tex: Texture2D = null
	var fly_color := Color(0.4, 0.85, 1.0)
	if res_type == GameEnums.ResourceType.ELDRITCH_INSIGHT:
		icon_tex = insight_icon_texture
		fly_color = Color(0.4, 0.85, 1.0)
	elif res_type == GameEnums.ResourceType.ABYSSAL_BIOMATTER:
		icon_tex = biomatter_icon_texture
		fly_color = Color(0.35, 0.78, 0.45)
	elif res_type == GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS:
		icon_tex = load("res://assets/sprites/icons/forgotten_mnemonics_icon.png")
		fly_color = Color(0.9, 0.7, 0.4)

	if glob.has_method("initialize"):
		glob.initialize(res_type, amount, icon_tex, self)
		if res_type == GameEnums.ResourceType.ELDRITCH_INSIGHT:
			print("[DEBUG] Spawned Insight glob value=%d" % amount)
		elif res_type == GameEnums.ResourceType.ABYSSAL_BIOMATTER:
			print("[DEBUG] Spawned Biomatter glob value=%d" % amount)
		elif res_type == GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS:
			print("[DEBUG] Spawned Shards glob value=%d" % amount)

	if glob.has_method("apply_impulse"):
		var kick := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(25, 55)
		glob.apply_impulse(kick)

# Called by a ResourceGlob when the player clicks it (or on auto-timeout).
# The glob carries its 'amount' (the released resource value, e.g. 1 for per-bite in the first cycle).
# This starts the flying visual animation (passing the blob's value).
# The actual add_resource (and UI update to e.g. "I:xx") happens on arrival at the HUD label
func on_resource_glob_collected(glob_node: Node, amt: int, typ: int) -> void:
	if typ == GameEnums.ResourceType.ELDRITCH_INSIGHT:
		print("[DEBUG] Insight glob clicked/collected, value=%d - starting fly to UI" % amt)
	elif typ == GameEnums.ResourceType.ABYSSAL_BIOMATTER:
		print("[DEBUG] Biomatter glob clicked/collected, value=%d - starting fly to UI" % amt)
	elif typ == GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS:
		print("[DEBUG] Shards glob clicked/collected, value=%d - starting fly to UI" % amt)
	var fly_color := Color(0.4, 0.85, 1.0)
	var fly_tex := insight_icon_texture
	if typ == GameEnums.ResourceType.ELDRITCH_INSIGHT:
		fly_color = Color(0.4, 0.85, 1.0)
		fly_tex = insight_icon_texture
	elif typ == GameEnums.ResourceType.ABYSSAL_BIOMATTER:
		fly_color = Color(0.35, 0.78, 0.45)
		fly_tex = biomatter_icon_texture
	elif typ == GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS:
		fly_color = Color(0.9, 0.7, 0.4)
		fly_tex = load("res://assets/sprites/icons/forgotten_mnemonics_icon.png")
	if has_method("_spawn_floating_resource"):
		_spawn_floating_resource(glob_node.global_position if is_instance_valid(glob_node) else global_position, "+%d" % amt, fly_color, 1.0, fly_tex, amt, typ)
	elif has_method("_spawn_floating_text"):
		_spawn_floating_text("+%d" % amt, glob_node.global_position if is_instance_valid(glob_node) else global_position, fly_color, 0.9)

func _spawn_floating_resource(world_pos: Vector2, text: String = "+1", color: Color = Color(0.4, 0.85, 1.0), lifetime: float = 1.0, icon_tex_override: Texture2D = null, collect_amt: int = 0, collect_typ: int = -1) -> void:
	var ui_layer := get_node_or_null("UI")
	if ui_layer == null:
		_spawn_floating_text(text, world_pos, color, lifetime)
		return

	var start_screen := world_to_screen(world_pos)
	var target_pos := start_screen + Vector2(0, -100)
	var bl := ui_layer.get_node_or_null("ResourceDisplay/Margin/HBox/biomass_label") as Label
	if bl:
		target_pos = bl.global_position - Vector2(18, 0)

	var use_tex := icon_tex_override if icon_tex_override != null else insight_icon_texture
	var num_blobs := 3
	for i in range(num_blobs):
		var blob: Control
		if use_tex == null:
			blob = ColorRect.new()
			var sz := 16 + randi() % 12
			blob.size = Vector2(sz, sz)
			blob.color = color
			blob.modulate = Color(1, 1, 1, 0.85 + randf() * 0.15)
			blob.z_index = 50
			blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			blob = TextureRect.new()
			(blob as TextureRect).texture = use_tex
			(blob as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			(blob as TextureRect).custom_minimum_size = Vector2(20, 20)
			blob.size = Vector2(20, 20)
			blob.modulate = Color(1, 1, 1, 0.9 + randf() * 0.1)
			blob.z_index = 50
			blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(blob)

		var offset := Vector2(randf_range(-12, 12), randf_range(-8, 8))
		blob.position = start_screen + offset - blob.size / 2

		var life := lifetime * (0.85 + randf() * 0.3)
		var t := create_tween()
		t.set_parallel(true)
		t.set_trans(Tween.TRANS_QUAD)
		t.set_ease(Tween.EASE_OUT)
		var tpos := target_pos + Vector2(randf_range(-8, 8), randf_range(-4, 4))
		t.tween_property(blob, "position", tpos, life)
		t.tween_property(blob, "modulate:a", 0.0, life * 0.55).set_delay(life * 0.35)
		if use_tex != null:
			t.tween_property(blob, "scale", Vector2(3.5, 3.5), life)
		else:
			t.tween_property(blob, "scale", Vector2(0.3, 0.3), life * 0.4).set_delay(life * 0.45)
		t.tween_callback(blob.queue_free).set_delay(life)

	var num_label := Label.new()
	num_label.text = text
	num_label.modulate = Color(0.7, 1.0, 0.85, 1.0)
	num_label.add_theme_font_size_override("font_size", 14)
	num_label.z_index = 52
	ui_layer.add_child(num_label)
	num_label.position = start_screen - Vector2(8, 8)

	var t2 := create_tween()
	t2.set_parallel(true)
	t2.set_trans(Tween.TRANS_QUAD)
	t2.set_ease(Tween.EASE_OUT)
	var tpos2 := target_pos + Vector2(randf_range(-4, 4), 0)
	t2.tween_property(num_label, "position", tpos2 - Vector2(4, 4), lifetime)
	t2.tween_property(num_label, "modulate:a", 0.0, lifetime * 0.6).set_delay(lifetime * 0.35)
	t2.tween_property(num_label, "scale", Vector2(0.6, 0.6), lifetime * 0.5).set_delay(lifetime * 0.4)
	if collect_amt > 0 and collect_typ >= 0:
		t2.tween_callback(Callable(self, "_finalize_resource_collection").bind(collect_amt, collect_typ)).set_delay(lifetime)
	t2.tween_callback(num_label.queue_free).set_delay(lifetime)

func _finalize_resource_collection(amt: int, typ: int):
	print("[DEBUG] Finalize: adding blob value=%d for type=%s (reaches UI)" % [amt, GameEnums.ResourceType.keys()[typ] if typ in GameEnums.ResourceType.values() else str(typ)])
	if _game_manager and _game_manager.has_method("add_resource"):
		_game_manager.add_resource(typ, amt)

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