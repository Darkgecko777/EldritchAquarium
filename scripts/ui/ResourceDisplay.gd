# scripts/ui/ResourceDisplay.gd
# Simple HUD element that displays current resources and pollution.
# Attach to a Control (CanvasLayer or inside UI scene) and assign labels in the inspector.
# This is intentionally basic — replace with themed panels, icons, and animations later.
extends Control

@export_group("Labels (assign in inspector)")
@export var biomass_label: Label
@export var void_essence_label: Label
@export var sanity_shards_label: Label
@export var pollution_label: Label  # Could be a ProgressBar instead / in addition

@export var pollution_bar: ProgressBar

var _game_manager: Node

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager == null:
		printerr("ResourceDisplay could not find GameManager.")
		return

	# Connect using GDScript signal style
	if _game_manager.has_signal("resources_changed"):
		_game_manager.resources_changed.connect(_update_display)
	if _game_manager.has_signal("pollution_changed"):
		_game_manager.pollution_changed.connect(func(_new_val): _update_display())

	_update_display()

func _update_display() -> void:
	if _game_manager == null:
		return

	if biomass_label:
		biomass_label.text = "Biomass: %d" % _game_manager.get_resource(GameEnums.ResourceType.BIOMASS)

	if void_essence_label:
		void_essence_label.text = "Void: %d" % _game_manager.get_resource(GameEnums.ResourceType.VOID_ESSENCE)

	if sanity_shards_label:
		sanity_shards_label.text = "Sanity: %d" % _game_manager.get_resource(GameEnums.ResourceType.SANITY_SHARDS)

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