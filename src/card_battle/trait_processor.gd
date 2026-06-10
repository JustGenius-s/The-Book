class_name TraitProcessor
extends RefCounted

## 特性触发管线：统一评估卡牌（card.traits）与装备（equip.traits）上的 TraitData。
## - 状态型（PERSISTENT）：条件满足期间生效，字段以 TRAIT 来源施加并记录，
##   条件不再满足（含持有者死亡、场地变化、关键队友阵亡）时按记录精确撤销。
## - 事件型（TRIGGERED）：在指定时机评估条件，满足则一次性施加效果。

signal trait_activated(unit: BattleUnit, trait_data: TraitData)
signal trait_deactivated(unit: BattleUnit, trait_data: TraitData)

var _ally_units: Array[BattleUnit]
var _enemy_units: Array[BattleUnit]
var _global_fields: FieldContainer
var _terrain_manager: TerrainManager
## "unit_instance_id:trait_id" -> {unit, trait, records: Array[{container, field_id}]}
var _active: Dictionary = {}


func _init(
	ally_units: Array[BattleUnit],
	enemy_units: Array[BattleUnit],
	global_fields: FieldContainer,
	terrain_manager: TerrainManager,
) -> void:
	_ally_units = ally_units
	_enemy_units = enemy_units
	_global_fields = global_fields
	_terrain_manager = terrain_manager


## 重评估所有单位的状态型特性，在战斗开始、场地变化、行动结算后、回合结束时调用
func evaluate_all() -> void:
	for unit: BattleUnit in _ally_units + _enemy_units:
		for trait_data: TraitData in collect_traits(unit):
			if trait_data.kind != TraitData.TraitKind.PERSISTENT:
				continue

			var key := _key(unit, trait_data)
			var met := unit.is_alive and _conditions_met(unit, trait_data)

			if met and not _active.has(key):
				_active[key] = {
					"unit": unit,
					"trait": trait_data,
					"records": _apply_effects(unit, trait_data),
				}
				trait_activated.emit(unit, trait_data)
			elif not met and _active.has(key):
				_revoke(_active[key]["records"])
				_active.erase(key)
				trait_deactivated.emit(unit, trait_data)


## 评估某单位在指定时机的事件型特性
func process_event(event: TraitData.TriggerEvent, unit: BattleUnit) -> void:
	if not unit.is_alive:
		return
	for trait_data: TraitData in collect_traits(unit):
		if trait_data.kind != TraitData.TraitKind.TRIGGERED:
			continue
		if trait_data.trigger != event:
			continue
		if _conditions_met(unit, trait_data):
			_apply_effects(unit, trait_data)
			trait_activated.emit(unit, trait_data)


## 当前已激活的状态型特性列表：[{unit: BattleUnit, trait: TraitData}]
## 供 UI 在战斗开始后补记开场即激活的特性
func get_active() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _active.values():
		result.append({"unit": entry["unit"], "trait": entry["trait"]})
	return result


## 单位的全部特性来源：卡牌特性 + 已穿戴装备的特性
static func collect_traits(unit: BattleUnit) -> Array[TraitData]:
	var result: Array[TraitData] = []
	result.append_array(unit.card.traits)
	for equip: EquipmentData in unit.equipment:
		result.append_array(equip.traits)
	return result


func _conditions_met(unit: BattleUnit, trait_data: TraitData) -> bool:
	for cond: TraitCondition in trait_data.conditions:
		var met := _check_condition(unit, cond)
		if cond.negate:
			met = not met
		if not met:
			return false
	return true


func _check_condition(unit: BattleUnit, cond: TraitCondition) -> bool:
	match cond.type:
		TraitCondition.ConditionType.GLOBAL_HAS_FIELD:
			return _global_fields.has_field(cond.value)
		TraitCondition.ConditionType.TERRAIN_IS:
			var terrain := _terrain_manager.get_current_terrain()
			return terrain != null and terrain.id == cond.value
		TraitCondition.ConditionType.SELF_HAS_FIELD:
			return unit.field_container.has_field(cond.value)
		TraitCondition.ConditionType.SELF_IS_CARD:
			return unit.card.id == cond.value
		TraitCondition.ConditionType.SELF_HAS_EQUIPMENT:
			for equip: EquipmentData in unit.equipment:
				if equip.id == cond.value:
					return true
			return false
		TraitCondition.ConditionType.ALLY_ON_FIELD:
			for ally: BattleUnit in _side_of(unit):
				if ally != unit and ally.is_alive and ally.card.id == cond.value:
					return true
			return false
		TraitCondition.ConditionType.ENEMY_ON_FIELD:
			for enemy: BattleUnit in _opposite_side_of(unit):
				if enemy.is_alive and enemy.card.id == cond.value:
					return true
			return false
	return false


## 施加效果并返回施加记录（用于状态型撤销）
func _apply_effects(unit: BattleUnit, trait_data: TraitData) -> Array[Dictionary]:
	var records: Array[Dictionary] = []

	for effect: TraitEffect in trait_data.effects:
		for container: FieldContainer in _target_containers(unit, effect.target):
			for field: FieldEntry in effect.fields_to_apply:
				var copy := field.duplicate_entry()
				copy.source = FieldEntry.FieldSource.TRAIT
				container.add_field(copy)
				records.append({"container": container, "field_id": copy.id})

			for field_id: String in effect.fields_to_remove:
				container.remove_field(field_id)

	return records


func _revoke(records: Array[Dictionary]) -> void:
	for record: Dictionary in records:
		var container: FieldContainer = record["container"]
		container.remove_field(record["field_id"])


func _target_containers(unit: BattleUnit, target: TraitEffect.EffectTarget) -> Array[FieldContainer]:
	var result: Array[FieldContainer] = []
	match target:
		TraitEffect.EffectTarget.SELF:
			result.append(unit.field_container)
		TraitEffect.EffectTarget.ALL_ALLIES:
			for ally: BattleUnit in _side_of(unit):
				if ally.is_alive:
					result.append(ally.field_container)
		TraitEffect.EffectTarget.ALL_ENEMIES:
			for enemy: BattleUnit in _opposite_side_of(unit):
				if enemy.is_alive:
					result.append(enemy.field_container)
		TraitEffect.EffectTarget.GLOBAL:
			result.append(_global_fields)
	return result


func _side_of(unit: BattleUnit) -> Array[BattleUnit]:
	return _ally_units if _ally_units.has(unit) else _enemy_units


func _opposite_side_of(unit: BattleUnit) -> Array[BattleUnit]:
	return _enemy_units if _ally_units.has(unit) else _ally_units


func _key(unit: BattleUnit, trait_data: TraitData) -> String:
	return "%d:%s" % [unit.get_instance_id(), trait_data.id]
