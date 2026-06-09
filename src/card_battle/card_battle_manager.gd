class_name CardBattleManager
extends Node

signal battle_started
signal turn_started(turn_number: int)
signal unit_action(unit: BattleUnit, skill: SkillData, result: SkillExecutor.SkillResult)
signal turn_ended(turn_number: int)
signal battle_ended(winner: String)

enum BattleState { IDLE, RUNNING, FINISHED }

var state: BattleState = BattleState.IDLE
var turn_number: int = 0
var global_fields: FieldContainer = FieldContainer.new()
var terrain_manager: TerrainManager

var _ally_units: Array[BattleUnit] = []
var _enemy_units: Array[BattleUnit] = []
var _all_units: Array[BattleUnit] = []


func setup_battle(
	ally_cards: Array[CardData],
	ally_equips: Array[Array],
	enemy_cards: Array[CardData],
	enemy_equips: Array[Array],
	initial_terrain: TerrainData = null,
) -> void:
	state = BattleState.IDLE
	turn_number = 0
	global_fields = FieldContainer.new()
	terrain_manager = TerrainManager.new(global_fields)

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


func start_battle() -> void:
	state = BattleState.RUNNING
	battle_started.emit()
	_run_battle()


func _run_battle() -> void:
	while state == BattleState.RUNNING:
		turn_number += 1
		turn_started.emit(turn_number)

		var action_order := _get_action_order()

		for unit: BattleUnit in action_order:
			if not unit.is_alive:
				continue

			unit.process_turn_start()
			if not unit.is_alive:
				if _check_battle_end():
					return
				continue

			if _is_stunned(unit):
				continue

			var skill := _select_skill(unit)
			if skill == null:
				continue

			var targets := _select_targets(unit, skill)
			_execute_action(unit, skill, targets)

			if _check_battle_end():
				return

		for unit: BattleUnit in _all_units:
			if unit.is_alive:
				unit.process_turn_end()

		global_fields.tick()
		turn_ended.emit(turn_number)

		if turn_number >= 100:
			_finish_battle("draw")
			return


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


func _execute_action(attacker: BattleUnit, skill: SkillData, targets: Array[BattleUnit]) -> void:
	attacker.put_skill_on_cooldown(skill)

	for target: BattleUnit in targets:
		var result := SkillExecutor.execute(
			skill,
			attacker.get_final_stat("atk"),
			attacker.field_container,
			target.field_container,
			global_fields,
		)

		if result.damage > 0:
			target.take_damage(result.damage)

		if result.heal > 0:
			attacker.heal(result.heal)

		for field: FieldEntry in result.fields_for_target:
			target.field_container.add_field(field)

		for field: FieldEntry in result.fields_for_self:
			attacker.field_container.add_field(field)

		for field: FieldEntry in result.fields_for_global:
			global_fields.add_field(field)

		for field_id: String in result.fields_to_remove:
			target.field_container.remove_field(field_id)

		if result.terrain_to_create != "":
			var terrain_res := load("res://data/terrains/%s.tres" % result.terrain_to_create)
			if terrain_res is TerrainData:
				terrain_manager.set_terrain(terrain_res)

		_process_equip_triggers(attacker, EquipTrigger.TriggerEvent.ON_ATTACK, target)
		_process_equip_triggers(target, EquipTrigger.TriggerEvent.ON_HIT, attacker)

		if not target.is_alive:
			_process_equip_triggers(attacker, EquipTrigger.TriggerEvent.ON_KILL, target)

		unit_action.emit(attacker, skill, result)


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
