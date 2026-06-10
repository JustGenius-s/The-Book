class_name TraitProcessor
extends RefCounted

## 特性触发管线：统一评估卡牌（card.traits）与装备（equip.traits）上的 TraitData。
## - 状态型（PERSISTENT）：条件满足期间生效，字段以 TRAIT 来源施加并记录，
##   条件不再满足（含持有者死亡、场地变化、关键队友阵亡）时按记录精确撤销；
##   含 switch_to_form 的状态型特性为双向切换——激活时切换形态，撤销时切回原形态。
## - 事件型（TRIGGERED）：在指定时机评估条件，满足则一次性施加效果（切换为单向）。
##
## 防震荡：单轮 evaluate_all 内每个单位维护 visited_forms，链式切换（A→B→C）合法，
## 但回访本轮已经历的形态（A→B→A）会被跳过；跨轮往返不受限制。

signal trait_activated(unit: BattleUnit, trait_data: TraitData)
signal trait_deactivated(unit: BattleUnit, trait_data: TraitData)

const CARDS_DIR := "res://data/cards"
## 单位单轮重评估次数上限，防止数据配置出极端切换环
const MAX_FORM_EVALS := 8

var _ally_units: Array[BattleUnit]
var _enemy_units: Array[BattleUnit]
var _global_fields: FieldContainer
var _terrain_manager: TerrainManager
## "unit_instance_id:trait_id" -> {
##   unit, trait, records: Array[{container, field_id}],
##   previous_form: String, switched_to: String, switch_effect: TraitEffect,
## }
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
	_cleanup_orphans()
	for unit: BattleUnit in _ally_units + _enemy_units:
		_evaluate_unit(unit)


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
			# 事件型为一次性效果：切换单向、字段记录即弃
			var entry := {"unit": unit, "trait": trait_data, "records": [] as Array[Dictionary]}
			var visited := {unit.card.id: true}
			_apply_effects(unit, trait_data, visited, entry)
			trait_activated.emit(unit, trait_data)


## 单轮内反复评估单位直到无形态变化（链式切换），visited_forms 防回访
func _evaluate_unit(unit: BattleUnit) -> void:
	var visited_forms := {unit.card.id: true}
	for _i in MAX_FORM_EVALS:
		if not _evaluate_unit_once(unit, visited_forms):
			return


## 返回是否发生了形态切换（发生则需重新收集特性再评估一轮）
func _evaluate_unit_once(unit: BattleUnit, visited_forms: Dictionary) -> bool:
	for trait_data: TraitData in _effective_traits(unit):
		if trait_data.kind != TraitData.TraitKind.PERSISTENT:
			continue

		var key := _key(unit, trait_data)
		var met := unit.is_alive and _conditions_met(unit, trait_data)

		if met and not _active.has(key):
			var entry := {
				"unit": unit,
				"trait": trait_data,
				"records": [] as Array[Dictionary],
				"previous_form": "",
				"switched_to": "",
				"switch_effect": null,
			}
			_active[key] = entry
			var switched := _apply_effects(unit, trait_data, visited_forms, entry)
			trait_activated.emit(unit, trait_data)
			if switched:
				return true
		elif not met and _active.has(key):
			var entry: Dictionary = _active[key]
			_revoke(entry["records"])
			_active.erase(key)
			trait_deactivated.emit(unit, trait_data)
			if _revert_form(unit, entry, visited_forms):
				return true

	return false


## 状态型切换的回退：仅当单位仍处于该特性切到的形态时切回原形态
func _revert_form(unit: BattleUnit, entry: Dictionary, visited_forms: Dictionary) -> bool:
	var switched_to: String = entry.get("switched_to", "")
	if switched_to == "" or unit.card.id != switched_to:
		return false

	var prev_id: String = entry["previous_form"]
	if visited_forms.has(prev_id):
		return false

	var prev_card := _load_form_card(prev_id)
	if prev_card == null:
		return false

	var effect: TraitEffect = entry["switch_effect"]
	unit.switch_form(prev_card, effect.hp_policy, effect.cooldown_policy, effect.field_policy)
	visited_forms[prev_id] = true
	return true


## 清理孤儿激活记录：特性已不属于该单位（如形态切换后旧形态的其它特性）时撤销其字段。
## 例外：执行了形态切换且单位仍处于目标形态的特性视为"随形态保留"，
## 以便条件失效时能撤销并切回原形态。
func _cleanup_orphans() -> void:
	var to_remove: Array[String] = []
	for key: String in _active:
		var entry: Dictionary = _active[key]
		var unit: BattleUnit = entry["unit"]
		if _effective_traits(unit).has(entry["trait"]):
			continue
		_revoke(entry["records"])
		to_remove.append(key)
		trait_deactivated.emit(unit, entry["trait"])
	for key: String in to_remove:
		_active.erase(key)


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


## 评估用的有效特性集合 = 当前形态特性 + "随形态保留"的切换特性
## （切换特性通常配在原形态卡上，切换后仍需追踪其条件以便回退）
func _effective_traits(unit: BattleUnit) -> Array[TraitData]:
	var result := collect_traits(unit)
	for entry: Dictionary in _active.values():
		if entry["unit"] != unit:
			continue
		if str(entry.get("switched_to", "")) != unit.card.id:
			continue
		if not result.has(entry["trait"]):
			result.append(entry["trait"])
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


## 施加效果：先处理形态切换（避免切换的字段清理策略误删本特性刚施加的字段），
## 再施加/移除字段并写入 entry["records"]。返回是否发生了形态切换。
func _apply_effects(
	unit: BattleUnit,
	trait_data: TraitData,
	visited_forms: Dictionary,
	entry: Dictionary,
) -> bool:
	var switched := false

	for effect: TraitEffect in trait_data.effects:
		if effect.switch_to_form == "" or switched:
			continue
		var target_card := _resolve_form_card(unit, effect.switch_to_form)
		if target_card == null or visited_forms.has(target_card.id):
			continue
		entry["previous_form"] = unit.card.id
		entry["switched_to"] = target_card.id
		entry["switch_effect"] = effect
		unit.switch_form(target_card, effect.hp_policy, effect.cooldown_policy, effect.field_policy)
		visited_forms[target_card.id] = true
		switched = true

	var records: Array[Dictionary] = entry["records"]
	for effect: TraitEffect in trait_data.effects:
		for container: FieldContainer in _target_containers(unit, effect.target):
			for field: FieldEntry in effect.fields_to_apply:
				var copy := field.duplicate_entry()
				copy.source = FieldEntry.FieldSource.TRAIT
				container.add_field(copy)
				records.append({"container": container, "field_id": copy.id})

			for field_id: String in effect.fields_to_remove:
				container.remove_field(field_id)

	return switched


## 解析切换目标形态卡，并校验与当前卡同属一个角色（character_id 一致且非空）
func _resolve_form_card(unit: BattleUnit, form_id: String) -> CardData:
	if form_id == unit.card.id:
		return null

	var target := _load_form_card(form_id)
	if target == null:
		return null

	if unit.card.character_id == "" or target.character_id != unit.card.character_id:
		push_warning("TraitProcessor: 形态切换要求同 character_id（%s → %s），已跳过" % [
			unit.card.id, form_id,
		])
		return null

	return target


func _load_form_card(form_id: String) -> CardData:
	var path := "%s/%s.tres" % [CARDS_DIR, form_id]
	if not ResourceLoader.exists(path):
		push_warning("TraitProcessor: 形态卡不存在 " + form_id)
		return null
	return load(path) as CardData


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
