extends Node2D

var amount: int = 1
var resource_type: GameEnums.ResourceType = GameEnums.ResourceType.ELDRITCH_INSIGHT
var _controller: Node = null   # set by spawner (AquariumController)

var _visual: CanvasItem
var _area: Area2D
var _lifetime: float = 28.0
var _bob_time: float = 0.0
var _drift: Vector2 = Vector2.ZERO
var _collected: bool = false

func _ready() -> void:
	# Editor-first: "Visual" host node + "HoverArea" are in ResourceGlob.tscn.
	# _build_visual populates under the host when present (or replaces its children for icon vs primitive).
	var host := get_node_or_null("Visual")
	_build_visual(null, host if host else null)
	_setup_hover_area()
	_drift = Vector2(randf_range(-12, 12), randf_range(-8, 8)).normalized() * randf_range(4, 10)

func initialize(res_type: GameEnums.ResourceType, amt: int, icon_tex: Texture2D = null, controller: Node = null) -> void:
	resource_type = res_type
	amount = max(1, amt)
	_controller = controller

	# Rebuild visual under the editor-placed "Visual" host.
	# Clear prior children of the host (supports re-init with icon after spawn).
	var host := get_node_or_null("Visual")
	if host:
		for c in host.get_children():
			c.queue_free()
		_visual = null
	_build_visual(icon_tex, host)

func _build_visual(icon_tex: Texture2D = null, host: Node = null) -> void:
	var is_insight := resource_type == GameEnums.ResourceType.ELDRITCH_INSIGHT
	var base_size := Vector2(52, 52)
	var parent := host if host else self

	if icon_tex != null:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = base_size
		tr.size = base_size
		tr.modulate = Color(1, 1, 1, 0.95)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = -base_size / 2
		parent.add_child(tr)
		_visual = tr
	else:
		var cr := ColorRect.new()
		cr.size = base_size
		cr.position = -base_size / 2
		cr.color = Color(0.35, 0.7, 0.95) if is_insight else Color(0.35, 0.75, 0.45)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cr)
		_visual = cr

	if _visual:
		_visual.scale = Vector2(1.35, 1.35)
		var pop := create_tween()
		pop.tween_property(_visual, "scale", Vector2(1.0, 1.0), 0.22)

func _setup_hover_area() -> void:
	# Editor-first: HoverArea is placed in ResourceGlob.tscn.
	# Script wires the signal; creation is defensive fallback.
	_area = get_node_or_null("HoverArea") as Area2D
	if _area == null:
		_area = Area2D.new()
		_area.name = "HoverArea"
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		(shape.shape as CircleShape2D).radius = 48
		_area.add_child(shape)
		add_child(_area)
	_area.input_pickable = true
	_area.mouse_entered.connect(_on_mouse_entered)

func _process(delta: float) -> void:
	if _collected:
		return

	_bob_time += delta
	_lifetime -= delta

	if _visual:
		var bob := sin(_bob_time * 4.5) * 3.5
		var vsize := 52.0
		if _visual is Control:
			vsize = _visual.size.y
		_visual.position.y = bob - vsize * 0.5

	position += _drift * delta * 0.6
	_drift = _drift.lerp(Vector2.ZERO, delta * 0.4)

	if _visual and fmod(_bob_time, 1.6) < 0.1:
		_visual.scale = Vector2(1.08, 1.08)
	else:
		_visual.scale = _visual.scale.lerp(Vector2.ONE, delta * 8.0)

	if _lifetime <= 0.0:
		_auto_collect_on_timeout()

func _on_mouse_entered() -> void:
	# Collect on hover (mouse enter) rather than requiring a click.
	if _collected:
		return
	_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true

	# Remove immediately on hover (visual gone right away)
	if _visual:
		_visual.visible = false

	if _controller and _controller.has_method("on_resource_glob_collected"):
		_controller.on_resource_glob_collected(self, amount, resource_type)
	else:
		queue_free()

	# Free promptly – the flying UI effect is spawned independently
	queue_free()

func _fade_and_free() -> void:
	if _collected:
		return
	_collected = true
	var t := create_tween()
	if _visual:
		t.tween_property(_visual, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)

# Optional: allow external force (e.g. from explosions later)
func apply_impulse(imp: Vector2) -> void:
	_drift += imp * 0.6

func _auto_collect_on_timeout() -> void:
	# On timeout, auto-collect so the player doesn't lose the released resources (just no hover bonus feel).
	# Still plays the fly visual. Hide first for clean removal.
	if _collected:
		return
	_collected = true

	if _visual:
		_visual.visible = false

	if _controller and _controller.has_method("on_resource_glob_collected"):
		_controller.on_resource_glob_collected(self, amount, resource_type)
	else:
		queue_free()

	queue_free()
