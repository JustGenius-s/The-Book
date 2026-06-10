class_name BattleUnitView
extends Control

## 战斗单位的 UI 视图：头像、血条、状态栏、飘字与简单受击/攻击动画。
## 支持点击（目标选择）与描边高亮。

signal clicked(unit: BattleUnit)

const DEAD_TINT := Color(0.35, 0.35, 0.35)
const ACTING_COLOR := Color(0.4, 0.9, 1.0)
const TARGET_COLOR := Color(1.0, 0.85, 0.3)

var unit: BattleUnit

var _portrait: TextureRect
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _fields_label: Label
var _outline: Panel


func setup(p_unit: BattleUnit) -> void:
	unit = p_unit
	custom_minimum_size = Vector2(150, 252)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_outline = Panel.new()
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	_outline.add_theme_stylebox_override("panel", style)
	_outline.visible = false
	add_child(_outline)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_portrait = TextureRect.new()
	_portrait.texture = unit.card.portrait
	_portrait.custom_minimum_size = Vector2(140, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_portrait)

	_name_label = Label.new()
	_name_label.text = unit.card.display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 12)
	_hp_bar.max_value = unit.max_hp
	_hp_bar.value = unit.current_hp
	_hp_bar.show_percentage = false
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_hp_label)

	_fields_label = Label.new()
	_fields_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fields_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fields_label.custom_minimum_size = Vector2(0, 36)
	_fields_label.add_theme_font_size_override("font_size", 12)
	_fields_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	# PASS：既能弹出 tooltip，又不挡住选目标的点击
	_fields_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_fields_label)

	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)

	var fc := unit.field_container
	fc.field_added.connect(func(_entry: FieldEntry) -> void: _refresh_fields())
	fc.field_removed.connect(func(_id: String) -> void: _refresh_fields())
	fc.field_stacked.connect(func(_entry: FieldEntry) -> void: _refresh_fields())
	fc.field_expired.connect(func(_id: String) -> void: _refresh_fields())

	_update_hp_display()
	_refresh_fields()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		clicked.emit(unit)
		accept_event()


func set_outline(color: Color) -> void:
	var style: StyleBoxFlat = _outline.get_theme_stylebox("panel")
	style.border_color = color
	_outline.visible = true


func clear_outline() -> void:
	_outline.visible = false


func play_attack() -> void:
	if not unit.is_alive:
		return
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)


func play_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.4, 0.4), 0.08)
	tween.tween_property(self, "modulate", DEAD_TINT if not unit.is_alive else Color.WHITE, 0.2)


func _on_hp_changed(_unit: BattleUnit, old_hp: int, new_hp: int) -> void:
	_update_hp_display()
	var diff := new_hp - old_hp
	if diff != 0:
		_spawn_popup(diff)


func _on_died(_unit: BattleUnit) -> void:
	modulate = DEAD_TINT
	_fields_label.text = ""
	clear_outline()


func _update_hp_display() -> void:
	_hp_bar.value = unit.current_hp
	_hp_label.text = "%d / %d" % [unit.current_hp, unit.max_hp]


func _refresh_fields() -> void:
	var parts: PackedStringArray = []
	var tooltip_lines: PackedStringArray = []
	for entry: FieldEntry in unit.field_container.get_all_fields():
		var label := entry.display_name if entry.display_name != "" else entry.id
		if entry.current_stacks > 1:
			label += "x%d" % entry.current_stacks
		parts.append(label)
		tooltip_lines.append("「%s」%s" % [label, FieldText.describe(entry)])
	_fields_label.text = " ".join(parts)
	_fields_label.tooltip_text = "\n".join(tooltip_lines)


func _spawn_popup(diff: int) -> void:
	var label := Label.new()
	label.text = ("+%d" % diff) if diff > 0 else str(diff)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override(
		"font_color",
		Color(0.45, 1.0, 0.45) if diff > 0 else Color(1.0, 0.35, 0.3),
	)
	label.z_index = 10
	add_child(label)
	label.position = Vector2(size.x / 2.0 - 18.0, 48.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)
