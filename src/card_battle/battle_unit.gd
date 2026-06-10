class_name BattleUnit
extends Node2D

signal died(unit: BattleUnit)
signal hp_changed(unit: BattleUnit, old_hp: int, new_hp: int)
signal form_changed(unit: BattleUnit, old_card: CardData, new_card: CardData)

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


## 形态切换：换卡并按策略过渡 HP/技能冷却/字段，装备按新形态重新匹配。
## 调用方（TraitProcessor）负责校验 character_id 一致。
func switch_form(
	new_card: CardData,
	hp_policy: TraitEffect.HpPolicy = TraitEffect.HpPolicy.KEEP_PERCENT,
	cooldown_policy: TraitEffect.CooldownPolicy = TraitEffect.CooldownPolicy.INHERIT_BY_ID,
	field_policy: TraitEffect.FieldPolicy = TraitEffect.FieldPolicy.KEEP_ALL,
) -> void:
	if not is_alive or new_card == null or new_card == card:
		return

	var old_card := card
	var hp_ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	var old_cooldowns := current_cooldowns

	card = new_card
	max_hp = _calc_base_stat("hp")

	match hp_policy:
		TraitEffect.HpPolicy.KEEP_PERCENT:
			current_hp = clampi(ceili(float(max_hp) * hp_ratio), 1, max_hp)
		TraitEffect.HpPolicy.KEEP_VALUE:
			current_hp = clampi(current_hp, 1, max_hp)
		TraitEffect.HpPolicy.FULL_RESTORE:
			current_hp = max_hp

	current_cooldowns = {}
	for skill: SkillData in card.skills:
		match cooldown_policy:
			TraitEffect.CooldownPolicy.INHERIT_BY_ID:
				current_cooldowns[skill.id] = old_cooldowns.get(skill.id, 0)
			TraitEffect.CooldownPolicy.RESET_ALL:
				current_cooldowns[skill.id] = 0
			TraitEffect.CooldownPolicy.ALL_ON_COOLDOWN:
				# 各技能进入自身冷却时长（普攻 cooldown=0 不受影响）
				current_cooldowns[skill.id] = skill.cooldown

	match field_policy:
		TraitEffect.FieldPolicy.CLEAR_DEBUFFS:
			_clear_fields_of_type(FieldEntry.FieldType.DEBUFF)
		TraitEffect.FieldPolicy.CLEAR_BUFFS:
			_clear_fields_of_type(FieldEntry.FieldType.BUFF)
		TraitEffect.FieldPolicy.CLEAR_ALL:
			field_container.clear_all()
		_:
			pass

	# 装备按新形态重新匹配（羁绊角色可能变化）
	field_container.clear_by_source(FieldEntry.FieldSource.EQUIPMENT)
	_apply_equipment_innate_fields()

	# diff 为 0 不会触发伤害/治疗弹窗，仅让 UI 刷新血量显示
	hp_changed.emit(self, current_hp, current_hp)
	form_changed.emit(self, old_card, card)


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


func _clear_fields_of_type(type: FieldEntry.FieldType) -> void:
	for entry: FieldEntry in field_container.get_fields_by_type(type):
		field_container.remove_field(entry.id)


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

		# 羁绊：若装备的 synergy_character 与当前卡牌匹配，注入 synergy_fields
		if equip.synergy_character != "" and equip.synergy_character == card.id:
			for field: FieldEntry in equip.synergy_fields:
				var copy := field.duplicate_entry()
				copy.source = FieldEntry.FieldSource.EQUIPMENT
				copy.duration = -1
				field_container.add_field(copy)
