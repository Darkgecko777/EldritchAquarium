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
@export var egg_scene: PackedScene  # Legacy (egg path removed from initial loop). Assigned in scene for safety during transition; not used for normal new runs.
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

# Player hold-to-tend state (LMB sustained on a target).
# Goldfish: 4x hunger rate while held.
# Uneaten food: 4x decay rate while held (rapid Pollution generation).
var _held_target: Node = null
const HOLD_MULTIPLIER: float = 4.0

# === OPENING SEQUENCE (first few moments from comic ad) ===
var _in_opening: bool = false  # legacy flag from egg era; kept for safety but new initial loop does not use egg paths
var _egg_node: Node = null  # legacy — not created in standard no-egg flow
var _incubating_label: Label = null
var _incubating_bar: ProgressBar = null
var _force_starter_next_drop: bool = false
var _comic_panel: Control = null  # Reusable placeholder comic panel for tutorial phases (65% screen, 4-panel layout)

var _first_sample_click_instruction: Label = null  # "Click Here" prompt for the very first complimentary sample container
var _click_here_tween: Tween = null

# Pollution death tracking (goldfish at 75% threshold — temporary until full per-pet HP system)
var _goldfish_died_from_pollution: bool = false

# Bottom shipment catalog (6 squares for available shipments as game progresses)
var _shipment_catalog: Control = null
var _shipment_slots: Array = []

# Tiered shipment state (base = free with 20s CD, silver/gold paid with better rarity odds)
var _last_base_shipment_ms: int = 0
var _pending_common_chance: float = 0.70  # consumed by spawn_organs_from_container for the next non-starter drop
var _base_cooldown_overlay: ColorRect = null  # visual bar for the BASE slot cooldown

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

	# Layers are declared in Aquarium.tscn (Entities + Pets children of root).
	# Defensive creation kept for robustness if scene is edited outside normal flow.
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

	# Clean any stale egg/incubation nodes from previous runs (defensive)
	var stale_egg := get_node_or_null("Entities/Egg")  # unlikely but safe
	if stale_egg:
		stale_egg.queue_free()

	# Connect to manager signals (GDScript style)
	if _game_manager:
		if _game_manager.has_signal("shipment_ordered"):
			_game_manager.shipment_ordered.connect(_on_shipment_ordered)
		if _game_manager.has_signal("pollution_changed"):
			_game_manager.pollution_changed.connect(_on_pollution_changed)

	# Wire the primitive MENU button (top right)
	var menu_btn: Button = get_node_or_null("UI/MenuButton")
	if menu_btn:
		_style_menu_button(menu_btn)
		menu_btn.pressed.connect(_on_menu_button_pressed)

	# Create invisible static walls so organs explode, bounce off tank bounds, and come to rest floating.
	_create_tank_bounds()

	# Prevent the large background ColorRects from consuming mouse input.
	# This allows Area2D / CollisionObject2D mouse events (ShippingContainer, feed items, pets, globs) to receive clicks.
	for n in ["Background", "WaterOverlay", "Floor"]:
		var ctrl := get_node_or_null(n) as Control
		if ctrl:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# v1.6+ initial loop: No egg, no incubation, no "opening sequence" wait.
	# New runs (and normal entry) start with a fully formed, visually normal goldfish already in the tank.
	# The title was the comic exotic feed catalog ad. Player orders feed via bottom catalog or SPACE.
	# Force paused state immediately for fresh runs so nothing (tweens, hunger, physics, drops) happens until the player reads and closes the instructions.
	if _game_manager and not _game_manager.first_pet_hatched:
		get_tree().paused = true

	_spawn_starter_pet()  # normal formed goldfish

	# Show a short rethemed comic tutorial explaining feed orders + mutation loop.
	# It pauses the world (game starts paused) so the player can read.
	# The initial complimentary sample shipment is triggered ONLY after the player closes this comic
	# (see _on_tutorial_comic_closed). This prevents the box from dropping or auto-opening while instructions are up.
	_show_initial_feed_tutorial()

	# Create the bottom shipment catalog panel (6 squares).
	# Slots: 0=BASE (free, 20s CD), 1=SILVER (10), 2=GOLD (25). Others are placeholders.
	_create_shipment_catalog()

	# print("[AquariumController] Ready. SPACE or bottom Shipment Panel slots to drop containers.")  # cleared for resource debug focus

func _process(_delta: float) -> void:
	if held_organ_type != -1 and held_indicator and is_instance_valid(held_indicator):
		held_indicator.position = get_viewport().get_mouse_position() - held_indicator.size / 2

	# Drive the obvious cooldown bar on the BASE (first) shipment slot.
	_update_base_cooldown_visual()

	# Maintain player hold-to-tend (hunger on pet or decay on food) at 4x while LMB is held.
	_process_hold_state()

func _unhandled_input(event: InputEvent) -> void:
	if not enable_test_input:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo):
		# SPACE requests the BASE shipment (free, subject to 20s CD, 70% common distribution).
		# Uses the same path as clicking the first catalog slot.
		_on_shipment_slot_pressed(0)
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

	# Temporary pollution death threshold for the goldfish specimen (75%). Will be replaced by per-pet HP + hunger/Pollution/stress depletion.
	# See Game_Vision v1.6 and Pets.md for the intended full system.
	if new_pollution >= 75.0 and not _goldfish_died_from_pollution:
		_kill_goldfish_at_pollution_threshold()

	# Ensure the corruption/pollution display (ResourceDisplay) updates immediately and correctly,
	# even if signal delivery or connections have timing subtleties (e.g. during decay).
	var res_disp := get_node_or_null("UI/ResourceDisplay")
	if res_disp and res_disp.has_method("_update_display"):
		res_disp._update_display()

## Called by ShippingContainer when it is opened.
## Spawns feed items at the container's location.
## For the very first run we use special starter sample packets (visually distinct "exotic primer" feed).
func spawn_organs_from_container(position: Vector2, count: int = 3) -> void:
	if organ_scene == null:
		printerr("OrganScene not assigned!")
		return

	# Clear the "Click Here" prompt as soon as any container (in particular the first sample) is opened.
	# This is called from the container's open() -> spawn path.
	if _first_sample_click_instruction and is_instance_valid(_first_sample_click_instruction):
		_clear_first_sample_instruction()

	var is_starter_drop := _force_starter_next_drop

	if is_starter_drop:
		_force_starter_next_drop = false
		_spawn_starter_packets(position)
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

		# Set reasonable defaults for normal feed items.
		# Rarity + insight are driven by the pending shipment tier profile (set by catalog slots).
		organ.bites_to_consume = 4
		organ.remaining_bites = 4

		var common_chance := _pending_common_chance
		_pending_common_chance = 0.70  # reset to base default after consumption

		var rolled := _roll_rarity(common_chance)

		if organ.has_method("set_rarity"):
			organ.set_rarity(rolled)
		else:
			organ.rarity = rolled
			if organ.has_method("_update_visual_for_rarity_and_size"):
				organ._update_visual_for_rarity_and_size()

		# Set insight according to the new ladder (common=2, uncommon=4, rare=8, epic=16, legendary=32)
		var insight := 2
		match rolled:
			GameEnums.OrganRarity.COMMON:    insight = 2
			GameEnums.OrganRarity.UNCOMMON:  insight = 4
			GameEnums.OrganRarity.RARE:      insight = 8
			GameEnums.OrganRarity.EPIC:      insight = 16
			GameEnums.OrganRarity.LEGENDARY: insight = 32
			_: insight = 2
		organ.insight_value = insight

	# (no egg timer logic — no egg in the standard initial loop)

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

# === PLAYER HOLD-TO-TEND (4x rate on hunger or decay) ===

func start_hold_on(target: Node) -> void:
	"""Begin sustained hold on a pet (hunger accel) or uneaten food (decay accel)."""
	if target == null or not is_instance_valid(target):
		return
	if _held_target == target:
		return

	_release_hold()

	_held_target = target

	# Apply immediately
	_apply_hold_effects(target)

func _release_hold() -> void:
	if _held_target == null:
		return

	if is_instance_valid(_held_target) and _held_target.has_method("set_hold_multiplier"):
		_held_target.set_hold_multiplier(1.0)

	_held_target = null

func _apply_hold_effects(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.has_method("set_hold_multiplier"):
		target.set_hold_multiplier(HOLD_MULTIPLIER)

func _process_hold_state() -> void:
	"""Called every frame to maintain or release the hold based on actual mouse button state."""
	if _held_target == null:
		return

	var still_holding_mouse := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not still_holding_mouse or not is_instance_valid(_held_target):
		_release_hold()
	else:
		# Re-assert the multiplier (in case the target reset it)
		_apply_hold_effects(_held_target)

func _spawn_starter_pet() -> void:
	_goldfish_died_from_pollution = false

	# Editor-first: If a Pet (goldfish) instance is already present as a child of the "Pets" node in the scene,
	# respect the editor placement (position, pet_name, species, current_stage etc. set in .tscn).
	# Only call initialize on the existing one(s). This is the preferred path.
	if _pets_layer and _pets_layer.get_child_count() > 0:
		for child in _pets_layer.get_children():
			if child.has_method("initialize"):
				child.initialize(_game_manager, self)
		return

	# Fallback: no editor-placed pet in the scene — spawn one (kept for robustness / other test setups).
	if pet_scene == null:
		# print("[AquariumController] No PetScene assigned — skipping starter pet (add one in inspector later).")  # cleared for resource debug focus
		return

	var pet: Node = pet_scene.instantiate()
	_pets_layer.add_child(pet)

	# v1.6: Fully formed normal goldfish at the start of the run.
	pet.global_position = Vector2(0, 80)
	if "species" in pet:
		pet.species = GameEnums.PetSpecies.FREAKY_GOLDFISH
	if "pet_name" in pet:
		pet.pet_name = "Normal Goldfish"
	if "current_stage" in pet:
		pet.current_stage = GameEnums.EvolutionStage.LARVAL
	if pet.has_method("initialize"):
		pet.initialize(_game_manager, self)

# === INITIAL LOOP INTRO (v1.6 — no egg) ===
# On first entry from the feed catalog title we show a short comic-style instruction panel
# explaining the new fantasy: ordinary goldfish + exotic feed orders → mutations.
# The panel can pause briefly so the player reads, then the goldfish is already there and catalog is live.

func _show_initial_feed_tutorial() -> void:
	_goldfish_died_from_pollution = false

	var phase_texts: Array[String] = [
		"1. THE CATALOG IS REAL\nThe comic ad you just clicked is how you order exotic feed and supplements. Your ordinary goldfish is already in the tank — no waiting, no eggs.",
		"2. FEED TO MUTATE\nOrder shipments (bottom catalog or SPACE). The goldfish will autonomously hunt and eat. Hover the mouse over the floating globs it releases to collect Insight and Biomatter (no click needed).",
		"3. TEND THE TANK\nHold on the goldfish to speed its hunger (faster eating/mutation). Hold on uneaten food to accelerate decay (generates Pollution for later cleaners). Mismatches rot and add Pollution.",
		"4. EVOLVE & END\nConsumption drives 5 mutation stages with choices. Pollution and hunger will eventually kill the specimen. Death grants Fragments for the prestige tree. Reset and scale."
	]
	_comic_panel = _create_comic_panel("THE FEED CATALOG", phase_texts, true)
	if _comic_panel:
		_comic_panel.set_meta("is_initial_tutorial", true)

# Performs the actual opening arrival now that the player has dismissed the tutorial comic.
# (Legacy _begin_opening_arrival stub — egg path disabled for the standard initial loop.
# New flow: _show_initial_feed_tutorial + direct _spawn_starter_pet (normal goldfish) + optional _spawn_initial_sample_feed.)
func _begin_opening_arrival() -> void:
	pass

func _create_incubation_ui() -> void:
	var ui_layer := get_node_or_null("UI")
	if ui_layer == null:
		return

	# (Incubation UI creation removed for no-egg flow. Stub left for any stray old calls.)

# Reusable placeholder comic panel UI for tutorial / phase descriptions.
# Single panel ~65% of screen space, quartered into 4 text panels (2x2 comic layout).
# Styled with comic borders (StyleBoxFlat) and paper tones. Includes a close button.
# pauses_game: when true, pauses the tree briefly so the player can read the instructions.
# Used for the initial feed tutorial and future threshold comics.
func _create_comic_panel(phase_title: String, panel_texts: Array[String], pauses_game: bool = false) -> Control:
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

	# Tutorial pause support: freeze the game world (pets, hunger, physics, future decay, timers) while the comic is the modal.
	# The comic (and its close button) must continue processing input and remain interactive.
	if pauses_game:
		get_tree().paused = true
		comic.process_mode = Node.PROCESS_MODE_ALWAYS
		comic.set_meta("pauses_game", true)

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

	# Close button action: resume from pause (if any) and free. New initial tutorial uses "is_initial_tutorial" meta.
	close_btn.pressed.connect(Callable(self, "_on_tutorial_comic_closed").bind(comic))

	ui_layer.add_child(comic)
	return comic

# Handler used by all tutorial comic close buttons.
# Resumes the game tree if this comic caused a pause (via meta), then frees the panel.
func _on_tutorial_comic_closed(comic: Control) -> void:
	if comic == null or not is_instance_valid(comic):
		return

	var was_pausing: bool = comic.has_meta("pauses_game") and bool(comic.get_meta("pauses_game"))
	if was_pausing:
		_release_hold()
		get_tree().paused = false

	# New initial feed tutorial just needs unpause + cleanup. No egg arrival.
	comic.queue_free()
	if _comic_panel == comic:
		_comic_panel = null

	# For the initial tutorial comic, NOW trigger the complimentary sample feed shipment.
	# It will drop (after unpause), land, and WAIT for the player to click it (no auto-open).
	# "Click Here" text will be shown until opened.
	if comic.has_meta("is_initial_tutorial"):
		_last_base_shipment_ms = Time.get_ticks_msec()
		_update_base_cooldown_visual()
		_spawn_initial_sample_feed(false)  # false = do not auto-open; player must click the box

# Helper for places that force-remove the comic to also unpause if it was a tutorial pauser.
func _ensure_comic_tutorial_unpause_and_free() -> void:
	if _comic_panel and is_instance_valid(_comic_panel):
		var c := _comic_panel
		_comic_panel = null
		if c.has_meta("pauses_game") and bool(c.get_meta("pauses_game")):
			_release_hold()
			_clear_first_sample_instruction()
			get_tree().paused = false
		c.queue_free()

func _update_incubation_ui() -> void:
	pass  # no-op after no-egg pivot

func _spawn_starter_packets(at_position: Vector2) -> void:
	"""Spawns the two special starter sample feed packets for the very first run.
	Visually distinct (STARTER_* types) so the player notices the "exotic primer" complimentary food.
	These kickstart mutations for the normal goldfish that is already in the tank. No egg involved.
	"""
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

		# Exactly 2 insight / 2 bites / 2 biomass for the complimentary sample.
		# These are visually distinct "exotic primer" feed packets for the very first run (kickstart mutations).
		# Reframed from "starter organs for egg" to "sample feed for normal goldfish".
		packet.bites_to_consume = 2
		packet.insight_value = 2
		packet.remaining_bites = 2
		packet.biomass_value = 2

		# Force the special starter type (bypass random) — distinct colors help the player notice the "special" first food.
		if packet.has_method("set_organ_type"):
			packet.set_organ_type(starter_types[i])
		else:
			packet.set("type", starter_types[i])
			if packet.has_method("_update_visual_for_type"):
				packet.call("_update_visual_for_type")

		if packet.has_method("set_rarity"):
			packet.set_rarity(GameEnums.OrganRarity.COMMON)
		else:
			packet.set("rarity", GameEnums.OrganRarity.COMMON)

		# Medium size bias for the goldfish starter's preference.
		if packet.has_method("set_size_category"):
			packet.set_size_category("medium")
		else:
			packet.set("size_category", "medium")

		# Apply impulse for physics-based explosion: short distance in different directions, upward bias for arc
		# (see normal organs for notes on no-gravity + bounce + resistance behavior)
		# Increased for more travel (organs were stopping too close to drop point).
		var impulse = Vector2(randf_range(-200, 200), randf_range(-300, -50)).normalized() * randf_range(350, 550)
		packet.apply_impulse(impulse)

	# print("[AquariumController] Spawned complimentary sample feed pack (2 special primer packets) at ", at_position)  # cleared for resource debug focus

# v1.6: Drop a complimentary sample feed pack for the brand new normal goldfish.
# Uses the existing starter packet visuals (distinct colors) but now framed as "exotic primer feed"
# to kickstart the mutation process.
# auto_open: if true, auto-opens after landing (for normal samples). If false (first time), player must click the container.
# When auto_open=false we also show persistent "Click Here" floating text until the player clicks it.
func _spawn_initial_sample_feed(auto_open: bool = true) -> void:
	_force_starter_next_drop = true

	if shipping_container_scene == null:
		_spawn_starter_packets(Vector2(20, 40))
		return

	var container: Node = shipping_container_scene.instantiate()
	_entities_layer.add_child(container)

	var x: float = randf_range(-80, 80)
	container.global_position = Vector2(x, tank_top_y - 70)
	if container.has_method("initialize"):
		container.initialize(self, organ_scene)

	# Mark it so we can clear the instruction on open
	if not auto_open:
		container.set_meta("is_initial_sample", true)

	# Compute approximate landing position for the "Click Here" text (same logic as container drop)
	var land_y: float = tank_bottom_y - 30.0
	if "tank_bottom_y" in self:
		land_y = tank_bottom_y - 30.0
	var land_pos := Vector2(x, land_y)

	if not auto_open:
		_spawn_click_here_instruction(land_pos)
	else:
		# Normal (non-first) sample: auto-open shortly after landing so the feed is released automatically.
		var auto_delay: float = 1.4
		get_tree().create_timer(auto_delay).timeout.connect(func() -> void:
			if is_instance_valid(container) and container.has_method("open"):
				container.open()
		)

func _spawn_click_here_instruction(land_pos: Vector2) -> void:
	"""Show a pulsing 'Click Here' prompt above the first sample container until the player clicks to open it."""
	_clear_first_sample_instruction()

	var label := Label.new()
	label.text = "Click Here"
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(1.0, 0.95, 0.5, 0.95)
	label.z_index = 55
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)
	label.global_position = land_pos + Vector2(-55, -95)  # positioned above the landed box

	_first_sample_click_instruction = label

	# Gentle pulse animation (finite loops to avoid "infinite loop detected" tween error)
	# Pulses for a while then stays visible until the box is clicked/opened.
	var t := create_tween()
	t.set_loops(25)  # ~17-18 seconds of pulsing, plenty for the first box
	t.tween_property(label, "modulate:a", 0.35, 0.7)
	t.tween_property(label, "modulate:a", 1.0, 0.7)
	_click_here_tween = t

func _clear_first_sample_instruction() -> void:
	if _click_here_tween and _click_here_tween.is_valid():
		_click_here_tween.kill()
	_click_here_tween = null

	if _first_sample_click_instruction and is_instance_valid(_first_sample_click_instruction):
		_first_sample_click_instruction.queue_free()
	_first_sample_click_instruction = null

# Create a persistent bottom panel holding 6 squares/slots for available shipments.
# Slot 0 = BASE (free + 20s cooldown), 1 = SILVER (10 insight), 2 = GOLD (25 insight).
# Higher slots are placeholders for future content.
func _create_shipment_catalog() -> void:
	var ui_layer := get_node_or_null("UI")
	if ui_layer == null:
		return

	_shipment_catalog = Panel.new()
	_shipment_catalog.name = "ShipmentCatalog"
	_shipment_catalog.custom_minimum_size = Vector2(0, 86)
	# Anchor to bottom, centered-ish width with margins
	_shipment_catalog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_shipment_catalog.offset_left = 40
	_shipment_catalog.offset_right = -40
	_shipment_catalog.offset_bottom = -12
	_shipment_catalog.offset_top = -98

	# Dark panel background with subtle border to fit the tank theme
	var cat_style := StyleBoxFlat.new()
	cat_style.bg_color = Color(0.06, 0.09, 0.12, 0.92)
	cat_style.border_width_left = 2
	cat_style.border_width_right = 2
	cat_style.border_width_top = 2
	cat_style.border_width_bottom = 2
	cat_style.border_color = Color(0.25, 0.28, 0.32, 0.9)
	_shipment_catalog.add_theme_stylebox_override("panel", cat_style)
	_shipment_catalog.z_index = 10  # keep the bottom catalog above the center comic panel during opening

	ui_layer.add_child(_shipment_catalog)

	# Inner content
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	_shipment_catalog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Small header label for the panel
	var header := Label.new()
	header.text = "AVAILABLE SHIPMENTS"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Row of 6 squares
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_shipment_slots.clear()
	for i in 6:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(64, 52)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var slot_style := StyleBoxFlat.new()
		if i == 0:
			# BASE shipment (free, 20s CD, 70% common)
			slot_style.bg_color = Color(0.13, 0.18, 0.22)
			slot_style.border_width_left = 3
			slot_style.border_width_right = 3
			slot_style.border_width_top = 3
			slot_style.border_width_bottom = 3
			slot_style.border_color = Color(0.45, 0.65, 0.75, 0.95)
		else:
			# Future/locked slots
			slot_style.bg_color = Color(0.07, 0.09, 0.11)
			slot_style.border_width_left = 2
			slot_style.border_width_right = 2
			slot_style.border_width_top = 2
			slot_style.border_width_bottom = 2
			slot_style.border_color = Color(0.22, 0.24, 0.27, 0.7)

		slot.add_theme_stylebox_override("panel", slot_style)

		# Content inside the square
		var inner_margin := MarginContainer.new()
		inner_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner_margin.add_theme_constant_override("margin_left", 4)
		inner_margin.add_theme_constant_override("margin_top", 3)
		inner_margin.add_theme_constant_override("margin_right", 4)
		inner_margin.add_theme_constant_override("margin_bottom", 3)
		slot.add_child(inner_margin)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		inner_margin.add_child(col)

		if i == 0:
			# BASE: free (cost 0) but 20s cooldown. Best "common" rate (70%).
			var name_lbl := Label.new()
			name_lbl.text = "BASE"
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(name_lbl)

			var cost_row := HBoxContainer.new()
			cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(cost_row)

			var cost_lbl := Label.new()
			cost_lbl.text = "FREE"
			cost_lbl.add_theme_font_size_override("font_size", 12)
			cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))
			cost_row.add_child(cost_lbl)

			var clicker := Button.new()
			clicker.text = ""
			clicker.flat = true
			clicker.modulate = Color(1, 1, 1, 0)
			clicker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			clicker.pressed.connect(_on_shipment_slot_pressed.bind(0))
			slot.add_child(clicker)

			# Obvious cooldown bar overlay for the BASE (first) shipment.
			# Starts full when we arm the initial cooldown; shrinks from the top as the 20s CD elapses.
			var cd := ColorRect.new()
			cd.name = "CooldownOverlay"
			cd.color = Color(0.2, 0.45, 0.85, 0.65)  # distinct blue "cooldown" tint
			cd.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			cd.size = Vector2(64, 52)  # full height initially
			cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(cd)
			_base_cooldown_overlay = cd

		elif i == 1:
			# SILVER: 60% common, cost 10 insight. Better distribution than base.
			var name_lbl := Label.new()
			name_lbl.text = "SILVER"
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(name_lbl)

			var cost_row := HBoxContainer.new()
			cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(cost_row)

			var cost_lbl := Label.new()
			cost_lbl.text = "10"
			cost_lbl.add_theme_font_size_override("font_size", 14)
			cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			cost_row.add_child(cost_lbl)

			if insight_icon_texture != null:
				var ic := TextureRect.new()
				ic.texture = insight_icon_texture
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.custom_minimum_size = Vector2(14, 14)
				ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cost_row.add_child(ic)

			var clicker := Button.new()
			clicker.text = ""
			clicker.flat = true
			clicker.modulate = Color(1, 1, 1, 0)
			clicker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			clicker.pressed.connect(_on_shipment_slot_pressed.bind(1))
			slot.add_child(clicker)

		elif i == 2:
			# GOLD: 50% common (best odds), cost 25 insight.
			var name_lbl := Label.new()
			name_lbl.text = "GOLD"
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(name_lbl)

			var cost_row := HBoxContainer.new()
			cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(cost_row)

			var cost_lbl := Label.new()
			cost_lbl.text = "25"
			cost_lbl.add_theme_font_size_override("font_size", 14)
			cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
			cost_row.add_child(cost_lbl)

			if insight_icon_texture != null:
				var ic := TextureRect.new()
				ic.texture = insight_icon_texture
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.custom_minimum_size = Vector2(14, 14)
				ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cost_row.add_child(ic)

			var clicker := Button.new()
			clicker.text = ""
			clicker.flat = true
			clicker.modulate = Color(1, 1, 1, 0)
			clicker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			clicker.pressed.connect(_on_shipment_slot_pressed.bind(2))
			slot.add_child(clicker)
		else:
			# Future/locked slots
			var lock_lbl := Label.new()
			lock_lbl.text = "?"
			lock_lbl.add_theme_font_size_override("font_size", 16)
			lock_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lock_lbl)

		hbox.add_child(slot)
		_shipment_slots.append(slot)

# Handler for clicking a shipment slot in the bottom catalog.
# Slot 0 = BASE (free, 20s CD, 70% common)
# Slot 1 = SILVER (cost 10, 60% common)
# Slot 2 = GOLD (cost 25, 50% common)
func _on_shipment_slot_pressed(slot_index: int) -> void:
	var common_chance := 0.70
	var cost := 0
	var is_base := false

	match slot_index:
		0:
			common_chance = 0.70
			cost = 0
			is_base = true
		1:
			common_chance = 0.60
			cost = 10
		2:
			common_chance = 0.50
			cost = 25
		_:
			return  # locked placeholders

	# Base has a 20s cooldown (free repeatable shipment)
	if is_base:
		var now := Time.get_ticks_msec()
		if now - _last_base_shipment_ms < 20000:
			# On cooldown - silently ignore or could spawn a floating note
			return
		_last_base_shipment_ms = now

	# Tell the next non-starter spawn what distribution to use
	_pending_common_chance = common_chance

	if _game_manager and _game_manager.has_method("order_shipment"):
		var ok: bool = _game_manager.order_shipment(cost)
		if not ok:
			# Insufficient resources - clear the pending profile so we don't leak state
			_pending_common_chance = 0.70
			# (Optional: could add a small "not enough" float here)

# Rolls an OrganRarity using the given common_chance (0.0-1.0) for the tier.
# Remaining probability is distributed to higher rarities (better odds for higher tiers).
# Used by base (70%), silver (60%), gold (50%) shipments.
func _roll_rarity(common_chance: float) -> GameEnums.OrganRarity:
	var r := randf()
	if r < common_chance:
		return GameEnums.OrganRarity.COMMON

	var remaining := 1.0 - common_chance
	var t := (r - common_chance) / remaining  # 0..1 in the non-common band

	# Simple decreasing distribution from the remaining mass.
	# Base example (common=0.70): ~18% U, 8% R, 3% E, 1% L
	if t < 0.60:
		return GameEnums.OrganRarity.UNCOMMON
	elif t < 0.85:
		return GameEnums.OrganRarity.RARE
	elif t < 0.95:
		return GameEnums.OrganRarity.EPIC
	else:
		return GameEnums.OrganRarity.LEGENDARY

# Updates the visual cooldown bar on the BASE slot (if present).
# The bar covers from the top and shrinks as the 20s cooldown elapses.
func _update_base_cooldown_visual() -> void:
	if _base_cooldown_overlay == null or not is_instance_valid(_base_cooldown_overlay):
		return
	var now: int = Time.get_ticks_msec()
	var cd_duration: int = 20000
	var elapsed: int = now - _last_base_shipment_ms
	var frac: float = clamp(float(elapsed) / float(cd_duration), 0.0, 1.0)  # 0 = full cooldown just triggered, 1 = ready
	var remaining: float = 1.0 - frac
	var full_h: float = 52.0
	var bar_h: float = full_h * remaining
	_base_cooldown_overlay.size = Vector2(64, bar_h)
	_base_cooldown_overlay.position = Vector2(0, 0)
	_base_cooldown_overlay.visible = remaining > 0.02

# (hatch_egg_at is a legacy no-op after the no-egg pivot. Normal goldfish is spawned directly in _spawn_starter_pet.)
func hatch_egg_at(pos: Vector2) -> void:
	pass

func _restore_normal_ui_after_hatch() -> void:
	# Legacy name kept for any old call sites. For the new flow we just ensure the tutorial comic is cleaned.
	_spawn_floating_text("GOLDFISH IS HUNGRY", Vector2(0, 50), Color(0.95, 0.82, 0.4), 1.8)
	_ensure_comic_tutorial_unpause_and_free()

# Kills the goldfish specimen at the temporary 75% Pollution threshold (scaffolding until full HP system).
# Grants a Fragment and plays feedback. Only triggers once per run.
func _kill_goldfish_at_pollution_threshold() -> void:
	_goldfish_died_from_pollution = true

	if _pets_layer == null:
		return

	for child in _pets_layer.get_children():
		if not is_instance_valid(child):
			continue
		# Match the gold starter species (the one that dies via Pollution threshold per design).
		var is_goldfish := false
		if "species" in child and child.species == GameEnums.PetSpecies.FREAKY_GOLDFISH:
			is_goldfish = true
		if not is_goldfish:
			continue

		# Grant the fragment (mnemonic on death) and visual feedback.
		if _game_manager and _game_manager.has_method("add_resource"):
			_game_manager.add_resource(GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS, 1)

		var death_pos := (child as Node2D).global_position if child is Node2D else Vector2.ZERO
		_spawn_floating_text("DIED FROM POLLUTION", death_pos, Color(0.75, 0.35, 0.3), 1.6)

		# Prefer encapsulated death on the pet (handles its own visuals + free); fallback to direct remove.
		if child.has_method("die_from_pollution"):
			child.die_from_pollution()
		else:
			child.queue_free()

func _create_fallback_egg() -> void:
	# Legacy no-op. Egg path is not used for the standard initial loop (normal goldfish start).
	pass

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

## Returns every valid uneaten food item (feed/organs) that is currently inside the tank bounds
## and has bites/collect remaining. This central method guarantees pets can always find
## ANY food the player has ordered, no matter how far it bounced or where it landed inside the tank.
## Pets should prefer this over tree groups or manual walks so detection is reliable and bounded.
func get_valid_food_in_tank() -> Array:
	var foods: Array = []
	if _entities_layer == null:
		return foods

	var min_x := spawn_x_min
	var max_x := spawn_x_max
	var min_y := tank_top_y
	var max_y := tank_bottom_y

	for child in _entities_layer.get_children():
		if not is_instance_valid(child):
			continue

		# Determine if this is a valid food item with remaining "bites" (uneaten feed)
		var bites_left := -1
		if "remaining_bites" in child:
			bites_left = child.remaining_bites
		elif child.has_method("get_remaining_bites"):
			bites_left = child.get_remaining_bites()

		var is_collected := false
		if "_collected" in child:
			is_collected = child._collected

		if bites_left > 0 and not is_collected:
			# Enforce tank bounds so pets only target food that is actually in the playable area
			if child is Node2D:
				var p: Vector2 = child.global_position
				if p.x < min_x or p.x > max_x or p.y < min_y or p.y > max_y:
					continue
			foods.append(child)

	return foods

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
	_release_hold()
	_clear_first_sample_instruction()
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _on_menu_button_pressed() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	_release_hold()
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
