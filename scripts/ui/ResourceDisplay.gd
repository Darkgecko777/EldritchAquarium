# scripts/ui/ResourceDisplay.gd
# Simple HUD element that displays current resources and pollution.
# Attach to a Control (CanvasLayer or inside UI scene) and assign labels in the inspector.
# This is intentionally basic — replace with themed panels, icons, and animations later.
extends Control

@export_group("Labels (assign in inspector)")
@export var biomass_label: Label  # Repurposed for primary currency display (now Eldritch Insight per v1.2 vision)
@export var void_essence_label: Label
@export var sanity_shards_label: Label
@export var pollution_label: Label  # Could be a ProgressBar instead / in addition

@export var pollution_bar: ProgressBar

var _game_manager: Node

var _insight_shown := false
var _void_shown := false
var _sanity_shown := false

# Cache the resource types to avoid any potential lookup issues and for clarity
const InsightType := GameEnums.ResourceType.ELDRITCH_INSIGHT
const VoidType := GameEnums.ResourceType.VOID_ESSENCE
const SanityType := GameEnums.ResourceType.SANITY_SHARDS

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager == null:
		printerr("ResourceDisplay could not find GameManager.")
		return

	# Start hidden until first accumulation (per design)
	if biomass_label:
		biomass_label.visible = false
	if void_essence_label:
		void_essence_label.visible = false
	if sanity_shards_label:
		sanity_shards_label.visible = false
	# Pollution meter can show from the start as it's always relevant
	if pollution_label:
		pollution_label.visible = true
	if pollution_bar:
		pollution_bar.visible = true

	# Connect using GDScript signal style
	if _game_manager.has_signal("resources_changed"):
		_game_manager.resources_changed.connect(_update_display)
	if _game_manager.has_signal("pollution_changed"):
		_game_manager.pollution_changed.connect(func(_new_val): _update_display())

	_update_display()

func _update_display() -> void:
	if _game_manager == null:
		return

	var insight: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		insight = _game_manager.get_resource(InsightType)
	if biomass_label:
		# Primary basic currency is now Eldritch Insight (earned via autonomous pet feeding / collisions).
		if insight > 0:
			_insight_shown = true
		biomass_label.visible = _insight_shown
		if _insight_shown:
			biomass_label.text = "Insight: %d" % insight

	var v: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		v = _game_manager.get_resource(VoidType)
	if void_essence_label:
		if v > 0:
			_void_shown = true
		void_essence_label.visible = _void_shown
		if _void_shown:
			void_essence_label.text = "Void: %d" % v

	var s: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		s = _game_manager.get_resource(SanityType)
	if sanity_shards_label:
		if s > 0:
			_sanity_shown = true
		sanity_shards_label.visible = _sanity_shown
		if _sanity_shown:
			sanity_shards_label.text = "Sanity: %d" % s

	var pollution: float = _game_manager.pollution

	if pollution_label:
		pollution_label.text = "Pollution: %.1f%%" % pollution

	if pollution_bar:
		pollution_bar.value = pollution
		# Optional: color the bar based on danger level
		if pollution > 70:
			pollution_bar.modulate = Color.ORANGE_RED
		elif pollution > 40:
			pollution_bar.modulate = Color.ORANGE
		else:
			pollution_bar.modulate = Color.WHITE

# TODO: Add click handlers on resource icons for tooltips or "spend" shortcuts
# TODO: Animate value changes (count-up instead of instant)
# TODO: Eldritch styling: dripping text, occasional glitch on high pollution
# TODO (comic vision): Restyle entire HUD as comic catalog "ledger stamps" / "ACME Void Supply Co." printed receipts. The "Insight" label should feel earned from the tank activity.