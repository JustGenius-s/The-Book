class_name SkillExecutor
extends RefCounted

## Executes a skill: calculates damage, applies fields, checks conditions.
## This is a stateless utility — all state is passed in via parameters.


static func execute(
	skill: SkillData,
	attacker_atk: int,
	attacker_fields: FieldContainer,
	target_fields: FieldContainer,
	global_fields: FieldContainer,
) -> SkillResult:
	var result := SkillResult.new()

	# --- Damage calculation ---
	if skill.damage_multiplier > 0.0:
		var multiplier := skill.damage_multiplier
		multiplier += _evaluate_condition_bonus(skill, target_fields, global_fields)

		var damage_boost := FieldResolver.get_effect_value("damage_bonus_percent", attacker_fields, global_fields)
		var damage_reduction := FieldResolver.get_effect_value("damage_reduction_percent", target_fields, global_fields)

		var raw_damage := float(attacker_atk) * multiplier
		raw_damage *= (1.0 + damage_boost)
		raw_damage *= maxf(0.0, 1.0 - damage_reduction)
		result.damage = int(raw_damage)

	# --- Heal calculation ---
	if skill.heal_multiplier > 0.0:
		result.heal = int(float(attacker_atk) * skill.heal_multiplier)

	# --- Apply fields to target ---
	for field: FieldEntry in skill.fields_to_apply:
		var copy := field.duplicate_entry()
		copy.source = FieldEntry.FieldSource.SKILL
		result.fields_for_target.append(copy)

	# --- Apply fields to self ---
	for field: FieldEntry in skill.fields_to_self:
		var copy := field.duplicate_entry()
		copy.source = FieldEntry.FieldSource.SKILL
		result.fields_for_self.append(copy)

	# --- Apply fields to global ---
	for field: FieldEntry in skill.fields_to_global:
		var copy := field.duplicate_entry()
		copy.source = FieldEntry.FieldSource.SKILL
		result.fields_for_global.append(copy)

	# --- Remove fields from target ---
	result.fields_to_remove = skill.fields_to_remove.duplicate()

	# --- Terrain change ---
	result.terrain_to_create = skill.terrain_to_create

	return result


static func _evaluate_condition_bonus(
	skill: SkillData,
	target_fields: FieldContainer,
	global_fields: FieldContainer,
) -> float:
	if skill.condition == SkillData.TriggerCondition.NONE:
		return 0.0

	var met := false
	match skill.condition:
		SkillData.TriggerCondition.TARGET_HAS_FIELD:
			met = target_fields.has_field(skill.condition_field_id)
		SkillData.TriggerCondition.TARGET_MISSING_FIELD:
			met = not target_fields.has_field(skill.condition_field_id)
		SkillData.TriggerCondition.GLOBAL_HAS_FIELD:
			met = global_fields.has_field(skill.condition_field_id)

	return skill.conditional_bonus_multiplier if met else 0.0


class SkillResult extends RefCounted:
	var damage: int = 0
	var heal: int = 0
	var fields_for_target: Array[FieldEntry] = []
	var fields_for_self: Array[FieldEntry] = []
	var fields_for_global: Array[FieldEntry] = []
	var fields_to_remove: Array[String] = []
	var terrain_to_create: String = ""
