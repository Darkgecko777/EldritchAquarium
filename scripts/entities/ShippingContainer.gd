extends Node2D

@export var drop_duration: float = 1.2
@export var organs_to_release: int = 3

@export_group("Visuals (Placeholders)")
@export var closed_color: Color = Color(0.6, 0.55, 0.45)
@export var open_color: Color = Color(0.4, 0.35, 0.3)

var _is_opened: bool = false
var _aquarium: Node
var _organ_scene: PackedScene

# Visual placeholder (replace with real sprite later)
var _visual: ColorRect

var _pressed_on_me: bool = false

func _ready() -> void:
	# Editor-first: Visual and ClickArea are authored in ShippingContainer.tscn.
	# Script retrieves them; creation is defensive fallback only.
	_visual = get_node_or_null("Visual") as ColorRect
	if _visual == null:
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = Vector2(80, 60)
		_visual.color = closed_color
		_visual.position = Vector2(-40, -30)
		_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_visual)

	var area: Area2D = get_node_or_null("ClickArea")
	if area == null:
		area = Area2D.new()
		area.name = "ClickArea"
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		(shape.shape as RectangleShape2D).size = Vector2(80, 60)
		area.add_child(shape)
		add_child(area)

	area.input_event.connect(_on_area_input_event)
	area.input_pickable = true
	area.mouse_exited.connect(_on_mouse_exited)
	area.mouse_entered.connect(_on_mouse_entered)

	# Start dropped state will be set by Initialize + Drop

## Called by AquariumController right after instantiation.
func initialize(aquarium: Node, organ_scene: PackedScene) -> void:
	_aquarium = aquarium
	_organ_scene = organ_scene

	# Animate the drop from current position
	_drop()

func _drop() -> void:
	# Optional: add a little horizontal sway or rotation during fall for personality
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	# Move down to a resting "floor" position near tank bottom (AquariumController can clamp later)
	var target_y: float = global_position.y + 400.0
	if _aquarium != null and "tank_bottom_y" in _aquarium:
		target_y = _aquarium.tank_bottom_y - 30.0
	var target_pos: Vector2 = Vector2(global_position.x, target_y)

	tween.tween_property(self, "global_position", target_pos, drop_duration)

	# Add a little "impact" squash at the end
	await tween.finished

	if not is_instance_valid(self):
		return

	if _aquarium and _aquarium.has_method("clamp_to_tank"):
		global_position = _aquarium.clamp_to_tank(global_position)

	# Impact effect placeholder
	var impact_tween: Tween = create_tween()
	impact_tween.tween_property(_visual, "scale", Vector2(1.15, 0.85), 0.08)
	impact_tween.tween_property(_visual, "scale", Vector2.ONE, 0.2)

	# print("[ShippingContainer] Landed. Click to open.")  # cleared for resource debug focus

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_opened:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed_on_me = true
			else:
				if _pressed_on_me:
					# print("[ShippingContainer] Click detected on area, opening...")  # cleared for resource debug focus
					open()
					_pressed_on_me = false
				get_viewport().set_input_as_handled()

func open() -> void:
	if _is_opened:
		return
	_is_opened = true

	# print("[ShippingContainer] Opening...")  # cleared for resource debug focus

	# Visual change
	if _visual:
		_visual.color = open_color
		_visual.modulate = Color.WHITE

	# TODO: Play proper opening animation (scale, particles, label "CONTENTS: ???")
	var open_tween: Tween = create_tween()
	open_tween.tween_property(_visual, "scale", Vector2(1.0, 0.6), 0.15)

	# Request organs from the controller (it knows where to spawn them nicely)
	if _aquarium and _aquarium.has_method("spawn_organs_from_container"):
		_aquarium.spawn_organs_from_container(global_position, organs_to_release)

	# Self-destruct after a short delay so player sees the "opened" state briefly
	var timer: SceneTreeTimer = get_tree().create_timer(0.6)
	timer.timeout.connect(queue_free)

func _on_mouse_exited() -> void:
	_pressed_on_me = false
	if _visual and not _is_opened:
		_visual.modulate = Color.WHITE

func _on_mouse_entered() -> void:
	if _is_opened or not _visual:
		return
	# Subtle hover to signal the box is clickable (open on click)
	_visual.modulate = Color(1.2, 1.15, 1.05)

# Future: Add hover highlight, shipping label text, variants (different sizes/colors)
