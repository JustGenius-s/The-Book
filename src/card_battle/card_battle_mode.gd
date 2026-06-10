extends Control

## 卡牌对战模式：编队 → 对战（手动/自动）→ 结算奖励。

const ENCOUNTER_PATH := "res://data/encounters/demo_battle.tres"
const TEAM_SIZE := 3

@onready var _manager: CardBattleManager = $BattleManager
@onready var _turn_label: Label = $TopBar/TurnLabel
@onready var _terrain_label: Label = $TopBar/TerrainLabel
@onready var _auto_check: CheckButton = $TopBar/AutoCheck
@onready var _enemy_row: HBoxContainer = $EnemyRow
@onready var _ally_row: HBoxContainer = $AllyRow
@onready var _action_panel: HBoxContainer = $ActionPanel
@onready var _hint_label: Label = $ActionPanel/HintLabel
@onready var _skill_buttons: HBoxContainer = $ActionPanel/SkillButtons
@onready var _log: RichTextLabel = $LogPanel/Log
@onready var _team_overlay: Control = $TeamSelectOverlay
@onready var _card_grid: HBoxContainer = $TeamSelectOverlay/Center/Panel/VBox/CardGrid
@onready var _confirm_button: Button = $TeamSelectOverlay/Center/Panel/VBox/Buttons/ConfirmButton
@onready var _result_overlay: Control = $ResultOverlay
@onready var _result_label: Label = $ResultOverlay/Center/Panel/VBox/ResultLabel
@onready var _reward_label: Label = $ResultOverlay/Center/Panel/VBox/RewardLabel

var _encounter: EncounterData
var _views: Dictionary = {}
var _selected_team: Array[String] = []
var _acting_unit: BattleUnit
var _chosen_skill: SkillData


func _ready() -> void:
	_encounter = load(ENCOUNTER_PATH)

	$TopBar/BackButton.pressed.connect(GameManager.return_to_main_menu)
	$TeamSelectOverlay/Center/Panel/VBox/Buttons/MenuButton.pressed.connect(GameManager.return_to_main_menu)
	$ResultOverlay/Center/Panel/VBox/Buttons/MenuButton.pressed.connect(GameManager.return_to_main_menu)
	$ResultOverlay/Center/Panel/VBox/Buttons/RestartButton.pressed.connect(_show_team_select)
	_confirm_button.pressed.connect(_on_team_confirmed)
	_auto_check.toggled.connect(func(on: bool) -> void: _manager.set_auto_mode(on))

	_manager.turn_started.connect(_on_turn_started)
	_manager.unit_acting.connect(_on_unit_acting)
	_manager.unit_action.connect(_on_unit_action)
	_manager.unit_stunned.connect(_on_unit_stunned)
	_manager.action_requested.connect(_on_action_requested)
	_manager.battle_ended.connect(_on_battle_ended)

	_show_team_select()


# ---------- 编队 ----------

func _show_team_select() -> void:
	_result_overlay.visible = false
	_action_panel.visible = false
	_team_overlay.visible = true

	_selected_team.clear()
	for id: String in SaveManager.player.card_battle_team:
		if SaveManager.player.has_card(id) and CardLibrary.has_card(id):
			_selected_team.append(id)

	for child in _card_grid.get_children():
		child.queue_free()

	for card_id: String in SaveManager.player.owned_card_ids:
		var card: CardData = CardLibrary.get_card(card_id)
		if card == null:
			continue
		_card_grid.add_child(_make_team_tile(card))

	_update_team_select_state()


func _make_team_tile(card: CardData) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.custom_minimum_size = Vector2(150, 210)
	tile.button_pressed = _selected_team.has(card.id)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)

	var portrait := TextureRect.new()
	portrait.texture = card.portrait
	portrait.custom_minimum_size = Vector2(140, 140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait)

	var name_label := Label.new()
	name_label.text = "%s %s" % ["★".repeat(card.rarity), card.display_name]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		_update_team_select_state()
	)
	return tile


func _update_team_select_state() -> void:
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
	for child in _ally_row.get_children():
		child.queue_free()
	for child in _enemy_row.get_children():
		child.queue_free()

	var ally_cards: Array[CardData] = []
	for id: String in _selected_team:
		ally_cards.append(CardLibrary.get_card(id))

	var enemy_cards: Array[CardData] = []
	enemy_cards.assign(_encounter.enemy_cards)

	var no_equips: Array[Array] = []
	_manager.setup_battle(ally_cards, no_equips, enemy_cards, no_equips, _encounter.terrain)
	_manager.set_auto_mode(_auto_check.button_pressed)

	for unit: BattleUnit in _manager.get_enemy_units():
		_add_view(unit, _enemy_row)
	for unit: BattleUnit in _manager.get_ally_units():
		_add_view(unit, _ally_row)

	var terrain := _manager.terrain_manager.get_current_terrain()
	_terrain_label.text = "地形：%s" % terrain.display_name if terrain else ""
	_turn_label.text = "回合 0"
	_log.clear()
	_append_log("%s —— 战斗开始！" % _encounter.display_name)

	_manager.start_battle()


func _add_view(unit: BattleUnit, row: HBoxContainer) -> void:
	var view := BattleUnitView.new()
	view.setup(unit)
	view.clicked.connect(_on_unit_view_clicked)
	row.add_child(view)
	_views[unit] = view


# ---------- 手动操作 ----------

func _on_action_requested(unit: BattleUnit) -> void:
	_acting_unit = unit
	_chosen_skill = null

	var view: BattleUnitView = _views.get(unit)
	if view:
		view.set_outline(BattleUnitView.ACTING_COLOR)

	for child in _skill_buttons.get_children():
		child.queue_free()

	for skill: SkillData in unit.card.skills:
		var btn := Button.new()
		var ready_to_use := unit.can_use_skill(skill)
		btn.text = skill.display_name if ready_to_use \
			else "%s（冷却 %d）" % [skill.display_name, unit.current_cooldowns.get(skill.id, 0)]
		btn.disabled = not ready_to_use
		btn.tooltip_text = FieldText.plain_tooltip(skill)
		btn.pressed.connect(_on_skill_chosen.bind(skill))
		_skill_buttons.add_child(btn)

	_hint_label.text = "轮到 %s 行动：" % unit.card.display_name
	_action_panel.visible = true


func _on_skill_chosen(skill: SkillData) -> void:
	if _acting_unit == null:
		return
	_clear_target_outlines()

	if _manager.needs_manual_target(skill):
		_chosen_skill = skill
		_hint_label.text = "选择「%s」的目标：" % skill.display_name
		for target: BattleUnit in _manager.get_valid_targets(_acting_unit, skill):
			var view: BattleUnitView = _views.get(target)
			if view:
				view.set_outline(BattleUnitView.TARGET_COLOR)
	else:
		_submit(skill, null)


func _on_unit_view_clicked(unit: BattleUnit) -> void:
	if _acting_unit == null or _chosen_skill == null:
		return
	if not _manager.get_valid_targets(_acting_unit, _chosen_skill).has(unit):
		return
	_submit(_chosen_skill, unit)


func _submit(skill: SkillData, target: BattleUnit) -> void:
	_end_input_phase()
	_manager.submit_action(skill, target)


func _end_input_phase() -> void:
	if _acting_unit:
		var view: BattleUnitView = _views.get(_acting_unit)
		if view:
			view.clear_outline()
	_clear_target_outlines()
	_acting_unit = null
	_chosen_skill = null
	_action_panel.visible = false


func _clear_target_outlines() -> void:
	for view: BattleUnitView in _views.values():
		if view.unit != _acting_unit:
			view.clear_outline()


# ---------- 战斗事件 ----------

func _on_turn_started(turn_number: int) -> void:
	_turn_label.text = "回合 %d" % turn_number
	_append_log("—— 回合 %d ——" % turn_number)


func _on_unit_acting(unit: BattleUnit, skill: SkillData, _targets: Array[BattleUnit]) -> void:
	# 自动模式下切换行动时清理可能残留的输入态
	if _acting_unit and _acting_unit != unit:
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


func _on_unit_stunned(unit: BattleUnit) -> void:
	_append_log("%s 处于眩晕状态，无法行动" % unit.card.display_name)


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
