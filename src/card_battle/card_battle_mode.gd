extends Control

## 卡牌对战模式：编队（带站位）→ 对战（手动/自动）→ 结算奖励。
## 战斗布局：我方左列、敌方右列；右侧垂直行动条；右下技能图标栏；日志折叠抽屉。

const ENCOUNTER_PATH := "res://data/encounters/demo_battle.tres"
const TEAM_SIZE := 3
const DEFAULT_BG_COLOR := Color(0.09, 0.08, 0.12)
const ALLY_FRAME_COLOR := Color(0.35, 0.75, 1.0)
const ENEMY_FRAME_COLOR := Color(0.95, 0.45, 0.4)
const CURRENT_FRAME_COLOR := Color(1.0, 0.9, 0.3)

@onready var _manager: CardBattleManager = $BattleManager
@onready var _turn_label: Label = $TopBar/TurnLabel
@onready var _terrain_label: Label = $TopBar/TerrainLabel
@onready var _auto_check: CheckButton = $TopBar/AutoCheck
@onready var _log_button: Button = $TopBar/LogButton
@onready var _ally_column: VBoxContainer = $AllyColumn
@onready var _enemy_column: VBoxContainer = $EnemyColumn
@onready var _order_bar: VBoxContainer = $OrderBar
@onready var _detail_panel: PanelContainer = $BottomRight/DetailPanel
@onready var _detail_text: RichTextLabel = $BottomRight/DetailPanel/DetailText
@onready var _battle_tooltip: PanelContainer = $BottomRight/DetailTooltip
@onready var _battle_tooltip_text: RichTextLabel = $BottomRight/DetailTooltip/HBox/Text
@onready var _battle_tooltip_bg: ColorRect = $BottomRight/DetailTooltipBg
@onready var _battle_tooltip_close: Button = $BottomRight/DetailTooltip/HBox/CloseBtn
@onready var _hint_label: Label = $BottomRight/HintLabel
@onready var _skill_icons: HBoxContainer = $BottomRight/SkillIcons
@onready var _log_drawer: PanelContainer = $LogDrawer
@onready var _log: RichTextLabel = $LogDrawer/Log
@onready var _team_overlay: Control = $TeamSelectOverlay
@onready var _card_grid: HBoxContainer = $TeamSelectOverlay/Center/Panel/VBox/CardGrid
@onready var _slot_row: HBoxContainer = $TeamSelectOverlay/Center/Panel/VBox/SlotRow
@onready var _confirm_button: Button = $TeamSelectOverlay/Center/Panel/VBox/Buttons/ConfirmButton
@onready var _result_overlay: Control = $ResultOverlay
@onready var _result_label: Label = $ResultOverlay/Center/Panel/VBox/ResultLabel
@onready var _reward_label: Label = $ResultOverlay/Center/Panel/VBox/RewardLabel

var _encounter: EncounterData
var _views: Dictionary = {}
var _bg_front_is_a: bool = true
var _bg_tween: Tween
var _selected_team: Array[String] = []
var _team_tiles: Dictionary = {}
var _slot_buttons: Array[Button] = []
var _acting_unit: BattleUnit
var _selected_skill: SkillData
var _skill_buttons: Dictionary = {}


func _ready() -> void:
	_encounter = load(ENCOUNTER_PATH)

	$TopBar/BackButton.pressed.connect(GameManager.return_to_main_menu)
	$TeamSelectOverlay/Center/Panel/VBox/Buttons/MenuButton.pressed.connect(GameManager.return_to_main_menu)
	$ResultOverlay/Center/Panel/VBox/Buttons/MenuButton.pressed.connect(GameManager.return_to_main_menu)
	$ResultOverlay/Center/Panel/VBox/Buttons/RestartButton.pressed.connect(_show_team_select)
	_confirm_button.pressed.connect(_on_team_confirmed)
	_auto_check.toggled.connect(func(on: bool) -> void: _manager.set_auto_mode(on))
	_log_button.toggled.connect(func(on: bool) -> void: _log_drawer.visible = on)

	_manager.turn_started.connect(_on_turn_started)
	_manager.unit_acting.connect(_on_unit_acting)
	_manager.unit_action.connect(_on_unit_action)
	_manager.unit_stunned.connect(_on_unit_stunned)
	_manager.action_requested.connect(_on_action_requested)
	_manager.action_order_changed.connect(_refresh_order_bar)
	_manager.battle_ended.connect(_on_battle_ended)

	_detail_text.meta_clicked.connect(_on_battle_detail_meta_clicked)
	_battle_tooltip_bg.gui_input.connect(func(_e: InputEvent) -> void:
		if _e is InputEventMouseButton and _e.pressed:
			_hide_battle_tooltip()
	)
	_battle_tooltip_close.pressed.connect(_hide_battle_tooltip)

	_show_team_select()


# ---------- 编队与站位 ----------

func _show_team_select() -> void:
	_result_overlay.visible = false
	_end_input_phase()
	_team_overlay.visible = true

	_selected_team.clear()
	for id: String in SaveManager.player.card_battle_team:
		if SaveManager.player.has_card(id) and CardLibrary.has_card(id):
			_selected_team.append(id)

	_team_tiles.clear()
	for child in _card_grid.get_children():
		child.queue_free()
	for card_id: String in SaveManager.player.owned_card_ids:
		var card: CardData = CardLibrary.get_card(card_id)
		if card == null:
			continue
		var tile := _make_team_tile(card)
		_card_grid.add_child(tile)
		_team_tiles[card.id] = tile

	_slot_buttons.clear()
	for child in _slot_row.get_children():
		child.queue_free()
	for i in TEAM_SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(150, 190)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	_refresh_slots()


func _make_team_tile(card: CardData) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.custom_minimum_size = Vector2(130, 170)
	tile.button_pressed = _selected_team.has(card.id)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)

	var portrait := TextureRect.new()
	portrait.texture = card.portrait
	portrait.custom_minimum_size = Vector2(120, 110)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait)

	var name_label := Label.new()
	name_label.text = "%s %s" % ["★".repeat(card.rarity), card.display_name]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	tile.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			if _selected_team.size() >= TEAM_SIZE:
				tile.set_pressed_no_signal(false)
				return
			if not _selected_team.has(card.id):
				_selected_team.append(card.id)
		else:
			_selected_team.erase(card.id)
		_refresh_slots()
	)
	return tile


func _on_slot_pressed(index: int) -> void:
	if index >= _selected_team.size():
		return
	var removed := _selected_team[index]
	_selected_team.remove_at(index)
	var tile: Button = _team_tiles.get(removed)
	if tile:
		tile.set_pressed_no_signal(false)
	_refresh_slots()


func _refresh_slots() -> void:
	for i in TEAM_SIZE:
		var slot := _slot_buttons[i]
		for child in slot.get_children():
			child.queue_free()

		if i < _selected_team.size():
			var card: CardData = CardLibrary.get_card(_selected_team[i])
			var vbox := VBoxContainer.new()
			vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_theme_constant_override("separation", 4)
			slot.add_child(vbox)

			var portrait := TextureRect.new()
			portrait.texture = card.portrait
			portrait.custom_minimum_size = Vector2(140, 124)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(portrait)

			var label := Label.new()
			label.text = "%d 号位  %s" % [i + 1, card.display_name]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 13)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(label)
			slot.text = ""
		else:
			slot.text = "%d 号位\n（空）" % [i + 1]

	_confirm_button.disabled = _selected_team.is_empty()
	_confirm_button.text = "出战（%d/%d）" % [_selected_team.size(), TEAM_SIZE]


func _on_team_confirmed() -> void:
	SaveManager.player.card_battle_team.assign(_selected_team)
	SaveManager.save_game()
	_team_overlay.visible = false
	_start_battle()


# ---------- 战斗 ----------

func _start_battle() -> void:
	_result_overlay.visible = false
	_views.clear()
	for child in _ally_column.get_children():
		child.queue_free()
	for child in _enemy_column.get_children():
		child.queue_free()

	var ally_cards: Array[CardData] = []
	for id: String in _selected_team:
		ally_cards.append(CardLibrary.get_card(id))

	var enemy_cards: Array[CardData] = []
	enemy_cards.assign(_encounter.enemy_cards)

	# 遭遇战指定了场地则用之，否则随机；保证每场战斗都有场地
	var terrain: TerrainData = _encounter.terrain
	if terrain == null:
		terrain = TerrainLibrary.get_random()

	# 读取每个参战卡牌的装备
	var ally_equips: Array[Array] = []
	for id: String in _selected_team:
		var equips := SaveManager.player.get_card_equips(id)
		ally_equips.append(equips)

	var no_equips: Array[Array] = []
	_manager.setup_battle(ally_cards, ally_equips, enemy_cards, no_equips, terrain)
	_manager.set_auto_mode(_auto_check.button_pressed)
	# TerrainManager / TraitProcessor 每场战斗都会重建，需要重新连接
	_manager.terrain_manager.terrain_changed.connect(_on_terrain_changed)
	_manager.trait_processor.trait_activated.connect(_on_trait_activated)
	_manager.trait_processor.trait_deactivated.connect(_on_trait_deactivated)

	# 站位顺序：1 号位在最上方（单体攻击默认命中存活的最前位）
	for unit: BattleUnit in _manager.get_ally_units():
		_add_view(unit, _ally_column, false)
	for unit: BattleUnit in _manager.get_enemy_units():
		_add_view(unit, _enemy_column, true)

	_update_terrain_display()
	_turn_label.text = "回合 0"
	_log.clear()
	_append_log("%s —— 战斗开始！" % _encounter.display_name)
	if terrain:
		_append_log("本场战场：%s —— %s" % [terrain.display_name, terrain.description])
	# 开场即激活的特性发生在信号连接之前，这里补记日志
	for entry: Dictionary in _manager.trait_processor.get_active():
		_on_trait_activated(entry["unit"], entry["trait"])
	_refresh_order_bar()

	_manager.start_battle()


# ---------- 场地 ----------

func _on_terrain_changed(_old_id: String, _new_id: String) -> void:
	_update_terrain_display()
	var terrain := _manager.terrain_manager.get_current_terrain()
	if terrain:
		_append_log("场地化为「%s」—— %s" % [terrain.display_name, terrain.description])
	else:
		_append_log("场地恢复如常")


func _update_terrain_display() -> void:
	var terrain := _manager.terrain_manager.get_current_terrain()

	if terrain:
		_terrain_label.text = "场地：%s" % terrain.display_name
		var tooltip_lines: PackedStringArray = [terrain.description]
		for field: FieldEntry in terrain.global_fields:
			tooltip_lines.append("「%s」%s" % [field.display_name, FieldText.describe(field)])
		_terrain_label.tooltip_text = "\n".join(tooltip_lines)
	else:
		_terrain_label.text = ""
		_terrain_label.tooltip_text = ""

	_transition_terrain_bg(terrain)


func _transition_terrain_bg(terrain: TerrainData) -> void:
	# TODO: terrain.bg_scene_path 非空时实例化动画场景替代静态图（后期动画效果）
	var bg_color := terrain.bg_color if terrain else DEFAULT_BG_COLOR
	var new_texture: Texture2D = terrain.bg_texture if terrain else null

	var front: TextureRect = $BgA if _bg_front_is_a else $BgB
	var back: TextureRect = $BgB if _bg_front_is_a else $BgA

	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()

	_bg_tween = create_tween()
	_bg_tween.set_parallel(true)
	_bg_tween.tween_property($Background, "color", bg_color, 0.8)
	_bg_tween.tween_property(
		$BgDim, "color",
		Color(bg_color.r, bg_color.g, bg_color.b, 0.45),
		0.8,
	)

	if front.texture == new_texture:
		return

	back.texture = new_texture
	back.modulate.a = 0.0
	_bg_tween.tween_property(back, "modulate:a", 1.0 if new_texture else 0.0, 0.8)
	_bg_tween.tween_property(front, "modulate:a", 0.0, 0.8)
	_bg_front_is_a = not _bg_front_is_a


func _add_view(unit: BattleUnit, column: VBoxContainer, mirrored: bool) -> void:
	var view := BattleUnitView.new()
	view.setup(unit, mirrored)
	view.clicked.connect(_on_unit_view_clicked)
	unit.form_changed.connect(_on_unit_form_changed)
	column.add_child(view)
	_views[unit] = view


func _on_unit_form_changed(_unit: BattleUnit, old_card: CardData, new_card: CardData) -> void:
	_append_log("[color=%s]%s 形态变化 → %s！[/color]" % [
		FieldText.TRAIT_COLOR, old_card.display_name, new_card.display_name,
	])
	_refresh_order_bar()


# ---------- 行动条 ----------

func _refresh_order_bar() -> void:
	for child in _order_bar.get_children():
		child.queue_free()

	var order := _manager.get_action_order()
	var index := _manager.get_action_index()

	for i in order.size():
		var unit := order[i]
		if not unit.is_alive:
			continue

		var is_current := i == index
		var frame := Panel.new()
		var frame_size := 52 if is_current else 42
		frame.custom_minimum_size = Vector2(frame_size, frame_size)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.4)
		style.set_corner_radius_all(6)
		style.set_border_width_all(3 if is_current else 2)
		if is_current:
			style.border_color = CURRENT_FRAME_COLOR
		else:
			style.border_color = ALLY_FRAME_COLOR if _manager.is_ally(unit) else ENEMY_FRAME_COLOR
		frame.add_theme_stylebox_override("panel", style)

		var portrait := TextureRect.new()
		portrait.texture = unit.card.portrait
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 3.0
		portrait.offset_top = 3.0
		portrait.offset_right = -3.0
		portrait.offset_bottom = -3.0
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(portrait)

		if i < index:
			frame.modulate = Color(1, 1, 1, 0.35)

		frame.tooltip_text = unit.card.display_name
		_order_bar.add_child(frame)


# ---------- 手动操作：点选技能 → 再点释放 ----------

func _on_action_requested(unit: BattleUnit) -> void:
	_acting_unit = unit
	_selected_skill = null

	var view: BattleUnitView = _views.get(unit)
	if view:
		view.set_outline(BattleUnitView.ACTING_COLOR)

	_skill_buttons.clear()
	for child in _skill_icons.get_children():
		child.queue_free()

	for skill: SkillData in unit.card.skills:
		var btn := _make_skill_button(unit, skill)
		_skill_icons.add_child(btn)
		_skill_buttons[skill] = btn

	_hint_label.text = "轮到 %s：点击技能查看并选中，再次点击释放" % unit.card.display_name
	_skill_icons.visible = true
	_hint_label.visible = true


func _make_skill_button(unit: BattleUnit, skill: SkillData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(72, 72)

	if skill.icon:
		btn.icon = skill.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# 没有图标素材时用技能名首字作为占位图标
		btn.text = skill.display_name.substr(0, 1)
		btn.add_theme_font_size_override("font_size", 30)

	var ready_to_use := unit.can_use_skill(skill)
	btn.disabled = not ready_to_use
	if not ready_to_use:
		var cd := Label.new()
		cd.text = "冷却%d" % int(unit.current_cooldowns.get(skill.id, 0))
		cd.add_theme_font_size_override("font_size", 11)
		cd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cd.offset_left = -40.0
		cd.offset_top = -18.0
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cd)

	btn.toggled.connect(_on_skill_toggled.bind(skill))
	return btn


func _on_skill_toggled(pressed: bool, skill: SkillData) -> void:
	if _acting_unit == null:
		return

	if pressed:
		# 第一次点击：选中技能，弹出详情，高亮可选目标
		if _selected_skill and _selected_skill != skill:
			var prev: Button = _skill_buttons.get(_selected_skill)
			if prev:
				prev.set_pressed_no_signal(false)
		_selected_skill = skill
		_show_skill_detail(skill)
		_clear_target_outlines()

		if _manager.needs_manual_target(skill):
			for target: BattleUnit in _manager.get_valid_targets(_acting_unit, skill):
				var view: BattleUnitView = _views.get(target)
				if view:
					view.set_outline(BattleUnitView.TARGET_COLOR)
			_hint_label.text = "点击目标释放「%s」，或再次点击图标释放（默认目标）" % skill.display_name
		else:
			_hint_label.text = "再次点击图标释放「%s」" % skill.display_name
	else:
		# 第二次点击同一技能：释放（单体技能命中默认目标）
		if _selected_skill == skill:
			_cast(skill, null)


func _on_unit_view_clicked(unit: BattleUnit) -> void:
	if _acting_unit == null or _selected_skill == null:
		return
	if not _manager.get_valid_targets(_acting_unit, _selected_skill).has(unit):
		return
	_cast(_selected_skill, unit)


func _show_skill_detail(skill: SkillData) -> void:
	_detail_text.clear()
	_detail_text.append_text(FieldText.skill_bbcode(skill))
	_detail_panel.visible = true
	_hide_battle_tooltip()


func _hide_battle_tooltip() -> void:
	_battle_tooltip.visible = false
	_battle_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_battle_tooltip() -> void:
	_battle_tooltip.visible = true
	_battle_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_battle_detail_meta_clicked(meta: String) -> void:
	var info := FieldText.lookup(meta)
	if info == "":
		return
	_battle_tooltip_text.clear()
	_battle_tooltip_text.append_text(info)
	_show_battle_tooltip()


func _cast(skill: SkillData, target: BattleUnit) -> void:
	_end_input_phase()
	_manager.submit_action(skill, target)


func _end_input_phase() -> void:
	if _acting_unit:
		var view: BattleUnitView = _views.get(_acting_unit)
		if view:
			view.clear_outline()
	_clear_target_outlines()
	_acting_unit = null
	_selected_skill = null
	_skill_buttons.clear()
	for child in _skill_icons.get_children():
		child.queue_free()
	_detail_panel.visible = false
	_hide_battle_tooltip()
	_hint_label.visible = false


func _clear_target_outlines() -> void:
	for view: BattleUnitView in _views.values():
		if view.unit != _acting_unit:
			view.clear_outline()


# ---------- 战斗事件 ----------

func _on_turn_started(turn_number: int) -> void:
	_turn_label.text = "回合 %d" % turn_number
	_append_log("—— 回合 %d ——" % turn_number)


func _on_unit_acting(unit: BattleUnit, skill: SkillData, _targets: Array[BattleUnit]) -> void:
	# 单位开始行动即意味着输入阶段结束（含切自动后 AI 代操作的情况）
	if _acting_unit:
		_end_input_phase()
	var view: BattleUnitView = _views.get(unit)
	if view:
		view.play_attack()
	_append_log("%s 使用「%s」" % [unit.card.display_name, skill.display_name])


func _on_unit_action(
	_attacker: BattleUnit,
	_skill: SkillData,
	target: BattleUnit,
	result: SkillExecutor.SkillResult,
) -> void:
	var view: BattleUnitView = _views.get(target)

	if result.damage > 0:
		if view:
			view.play_hit()
		_append_log("    %s 受到 %d 点伤害" % [target.card.display_name, result.damage])

	if result.heal > 0:
		_append_log("    %s 恢复 %d 点生命" % [target.card.display_name, result.heal])

	for field: FieldEntry in result.fields_for_target:
		_append_log("    %s 获得「%s」" % [target.card.display_name, field.display_name])

	if not target.is_alive:
		_append_log("    %s 被击败！" % target.card.display_name)
		_refresh_order_bar()


func _on_unit_stunned(unit: BattleUnit) -> void:
	_append_log("%s 处于眩晕状态，无法行动" % unit.card.display_name)


func _on_trait_activated(unit: BattleUnit, trait_data: TraitData) -> void:
	_append_log("[color=%s]%s 触发特性【%s】[/color]" % [
		FieldText.TRAIT_COLOR, unit.card.display_name, trait_data.display_name,
	])


func _on_trait_deactivated(unit: BattleUnit, trait_data: TraitData) -> void:
	_append_log("[color=%s]%s 的特性【%s】失效[/color]" % [
		FieldText.TRAIT_COLOR, unit.card.display_name, trait_data.display_name,
	])


func _on_battle_ended(winner: String) -> void:
	_end_input_phase()

	var text: String
	match winner:
		"ally":
			text = "胜利！"
		"enemy":
			text = "战败…"
		_:
			text = "平局"
	_append_log("战斗结束：%s" % text)

	_reward_label.text = ""
	if winner == "ally" and _encounter.reward_gold > 0:
		SaveManager.player.add_currency("gold", _encounter.reward_gold)
		SaveManager.save_game()
		_reward_label.text = "获得 %d 金币（当前 %d）" % [
			_encounter.reward_gold,
			SaveManager.player.get_currency("gold"),
		]

	_result_label.text = text
	_result_overlay.visible = true


func _append_log(line: String) -> void:
	_log.append_text(line + "\n")
