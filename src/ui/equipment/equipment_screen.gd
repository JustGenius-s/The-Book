extends Control

## 装备穿戴界面：
## 左侧卡牌列表 → 选中后右侧三槽+装备背包 → 点击背包装备即穿戴
## 主菜单「装备」入口，图鉴「装备」按钮直接跳转并预选卡牌。

const SLOT_LABEL := {"weapon":"武器","armor":"防具","accessory":"饰品"}
const SLOT_ORDER := ["weapon","armor","accessory"]

@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _card_list: VBoxContainer = $HBox/Left/Scroll/CardList
@onready var _slot_container: VBoxContainer = $HBox/Right/VBox/Slots
@onready var _selected_name: Label = $HBox/Right/VBox/PortraitRow/NameLabel
@onready var _selected_portrait: TextureRect = $HBox/Right/VBox/PortraitRow/Portrait
@onready var _bag_grid: GridContainer = $HBox/Right/VBox/BagScroll/BagGrid
@onready var _detail_overlay: Control = $DetailOverlay
@onready var _detail_name: Label = $DetailOverlay/Center/Panel/HBox/Info/NameLabel
@onready var _detail_slot: Label = $DetailOverlay/Center/Panel/HBox/Info/SlotLabel
@onready var _detail_price: Label = $DetailOverlay/Center/Panel/HBox/Info/PriceLabel
@onready var _detail_stats: Label = $DetailOverlay/Center/Panel/HBox/Info/StatsLabel
@onready var _detail_fields: RichTextLabel = $DetailOverlay/Center/Panel/HBox/Info/FieldsLabel
@onready var _detail_tooltip: PanelContainer = $DetailOverlay/Tooltip
@onready var _detail_tooltip_text: RichTextLabel = $DetailOverlay/Tooltip/HBox/Text
@onready var _tooltip_bg: ColorRect = $DetailOverlay/TooltipBg

var _selected_card: String = ""
var _selected_equip: EquipmentData = null
var _slot_nodes: Array[Control] = []
var _slot_equip_ids: Dictionary = {}


func _ready() -> void:
	_gold_label.text = "金币：%d" % SaveManager.player.get_currency("gold")
	var pre_select: String = ""
	if Engine.get_main_loop() is SceneTree:
		var meta_str := str(GameManager.get_meta("equip_preselect_card", ""))
		if meta_str:
			pre_select = meta_str
			GameManager.remove_meta("equip_preselect_card")

	$TopBar/BackButton.pressed.connect(GameManager.return_to_main_menu)
	$TopBar/ShopBtn.pressed.connect(GameManager.enter_shop)
	$DetailOverlay/Center/Panel/HBox/Info/CloseButton.pressed.connect(func() -> void: _detail_overlay.visible = false)
	_detail_fields.meta_clicked.connect(_on_meta_clicked)
	_tooltip_bg.gui_input.connect(func(_e: InputEvent) -> void:
		if _e is InputEventMouseButton and _e.pressed:
			_hide_tooltip()
	)
	$DetailOverlay/Tooltip/HBox/CloseBtn.pressed.connect(_hide_tooltip)

	_populate_card_list()
	if pre_select:
		_select_card(pre_select)


func _populate_card_list() -> void:
	for child in _card_list.get_children():
		child.queue_free()

	for card_id: String in SaveManager.player.owned_card_ids:
		var card := CardLibrary.get_card(card_id)
		if card == null:
			continue
		var btn := Button.new()
		btn.text = card.display_name
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_select_card.bind(card_id))
		_card_list.add_child(btn)

	if _card_list.get_child_count() == 0:
		var label := Label.new()
		label.text = "暂无拥有卡牌"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_list.add_child(label)


func _select_card(card_id: String) -> void:
	_selected_card = card_id
	_selected_equip = null
	var card := CardLibrary.get_card(card_id)
	if card == null:
		return

	_selected_name.text = card.display_name
	_selected_portrait.texture = card.portrait

	_refresh_slots()
	_populate_bag()


func _refresh_slots() -> void:
	for n in _slot_nodes:
		n.queue_free()
	_slot_nodes.clear()
	_slot_equip_ids.clear()

	var equips: Array[EquipmentData] = SaveManager.player.get_card_equips(_selected_card)
	for equip in equips:
		_slot_equip_ids[equip.slot] = equip.id

	for slot: String in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = SLOT_LABEL[slot] + "："
		lbl.custom_minimum_size = Vector2(60, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var equip_id: String = _slot_equip_ids.get(slot, "")
		var equip: EquipmentData = EquipmentLibrary.get_equip(equip_id)

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(220, 44)
		if equip:
			slot_btn.text = equip.display_name
			slot_btn.pressed.connect(_show_equip_detail.bind(equip))
			slot_btn.tooltip_text = "点击查看详情"
		else:
			slot_btn.text = "(空)"
			slot_btn.disabled = true

		row.add_child(lbl)
		row.add_child(slot_btn)

		if equip_id:
			var unequip_btn := Button.new()
			unequip_btn.text = "卸下"
			unequip_btn.custom_minimum_size = Vector2(60, 44)
			unequip_btn.pressed.connect(func() -> void:
				var player := SaveManager.player
				player.unequip_card(_selected_card, slot)
				_refresh_slots()
				_populate_bag()
				SaveManager.save_game()
			)
			row.add_child(unequip_btn)

		_slot_container.add_child(row)
		_slot_nodes.append(row)


func _populate_bag() -> void:
	for child in _bag_grid.get_children():
		child.queue_free()

	var owned := SaveManager.player.owned_equipment_ids.duplicate()
	var equipped_ids: Array[String] = []
	for card_id: String in SaveManager.player.card_equipment:
		for s in SaveManager.player.card_equipment[card_id]:
			equipped_ids.append(SaveManager.player.card_equipment[card_id][s])

	for equip_id: String in owned:
		var equip := EquipmentLibrary.get_equip(equip_id)
		if equip == null:
			continue

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 100)
		btn.pressed.connect(func() -> void:
			if _selected_card == "":
				return
			var player := SaveManager.player
			var eq := EquipmentLibrary.get_equip(equip_id)
			if eq == null:
				return
			if _slot_equip_ids.get(eq.slot, "") == equip_id:
				player.unequip_card(_selected_card, eq.slot)
			else:
				player.equip_card(_selected_card, equip_id)
			_refresh_slots()
			_populate_bag()
			SaveManager.save_game()
		)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 2)
		btn.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = equip.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var slot_lbl := Label.new()
		slot_lbl.text = "[%s]" % SLOT_LABEL.get(equip.slot, equip.slot)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(slot_lbl)

		var is_equipped_here: bool = _slot_equip_ids.get(equip.slot, "") == equip_id
		var is_equipped_other: bool = equipped_ids.has(equip_id) and not is_equipped_here
		var status_lbl := Label.new()
		if is_equipped_here:
			status_lbl.text = "★ 已穿戴"
			status_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif is_equipped_other:
			status_lbl.text = "穿戴中(其他)"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		else:
			status_lbl.text = "点击穿戴"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(status_lbl)

		_bag_grid.add_child(btn)


func _show_equip_detail(equip: EquipmentData) -> void:
	_selected_equip = equip
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

	_detail_overlay.visible = true
	_hide_tooltip()


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
		EquipTrigger.TriggerEvent.ON_ALLY_DEATH: return "友方阵亡"
		_: return "?"


func _card_name(card_id: String) -> String:
	var card := CardLibrary.get_card(card_id)
	if card:
		return card.display_name
	return card_id
