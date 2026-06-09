class_name BattleUnit
extends Node2D

signal died(unit: BattleUnit)
signal hp_changed(unit: BattleUnit, old_hp: int, new_hp: int)

var card: CardData
var equipment: Array[EquipmentData] = []
var field_container: FieldContainer = FieldContainer.new()
var global_fields: FieldContainer

var max_hp: int
var current_hp: int
var current_cooldowns: Dictionary = {}
var is_alive: bool = true


func setup(card_data: CardData, equips: Array[EquipmentData], global: FieldContainer) -> void:
	card = card_data
	global_fields = global
	equipment = equips

	max_hp = _calc_base_stat("hp")
	current_hp = max_hp

	for skill: SkillData in card.skills:
		current_cooldowns[skill.id] = 0

	_apply_equipment_innate_fields()


func get_final_stat(stat_name: String) -> int:
	var base := _calc_base_stat(stat_name)
	return FieldResolver.resolve_stat(stat_name, base, field_container, global_fields)


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	var shield := FieldResolver.get_effect_value("shield", field_container, global_fields)
	var actual := amount

	if shield > 0.0:
		var absorbed := mini(actual, int(shield))
		actual -= absorbed
		# Reduce shield stacks proportionally — simplified: remove shield if depleted
		if actual <= 0:
			return

	var old_hp := current_hp
	current_hp = maxi(0, current_hp - actual)
	hp_changed.emit(self, old_hp, current_hp)

	if current_hp <= 0:
		is_alive = false
		died.emit(self)


func heal(amount: int) -> void:
	if not is_alive:
		return
	var old_hp := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(self, old_hp, current_hp)


func process_turn_start() -> void:
	var dot := FieldResolver.collect_dot_damage(field_container, global_fields)
	if dot > 0:
		take_damage(dot)

	var hot := FieldResolver.collect_heal_per_turn(field_container, global_fields)
	if hot > 0:
		heal(hot)


func process_turn_end() -> void:
	field_container.tick()

	for skill_id: String in current_cooldowns:
		if current_cooldowns[skill_id] > 0:
			current_cooldowns[skill_id] -= 1


func can_use_skill(skill: SkillData) -> bool:
	return current_cooldowns.get(skill.id, 0) <= 0


func put_skill_on_cooldown(skill: SkillData) -> void:
	current_cooldowns[skill.id] = skill.cooldown


func check_equip_triggers(event: EquipTrigger.TriggerEvent) -> Array[EquipTrigger]:
	var triggered: Array[EquipTrigger] = []
	for equip: EquipmentData in equipment:
		for trigger: EquipTrigger in equip.passive_triggers:
			if trigger.event == event and randf() <= trigger.chance:
				triggered.append(trigger)
	return triggered


func _calc_base_stat(stat_name: String) -> int:
	var base: int = 0
	match stat_name:
		"hp": base = card.base_hp
		"atk": base = card.base_atk
		"def": base = card.base_def
		"spd": base = card.base_spd

	for equip: EquipmentData in equipment:
		base += int(equip.stat_bonuses.get(stat_name, 0))

	return base


func _apply_equipment_innate_fields() -> void:
	for equip: EquipmentData in equipment:
		for field: FieldEntry in equip.innate_fields:
			var copy := field.duplicate_entry()
			copy.source = FieldEntry.FieldSource.EQUIPMENT
			copy.duration = -1
			field_container.add_field(copy)
