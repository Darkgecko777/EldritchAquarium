extends Node2D

@export var base_hatch_time: float = 8.0

var _remaining_time: float = 8.0
var _aquarium_controller: Node
var _hatched: bool = false

# Primitive visuals
var _shell: CanvasItem
var _inner: CanvasItem
var _timer_label: Label
var _status_label: Label  # e.g. "INCUBATING..."

var _original_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_build_primitives()
	_remaining_time = base_hatch_time
	_update_timer_display()

func initialize(controller: Node) -> void:
	_aquarium_controller = controller
	# Start the drop animation from current (top) position
	_start_drop_tween()

func reduce_timer(seconds: float) -> void:
	if _hatched or seconds <= 0:
		return
	_remaining_time = max(0.1, _remaining_time - seconds)
	_update_timer_display()
	# Small visual pop to show acceleration
	if _shell:
		var pop := create_tween()
		pop.tween_property(_shell, "scale", _shell.scale * 1.15, 0.08)
		pop.tween_property(_shell, "scale", _original_scale, 0.15)

func _process(delta: float) -> void:
	if _hatched:
		return
	_remaining_time -= delta
	_update_timer_display()

	if _remaining_time <= 0.0:
		_hatch()

	# Pulsing / "alive" effect that gets stronger as time runs low
	if _shell:
		var progress: float = 1.0 - clamp(_remaining_time / base_hatch_time, 0.0, 1.0)
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() / 180.0) * (0.03 + progress * 0.08)
		_shell.scale = _original_scale * pulse

		# Color warms / gets uncanny gold as it nears hatch (gold starter egg primitive)
		if _shell is ColorRect:
			var base_col := Color(0.92, 0.82, 0.55)
			var hatch_col := Color(0.75, 0.35, 0.35)
			_shell.color = base_col.lerp(hatch_col, progress * 0.7)

func _start_drop_tween() -> void:
	# Similar to container drop for consistency
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	# Compute landing near tank bottom so it drops all the way
	var target_y: float = global_position.y + 400.0
	if _aquarium_controller != null and "tank_bottom_y" in _aquarium_controller:
		target_y = _aquarium_controller.tank_bottom_y - 30.0
	var target_pos := Vector2(global_position.x, target_y)
	tween.tween_property(self, "global_position", target_pos, 1.3)

	await tween.finished
	if is_instance_valid(self) and _aquarium_controller and _aquarium_controller.has_method("clamp_to_tank"):
		global_position = _aquarium_controller.clamp_to_tank(global_position)

	# Gentle settle impact
	if _shell:
		var settle := create_tween()
		settle.tween_property(_shell, "scale", _original_scale * Vector2(1.1, 0.9), 0.1)
		settle.tween_property(_shell, "scale", _original_scale, 0.25)

	# print("[Egg] Landed and incubating.")  # cleared for resource debug focus

func _build_primitives() -> void:
	# Editor-first: Shell, Inner, StatusLabel, TimerLabel, and InputArea are placed in Egg.tscn.
	# Script retrieves and applies initial configuration / wiring. Creation is defensive.
	_shell = get_node_or_null("Shell") as CanvasItem
	if _shell == null:
		# Distinct golden/eldritch egg primitive (fallback only).
		_shell = ColorRect.new()
		_shell.name = "Shell"
		_shell.size = Vector2(46, 36)
		_shell.position = Vector2(-23, -18)
		_shell.color = Color(0.92, 0.82, 0.55)
		(_shell as ColorRect).pivot_offset = _shell.size / 2
		(_shell as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shell)
	_original_scale = _shell.scale

	# Inner yolk (editor-placed child preferred)
	if _shell is ColorRect:
		_inner = _shell.get_node_or_null("Inner") as CanvasItem
		if _inner == null:
			_inner = ColorRect.new()
			_inner.name = "Inner"
			_inner.size = Vector2(20, 16)
			_inner.position = Vector2(-10, -8)
			(_inner as ColorRect).color = Color(0.55, 0.42, 0.22, 0.65)
			(_inner as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shell.add_child(_inner)

	# Labels (editor-placed)
	_status_label = get_node_or_null("StatusLabel") as Label
	if _status_label == null:
		_status_label = Label.new()
		_status_label.name = "StatusLabel"
		_status_label.text = "INCUBATING..."
		_status_label.position = Vector2(-25, -55)
		_status_label.add_theme_font_size_override("font_size", 14)
		_status_label.modulate = Color(0.9, 0.85, 0.7, 0.95)
		add_child(_status_label)

	_timer_label = get_node_or_null("TimerLabel") as Label
	if _timer_label == null:
		_timer_label = Label.new()
		_timer_label.name = "TimerLabel"
		_timer_label.text = "30s"
		_timer_label.position = Vector2(-18, -40)
		_timer_label.add_theme_font_size_override("font_size", 18)
		_timer_label.modulate = Color(1, 0.95, 0.8)
		add_child(_timer_label)

	# Input area (editor-placed preferred)
	var area: Area2D = get_node_or_null("InputArea")
	if area == null:
		area = Area2D.new()
		area.name = "InputArea"
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		(shape.shape as CircleShape2D).radius = 32
		area.add_child(shape)
		add_child(area)
	area.input_pickable = true
	area.input_event.connect(_on_egg_clicked)

func _update_timer_display() -> void:
	if _timer_label:
		var secs := int(ceil(_remaining_time))
		_timer_label.text = "%ds" % secs
		# Color urgency
		if secs < 8:
			_timer_label.modulate = Color(1, 0.4, 0.4)
		elif secs < 15:
			_timer_label.modulate = Color(1, 0.85, 0.5)
		else:
			_timer_label.modulate = Color(1, 0.95, 0.8)

	if _status_label:
		if _remaining_time < 5.0:
			_status_label.text = "HATCHING SOON!"
		else:
			_status_label.text = "INCUBATING..."

func _on_egg_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Fun feedback: small time reduction on click (player "encouraging" it) + visual
		reduce_timer(1.5)
		if _shell:
			var jiggle := create_tween()
			jiggle.tween_property(_shell, "rotation_degrees", 8, 0.06)
			jiggle.tween_property(_shell, "rotation_degrees", -6, 0.08)
			jiggle.tween_property(_shell, "rotation_degrees", 0, 0.1)
		get_viewport().set_input_as_handled()

func _hatch() -> void:
	if _hatched:
		return
	_hatched = true

	# print("[Egg] Hatching the Freaky Goldfish (gold starter larva)!")  # cleared for resource debug focus

	# Comic hatch effect
	if _status_label:
		_status_label.text = "CRACK!"
		_status_label.modulate = Color(1, 0.6, 0.5)
	if _shell:
		var crack := create_tween()
		crack.tween_property(_shell, "scale", _original_scale * Vector2(1.4, 0.6), 0.1)
		crack.tween_property(_shell, "modulate:a", 0.0, 0.35)

	if _aquarium_controller and _aquarium_controller.has_method("hatch_egg_at"):
		_aquarium_controller.hatch_egg_at(global_position)

	# Self cleanup after effect
	var t := get_tree().create_timer(0.4)
	t.timeout.connect(queue_free)

# Helper so controller can query remaining if needed
func get_remaining_time() -> float:
	return _remaining_time
