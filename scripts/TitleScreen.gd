extends Control

@export var game_scene: PackedScene = preload("res://scenes/Aquarium.tscn")

@onready var start_button: Button = %StartButton
@onready var exit_button: Button = %ExitButton
@onready var title_label_1: Label = %TitleLabel1
@onready var title_label_2: Label = %TitleLabel2
@onready var logo_container: Control = %LogoContainer
@onready var bubbles: CPUParticles2D = %Bubbles
@onready var void_particles: CPUParticles2D = %VoidParticles

var _pulse_time: float = 0.0

func _ready() -> void:
	# Wire buttons
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Style the buttons with code (pure shapes, no textures)
	_style_buttons()

	# Start particle systems
	if bubbles:
		bubbles.emitting = true
	if void_particles:
		void_particles.emitting = true

	# v1.3+: Make title screen content dynamic based on run state.
	# For brand new games: exotic "creatures never before seen by man or child!" pitch (Sea Monkeys aesthetic preserved).
	# For continuing games (after first pet hatched): updated catalog / "order more" page.
	_apply_dynamic_ad_content()

	# print("[TitleScreen] Ready. All visuals are Godot primitives only.")  # cleared for resource debug focus

func _process(delta: float) -> void:
	# Gentle pulsing "logo" effect using only code + modulate/scale
	if logo_container:
		_pulse_time += delta * 1.2
		var pulse: float = 1.0 + sin(_pulse_time) * 0.015
		logo_container.scale = Vector2.ONE * pulse

		# Very slight color breathing on the second title word
		if title_label_2:
			var hue_shift: float = (sin(_pulse_time * 0.6) + 1.0) * 0.5 * 0.1
			var base_color: Color = Color(0.55, 0.75, 0.95)
			title_label_2.modulate = base_color.lerp(Color(0.7, 0.6, 0.95), hue_shift)

func _style_buttons() -> void:
	# Start button - prominent
	_style_button(start_button, Color(0.15, 0.35, 0.45), Color(0.2, 0.55, 0.65))

	# Exit button - more ominous
	_style_button(exit_button, Color(0.25, 0.15, 0.15), Color(0.45, 0.2, 0.2))

func _style_button(button: Button, normal_color: Color, hover_color: Color) -> void:
	if button == null:
		return

	# Create flat styleboxes using only colors and rounded corners (no images)
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_color = Color(0.6, 0.7, 0.8, 0.6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	hover.border_color = Color(0.8, 0.9, 1.0, 0.9)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal_color.darkened(0.3)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

	# Text styling
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))
	button.add_theme_font_size_override("font_size", 28)

func _on_start_pressed() -> void:
	if game_scene == null:
		# printerr("GameScene not assigned on TitleScreen!")  # cleared for resource debug focus
		return

	start_button.disabled = true
	exit_button.disabled = true

	# Fresh run state (keeps the game feeling like a proper new session each time)
	GameManager.start_new_run()

	# Fun "container is arriving" micro-transition using only shapes
	await _play_start_transition()

	get_tree().change_scene_to_packed(game_scene)

func _play_start_transition() -> void:
	# Simple screen flash + "drop" effect using a full-screen ColorRect we can create on the fly
	var flash := ColorRect.new()
	flash.color = Color(0.4, 0.6, 0.9, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 100
	add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)

	# Quick bright flash
	tween.tween_property(flash, "color:a", 0.6, 0.08)
	tween.tween_property(flash, "color:a", 0.0, 0.35).set_delay(0.08)

	# Slightly "sink" the whole title as if something dropped into the tank
	if logo_container:
		tween.tween_property(logo_container, "position:y", logo_container.position.y + 60.0, 0.5)

	# Slow the bubbles dramatically for a moment
	if bubbles:
		tween.tween_property(bubbles, "speed_scale", 0.2, 0.4)

	await tween.finished

	if is_instance_valid(flash):
		flash.queue_free()

func _apply_dynamic_ad_content() -> void:
	# Check GameManager for whether we've already hatched the first pet in this run (or a loaded save).
	var gm := get_node_or_null("/root/GameManager")
	var is_continuing := false
	if gm != null and "first_pet_hatched" in gm:
		is_continuing = gm.first_pet_hatched

	if not is_continuing:
		# Fresh run / first pet not yet hatched → exotic "creatures never before seen" ad (gold starter playloop).
		# Keeps Sea Monkeys visual/portal aesthetic and uncanny mercantile tone.
		# print("[TitleScreen] Fresh run mode: exotic creatures comic ad pitch (gold starter).")  # cleared for resource debug focus
		# Could swap in more sales-y subtitle or button text here when we have comic styling.
		if start_button:
			start_button.text = "EXOTIC CREATURES (NEW!)"
		return

	# Continuing run → dynamically changed catalog / re-order page. Keep the same visual style (gold starter now active).
		# print("[TitleScreen] Continuing run: updated catalog / 'order more specimens' ad content.")  # cleared for resource debug focus
	if start_button:
		start_button.text = "ORDER MORE SPECIMENS"
	if title_label_2:
		# Slight flavor shift without breaking the logo.
		pass  # Could modulate or we could have a separate "catalog header" label later.
	# Update footer + subtitle to feel like a catalog update / ongoing ad.
	var footer := get_node_or_null("Footer") as Label
	if footer:
		footer.text = "Your tank has proven viable. New exotic imports now available."
	var subtitle := get_node_or_null("LogoContainer/Subtitle") as Label
	if subtitle:
		subtitle.text = "Replenish. Expand. Witness the unknowable."
	# Could add a small "current collection" comic panel summary here in future.

func _on_exit_pressed() -> void:
	exit_button.disabled = true
	get_tree().quit()

# Optional: allow pressing Enter to start (nice for incremental games)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()