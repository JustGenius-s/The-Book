extends Control

## 装备商店：列出 EquipmentLibrary 全部装备，已拥有/已售罄置灰，
## 点击购买扣金币 → grant_equip → save。

const SLOT_LABEL := {"weapon":"武器","armor":"防具","accessory":"饰品"}

@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _shop_grid: GridContainer = $Scroll/Grid
@onready var _detail_overlay: Control = $DetailOverlay
@onready var _detail_name: Label = $DetailOverlay/Center/Panel/HBox/Info/NameLabel
@onready var _detail_slot: Label = $DetailOverlay/Center/Panel/HBox/Info/SlotLabel
@onready var _detail_price: Label = $DetailOverlay/Center/Panel/HBox/Info/PriceLabel
@onready var _detail_stats: Label = $DetailOverlay/Center/Panel/HBox/Info/StatsLabel
@onready var _detail_fields: RichTextLabel = $DetailOverlay/Center/Panel/HBox/Info/FieldsLabel
@onready var _detail_buy_btn: Button = $DetailOverlay/Center/Panel/HBox/Info/BuyBtn
@onready var _detail_owned_label: Label = $DetailOverlay/Center/Panel/HBox/Info/OwnedLabel
@onready var _detail_tooltip: PanelContainer = $DetailOverlay/Tooltip
@onready var _detail_tooltip_text: RichTextLabel = $DetailOverlay/Tooltip/HBox/Text
@onready var _tooltip_bg: ColorRect = $DetailOverlay/TooltipBg

var _shown_equip: EquipmentData = null


func _ready() -> void:
	_refresh_gold()
	$TopBar/BackButton.pressed.connect(GameManager.return_to_main_menu)
	$DetailOverlay/Center/Panel/HBox/Info/CloseButton.pressed.connect(func() -> void: _detail_overlay.visible = false)
	$DetailOverlay/Center/Panel/HBox/Info/BuyBtn.pressed.connect(_on_buy_pressed)
	_detail_fields.meta_clicked.connect(_on_meta_clicked)
	_tooltip_bg.gui_input.connect(func(_e: InputEvent) -> void:
		if _e is InputEventMouseButton and _e.pressed:
			_hide_tooltip()
	)
	$DetailOverlay/Tooltip/HBox/CloseBtn.pressed.connect(_hide_tooltip)

	_populate_shop()


func _refresh_gold() -> void:
	_gold_label.text = "[color=#ffdd44]金币：%d[/color]" % SaveManager.player.get_currency("gold")


func _populate_shop() -> void:
	for child in _shop_grid.get_children():
		child.queue_free()

	for equip: EquipmentData in EquipmentLibrary.get_all():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 110)
		var owned := SaveManager.player.has_equip(equip.id)
		btn.pressed.connect(_show_detail.bind(equip, owned))

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 2)
		btn.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = equip.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if owned:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(name_lbl)

		var slot_lbl := Label.new()
		slot_lbl.text = "[%s]" % SLOT_LABEL.get(equip.slot, equip.slot)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0) if not owned else Color(0.35, 0.35, 0.5))
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(slot_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d 金币" % equip.price
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if owned:
			price_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		vbox.add_child(price_lbl)

		var status_lbl := Label.new()
		if owned:
			status_lbl.text = "[已拥有]"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
			btn.modulate = Color(0.6, 0.6, 0.6)
		else:
			status_lbl.text = "点击查看"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(status_lbl)

		_shop_grid.add_child(btn)


func _show_detail(equip: EquipmentData, owned: bool) -> void:
	_shown_equip = equip
	_detail_name.text = equip.display_name
	_detail_slot.text = "槽位：[color=#88aaff]%s[/color]" % SLOT_LABEL.get(equip.slot, equip.slot)
	_detail_price.text = "售价：%d 金币" % equip.price

	var stat_lines: Array[String] = []
	if equip.stat_bonuses.has("atk") and equip.stat_bonuses["atk"] != 0:
		stat_lines.append("攻击 +%d" % int(equip.stat_bonuses["atk"]))
	if equip.stat_bonuses.has("hp") and equip.stat_bonuses["hp"] != 0:
		stat_lines.append("生命 +%d" % int(equip.stat_bonuses["hp"]))
	if equip.stat_bonuses.has("def") and equip.stat_bonuses["def"] != 0:
		stat_lines.append("防御 +%d" % int(equip.stat_bonuses["def"]))
	if equip.stat_bonuses.has("spd") and equip.stat_bonuses["spd"] != 0:
		stat_lines.append("速度 +%d" % int(equip.stat_bonuses["spd"]))
	_detail_stats.text = " | ".join(stat_lines) if stat_lines else "无属性加成"

	_detail_fields.clear()
	if not equip.innate_fields.is_empty():
		_detail_fields.append_text("[color=#aaa]固有效果：[/color]\n")
		for f in equip.innate_fields:
			_detail_fields.append_text("  · %s\n" % FieldText.field_bbcode(f))
		_detail_fields.append_text("\n")

	if not equip.passive_triggers.is_empty():
		_detail_fields.append_text("[color=#aaa]触发效果：[/color]\n")
		for trigger in equip.passive_triggers:
			var event_name := _trigger_event_name(trigger.event)
			var f_bb := FieldText.field_bbcode(trigger.field_to_apply) if trigger.field_to_apply else "?"
			_detail_fields.append_text("  · %s [%d%%] → %s (%s)\n" % [event_name, int(trigger.chance * 100), f_bb, "自身" if trigger.apply_to_self else "目标"])

	if equip.synergy_character:
		_detail_fields.append_text("\n[color=#ffcc44]羁绊角色：%s[/color]\n" % _card_name(equip.synergy_character))
		if not equip.synergy_fields.is_empty():
			for f in equip.synergy_fields:
				_detail_fields.append_text("  · %s\n" % FieldText.field_bbcode(f))

	if equip.description:
		_detail_fields.append_text("\n[i]%s[/i]" % equip.description)

	if owned:
		_detail_owned_label.text = "[color=#5a5]已拥有[/color]"
		_detail_buy_btn.visible = false
	else:
		_detail_owned_label.text = ""
		_detail_buy_btn.visible = true
		_detail_buy_btn.disabled = SaveManager.player.get_currency("gold") < equip.price
		_detail_buy_btn.text = "购买 (%d 金币)" % equip.price

	_detail_overlay.visible = true
	_hide_tooltip()


func _on_buy_pressed() -> void:
	if _shown_equip == null:
		return
	var player := SaveManager.player
	if player.get_currency("gold") < _shown_equip.price:
		return
	if player.has_equip(_shown_equip.id):
		return

	player.add_currency("gold", -_shown_equip.price)
	player.grant_equip(_shown_equip.id)
	SaveManager.save_game()
	_refresh_gold()

	# 刷新详情
	_show_detail(_shown_equip, true)
	_populate_shop()


func _on_meta_clicked(meta: String) -> void:
	var info := FieldText.lookup(meta)
	if info == "":
		return
	_detail_tooltip_text.clear()
	_detail_tooltip_text.append_text(info)
	_detail_tooltip.visible = true
	_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_tooltip() -> void:
	_detail_tooltip.visible = false
	_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _trigger_event_name(event: int) -> String:
	match event:
		EquipTrigger.TriggerEvent.ON_ATTACK: return "攻击时"
		EquipTrigger.TriggerEvent.ON_HIT: return "受击时"
		EquipTrigger.TriggerEvent.ON_TURN_START: return "回合开始"
		EquipTrigger.TriggerEvent.ON_TURN_END: return "回合结束"
		EquipTrigger.TriggerEvent.ON_KILL: return "击杀时"
		_: return "?"


func _card_name(card_id: String) -> String:
	var card := CardLibrary.get_card(card_id)
	if card:
		return card.display_name
	return card_id
