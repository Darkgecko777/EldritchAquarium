extends Control

@export_group("Labels (assign in inspector)")
@export var insight_icon: TextureRect
@export var biomass_label: Label
@export var void_essence_label: Label
@export var sanity_shards_label: Label
@export var pollution_label: Label

@export var pollution_bar: ProgressBar

@export var biomatter_icon: TextureRect
@export var mnemonics_icon: TextureRect

var _game_manager: Node

var _void_shown := false
var _sanity_shown := false

var _last_insight: int = 0

const InsightType := GameEnums.ResourceType.ELDRITCH_INSIGHT
const BiomatterType := GameEnums.ResourceType.ABYSSAL_BIOMATTER
const ShardsType := GameEnums.ResourceType.FORGOTTEN_MNEMONIC_SHARDS

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager == null:
		printerr("ResourceDisplay could not find GameManager.")
		return

	print("[DEBUG] ResourceDisplay _ready - biomass_label=", biomass_label, " biomatter_icon=", biomatter_icon, " void_essence_label=", void_essence_label, " mnemonics_icon=", mnemonics_icon)

	if biomass_label == null:
		biomass_label = get_node_or_null("Margin/HBox/biomass_label") as Label
		print("[DEBUG] Re-got biomass_label in _ready: ", biomass_label)
	if biomatter_icon == null:
		biomatter_icon = get_node_or_null("Margin/HBox/biomatter_icon") as TextureRect
		print("[DEBUG] Re-got biomatter_icon in _ready: ", biomatter_icon)
	if mnemonics_icon == null:
		mnemonics_icon = get_node_or_null("Margin/HBox/mnemonics_icon") as TextureRect
		print("[DEBUG] Re-got mnemonics_icon in _ready: ", mnemonics_icon)

	if insight_icon:
		insight_icon.visible = true
		insight_icon.custom_minimum_size = Vector2(70, 70)
		insight_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		insight_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if biomass_label:
		biomass_label.visible = true
	if biomatter_icon:
		biomatter_icon.visible = true
		biomatter_icon.custom_minimum_size = Vector2(70, 70)
		biomatter_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		biomatter_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if mnemonics_icon:
		mnemonics_icon.visible = true
		mnemonics_icon.custom_minimum_size = Vector2(70, 70)
		mnemonics_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mnemonics_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if void_essence_label == null:
		void_essence_label = get_node_or_null("Margin/HBox/void_label") as Label
		print("[DEBUG] Re-got void_essence_label in _ready: ", void_essence_label)
	if void_essence_label:
		void_essence_label.visible = true
	if sanity_shards_label:
		sanity_shards_label.visible = true
	if pollution_label:
		pollution_label.visible = true
	if pollution_bar:
		pollution_bar.visible = true

	if _game_manager.has_signal("resources_changed"):
		_game_manager.resources_changed.connect(_update_display)
		print("[DEBUG] ResourceDisplay connected to resources_changed")
	if _game_manager.has_signal("pollution_changed"):
		_game_manager.pollution_changed.connect(func(_new_val): _update_display())

	_update_display()

func _update_display() -> void:
	if _game_manager == null:
		return

	print("[DEBUG] ResourceDisplay _update_display called via signal")

	if biomass_label == null:
		biomass_label = get_node_or_null("Margin/HBox/biomass_label") as Label
		print("[DEBUG] Re-got biomass_label in update: ", biomass_label)
	if biomass_label == null:
		print("[DEBUG] ERROR: biomass_label still null, cannot update display!")
		return

	var insight: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		insight = _game_manager.get_resource(InsightType)

	var biom: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		biom = _game_manager.get_resource(BiomatterType)

	var shards: int = 0
	if _game_manager and _game_manager.has_method("get_resource"):
		shards = _game_manager.get_resource(ShardsType)

	print("[DEBUG] ResourceDisplay _update: BEFORE biomass_label.text (current: ", biomass_label.text if biomass_label else "null", ")")
	biomass_label.text = "%d" % insight
	print("[DEBUG] ResourceDisplay _update: AFTER biomass_label.text to %d" % insight)
	if insight > _last_insight:
		_juice_label_pop(biomass_label, Color(0.6, 1.0, 0.85))
		if insight_icon:
			_juice_icon_pop(insight_icon)
	_last_insight = insight
	if insight_icon and insight > 0:
		insight_icon.visible = true

	if biomatter_icon == null:
		biomatter_icon = get_node_or_null("Margin/HBox/biomatter_icon") as TextureRect
		print("[DEBUG] Re-got biomatter_icon in update: ", biomatter_icon)
	if void_essence_label == null:
		void_essence_label = get_node_or_null("Margin/HBox/void_label") as Label
		print("[DEBUG] Re-got void_essence_label in update: ", void_essence_label)
	if biomatter_icon:
		biomatter_icon.visible = true
	if void_essence_label:
		void_essence_label.visible = true
		void_essence_label.text = "%d" % biom
		if biom > 0:
			_juice_label_pop(void_essence_label, Color(0.5, 0.9, 0.6))
			if biomatter_icon:
				_juice_icon_pop(biomatter_icon)
		print("[DEBUG] ResourceDisplay _update: Biomatter updated to %d" % biom)

	if mnemonics_icon == null:
		mnemonics_icon = get_node_or_null("Margin/HBox/mnemonics_icon") as TextureRect
		print("[DEBUG] Re-got mnemonics_icon in update: ", mnemonics_icon)
	if sanity_shards_label:
		sanity_shards_label.visible = true
		sanity_shards_label.text = "%d" % shards
		if shards > 0:
			_juice_label_pop(sanity_shards_label, Color(0.8, 0.6, 0.9))
			if mnemonics_icon:
				_juice_icon_pop(mnemonics_icon)
		print("[DEBUG] ResourceDisplay _update: Shards updated to %d" % shards)

	var pollution: float = _game_manager.pollution

	if pollution_label:
		pollution_label.text = "Pollution: %.1f%%" % pollution

	if pollution_bar:
		pollution_bar.value = pollution
		if pollution > 70:
			pollution_bar.modulate = Color.ORANGE_RED
		elif pollution > 40:
			pollution_bar.modulate = Color.ORANGE
		else:
			pollution_bar.modulate = Color.WHITE

func _juice_label_pop(label: Label, flash_color: Color = Color(1, 1, 1)) -> void:
	if label == null:
		return
	label.pivot_offset = label.size / 2.0
	var orig_scale := label.scale
	var orig_mod := label.modulate
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "scale", Vector2(1.4, 1.4), 0.06)
	t.tween_property(label, "scale", orig_scale, 0.2)
	if flash_color != Color(1, 1, 1):
		label.modulate = flash_color
		t.parallel().tween_property(label, "modulate", orig_mod, 0.25)

func _juice_icon_pop(icon: TextureRect, flash_color: Color = Color(0.6, 1.0, 0.85)) -> void:
	if icon == null:
		return
	var orig_scale := icon.scale
	var orig_mod := icon.modulate
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.06)
	t.tween_property(icon, "scale", orig_scale, 0.2)
	if flash_color != Color(1, 1, 1):
		icon.modulate = flash_color
		t.parallel().tween_property(icon, "modulate", orig_mod, 0.25)