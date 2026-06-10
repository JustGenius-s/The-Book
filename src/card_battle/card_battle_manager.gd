class_name CardBattleManager
extends Node

signal battle_started
signal turn_started(turn_number: int)
signal unit_acting(unit: BattleUnit, skill: SkillData, targets: Array[BattleUnit])
signal unit_action(attacker: BattleUnit, skill: SkillData, target: BattleUnit, result: SkillExecutor.SkillResult)
signal unit_stunned(unit: BattleUnit)
signal turn_ended(turn_number: int)
signal battle_ended(winner: String)
## 轮到我方单位且处于手动模式时发出，UI 应调用 submit_action() 提交行动
signal action_requested(unit: BattleUnit)
signal action_submitted
## 本回合行动序列计算完成或行动进度推进时发出（配合 get_action_order/index 使用）
signal action_order_changed

enum BattleState { IDLE, RUNNING, FINISHED }

## 每次行动之间的停顿，让战斗过程可以被观看
@export var action_delay: float = 0.9
## 攻击动画起手到结算之间的停顿
@export var pre_hit_delay: float = 0.25
## 回合之间的停顿
@export var turn_delay: float = 0.5

var state: BattleState = BattleState.IDLE
var turn_number: int = 0
var global_fields: FieldContainer = FieldContainer.new()
var terrain_manager: TerrainManager
## 自动模式下我方单位由 AI 行动；敌方始终 AI
var auto_mode: bool = false

var _ally_units: Array[BattleUnit] = []
var _enemy_units: Array[BattleUnit] = []
var _all_units: Array[BattleUnit] = []
var _waiting_for_input: bool = false
var _waiting_unit: BattleUnit
var _pending_skill: SkillData
var _pending_target: BattleUnit
var _action_order: Array[BattleUnit] = []
var _action_index: int = -1


func setup_battle(
	ally_cards: Array[CardData],
	ally_equips: Array[Array],
	enemy_cards: Array[CardData],
	enemy_equips: Array[Array],
	initial_terrain: TerrainData = null,
) -> void:
	for unit: BattleUnit in _all_units:
		if is_instance_valid(unit):
			unit.queue_free()

	state = BattleState.IDLE
	turn_number = 0
	global_fields = FieldContainer.new()
	terrain_manager = TerrainManager.new(global_fields)

	# 若上一场战斗的协程还在等待玩家输入，唤醒它让其因 state 变化而退出
	if _waiting_for_input:
		_waiting_for_input = false
		action_submitted.emit()

	_ally_units.clear()
	_enemy_units.clear()
	_all_units.clear()

	for i in ally_cards.size():
		var unit := BattleUnit.new()
		var equips: Array[EquipmentData] = []
		if i < ally_equips.size():
			equips.assign(ally_equips[i])
		unit.setup(ally_cards[i], equips, global_fields)
		_ally_units.append(unit)
		_all_units.append(unit)
		add_child(unit)

	for i in enemy_cards.size():
		var unit := BattleUnit.new()
		var equips: Array[EquipmentData] = []
		if i < enemy_equips.size():
			equips.assign(enemy_equips[i])
		unit.setup(enemy_cards[i], equips, global_fields)
		_enemy_units.append(unit)
		_all_units.append(unit)
		add_child(unit)

	if initial_terrain:
		terrain_manager.set_terrain(initial_terrain)


func get_ally_units() -> Array[BattleUnit]:
	return _ally_units


func get_enemy_units() -> Array[BattleUnit]:
	return _enemy_units


func is_ally(unit: BattleUnit) -> bool:
	return _ally_units.has(unit)


## 当前回合的行动序列与进度（供行动条 UI 使用）
func get_action_order() -> Array[BattleUnit]:
	return _action_order


func get_action_index() -> int:
	return _action_index


## 该技能是否需要玩家手动指定目标
func needs_manual_target(skill: SkillData) -> bool:
	return skill.target == SkillData.TargetType.SINGLE_ENEMY \
		or skill.target == SkillData.TargetType.SINGLE_ALLY


## 当前可被该技能选中的目标列表（供 UI 高亮）
func get_valid_targets(unit: BattleUnit, skill: SkillData) -> Array[BattleUnit]:
	var enemies := _enemy_units if is_ally(unit) else _ally_units
	var allies := _ally_units if is_ally(unit) else _enemy_units
	var pool := enemies if skill.target == SkillData.TargetType.SINGLE_ENEMY else allies
	var result: Array[BattleUnit] = []
	for u: BattleUnit in pool:
		if u.is_alive:
			result.append(u)
	return result


## UI 提交玩家选择的行动；target 仅对单体技能有意义
func submit_action(skill: SkillData, target: BattleUnit = null) -> void:
	if not _waiting_for_input:
		return
	_pending_skill = skill
	_pending_target = target
	_waiting_for_input = false
	action_submitted.emit()


func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled
	# 正在等玩家输入时切自动，立刻由 AI 代为行动
	if enabled and _waiting_for_input and _waiting_unit:
		submit_action(_select_skill(_waiting_unit), null)


func start_battle() -> void:
	state = BattleState.RUNNING
	battle_started.emit()
	_run_battle()


func _run_battle() -> void:
	while state == BattleState.RUNNING:
		turn_number += 1
		turn_started.emit(turn_number)

		_action_order = _get_action_order()
		_action_index = -1
		action_order_changed.emit()

		for i in _action_order.size():
			var unit := _action_order[i]
			if state != BattleState.RUNNING:
				return
			_action_index = i
			action_order_changed.emit()
			if not unit.is_alive:
				continue

			unit.process_turn_start()
			_process_equip_triggers(unit, EquipTrigger.TriggerEvent.ON_TURN_START, unit)
			if not unit.is_alive:
				if _check_battle_end():
					return
				continue

			if _is_stunned(unit):
				unit_stunned.emit(unit)
				await _wait(action_delay * 0.6)
				if state != BattleState.RUNNING:
					return
				continue

			var skill: SkillData
			var targets: Array[BattleUnit]

			if is_ally(unit) and not auto_mode:
				_waiting_for_input = true
				_waiting_unit = unit
				action_requested.emit(unit)
				await action_submitted
				_waiting_unit = null
				if state != BattleState.RUNNING:
					return
				skill = _pending_skill
				targets = _resolve_player_targets(unit, skill, _pending_target)
			else:
				skill = _select_skill(unit)
				targets = _select_targets(unit, skill)

			if skill == null:
				continue

			unit_acting.emit(unit, skill, targets)
			await _wait(pre_hit_delay)
			if state != BattleState.RUNNING:
				return

			_execute_action(unit, skill, targets)

			if _check_battle_end():
				return

			await _wait(action_delay)
			if state != BattleState.RUNNING:
				return

		for unit: BattleUnit in _all_units:
			if unit.is_alive:
				unit.process_turn_end()
				_process_equip_triggers(unit, EquipTrigger.TriggerEvent.ON_TURN_END, unit)

		global_fields.tick()
		turn_ended.emit(turn_number)

		if turn_number >= 100:
			_finish_battle("draw")
			return

		await _wait(turn_delay)


func _wait(seconds: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout


func _get_action_order() -> Array[BattleUnit]:
	var alive: Array[BattleUnit] = []
	for unit: BattleUnit in _all_units:
		if unit.is_alive:
			alive.append(unit)

	alive.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.get_final_stat("spd") > b.get_final_stat("spd")
	)
	return alive


func _select_skill(unit: BattleUnit) -> SkillData:
	for skill: SkillData in unit.card.skills:
		if unit.can_use_skill(skill) and skill.cooldown > 0:
			return skill

	if unit.card.skills.size() > 0:
		return unit.card.skills[0]

	return null


func _select_targets(unit: BattleUnit, skill: SkillData) -> Array[BattleUnit]:
	var allies := _ally_units if _ally_units.has(unit) else _enemy_units
	var enemies := _enemy_units if _ally_units.has(unit) else _ally_units
	var result: Array[BattleUnit] = []

	match skill.target:
		SkillData.TargetType.SELF:
			result.append(unit)
		SkillData.TargetType.SINGLE_ENEMY:
			var alive := enemies.filter(func(u: BattleUnit) -> bool: return u.is_alive)
			if alive.size() > 0:
				result.append(alive[0])
		SkillData.TargetType.ALL_ENEMIES:
			result.append_array(enemies.filter(func(u: BattleUnit) -> bool: return u.is_alive))
		SkillData.TargetType.SINGLE_ALLY:
			var alive := allies.filter(func(u: BattleUnit) -> bool: return u.is_alive)
			if alive.size() > 0:
				result.append(alive[0])
		SkillData.TargetType.ALL_ALLIES:
			result.append_array(allies.filter(func(u: BattleUnit) -> bool: return u.is_alive))
		SkillData.TargetType.RANDOM_ENEMY:
			var alive := enemies.filter(func(u: BattleUnit) -> bool: return u.is_alive)
			if alive.size() > 0:
				result.append(alive[randi() % alive.size()])

	return result


## 玩家手选目标合法时优先使用，否则退回 AI 规则（群体/自身技能也走这里）
func _resolve_player_targets(unit: BattleUnit, skill: SkillData, chosen: BattleUnit) -> Array[BattleUnit]:
	if skill == null:
		return []
	if chosen != null and is_instance_valid(chosen) and chosen.is_alive and needs_manual_target(skill):
		var result: Array[BattleUnit] = [chosen]
		return result
	return _select_targets(unit, skill)


func _execute_action(attacker: BattleUnit, skill: SkillData, targets: Array[BattleUnit]) -> void:
	attacker.put_skill_on_cooldown(skill)

	for target: BattleUnit in targets:
		var result := SkillExecutor.execute(
			skill,
			attacker.get_final_stat("atk"),
			target.get_final_stat("def"),
			attacker.field_container,
			target.field_container,
			global_fields,
		)

		if result.damage > 0:
			target.take_damage(result.damage)

		if result.heal > 0:
			target.heal(result.heal)

		for field: FieldEntry in result.fields_for_target:
			target.field_container.add_field(field)

		for field: FieldEntry in result.fields_for_self:
			attacker.field_container.add_field(field)

		for field: FieldEntry in result.fields_for_global:
			global_fields.add_field(field)

		for field_id: String in result.fields_to_remove:
			target.field_container.remove_field(field_id)

		if result.terrain_to_create != "":
			var current := terrain_manager.get_current_terrain()
			# 同场地不重复设置（群体技能会按目标多次结算）
			if current == null or current.id != result.terrain_to_create:
				var terrain_res := load("res://data/terrains/%s.tres" % result.terrain_to_create)
				if terrain_res is TerrainData:
					terrain_manager.set_terrain(terrain_res)

		_process_equip_triggers(attacker, EquipTrigger.TriggerEvent.ON_ATTACK, target)
		_process_equip_triggers(target, EquipTrigger.TriggerEvent.ON_HIT, attacker)

		if not target.is_alive:
			_process_equip_triggers(attacker, EquipTrigger.TriggerEvent.ON_KILL, target)

		unit_action.emit(attacker, skill, target, result)


func _process_equip_triggers(unit: BattleUnit, event: EquipTrigger.TriggerEvent, other: BattleUnit) -> void:
	var triggered := unit.check_equip_triggers(event)
	for trigger: EquipTrigger in triggered:
		if trigger.field_to_apply:
			var copy := trigger.field_to_apply.duplicate_entry()
			copy.source = FieldEntry.FieldSource.EQUIPMENT
			if trigger.apply_to_self:
				unit.field_container.add_field(copy)
			else:
				other.field_container.add_field(copy)


func _is_stunned(unit: BattleUnit) -> bool:
	return unit.field_container.has_field("stun")


func _check_battle_end() -> bool:
	var allies_alive := _ally_units.any(func(u: BattleUnit) -> bool: return u.is_alive)
	var enemies_alive := _enemy_units.any(func(u: BattleUnit) -> bool: return u.is_alive)

	if not enemies_alive:
		_finish_battle("ally")
		return true
	if not allies_alive:
		_finish_battle("enemy")
		return true

	return false


func _finish_battle(winner: String) -> void:
	state = BattleState.FINISHED
	battle_ended.emit(winner)
