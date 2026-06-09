class_name FieldResolver
extends RefCounted

## Collects effect modifiers from unit-level and global-level field containers
## and resolves them into final stat adjustments and active effects.


static func resolve_stat(
	stat_name: String,
	base_value: int,
	unit_fields: FieldContainer,
	global_fields: FieldContainer,
) -> int:
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0

	var all_fields: Array[FieldEntry] = []
	all_fields.append_array(unit_fields.get_all_fields())
	all_fields.append_array(global_fields.get_all_fields())

	var flat_key := stat_name + "_flat"
	var percent_key := stat_name + "_percent"

	for entry: FieldEntry in all_fields:
		var multiplier := float(entry.current_stacks)
		if entry.effects.has(flat_key):
			flat_bonus += float(entry.effects[flat_key]) * multiplier
		if entry.effects.has(percent_key):
			percent_bonus += float(entry.effects[percent_key]) * multiplier

	var result := float(base_value)
	result += flat_bonus
	result *= (1.0 + percent_bonus)
	return int(result)


static func collect_dot_damage(
	unit_fields: FieldContainer,
	global_fields: FieldContainer,
) -> int:
	var total: float = 0.0
	var all_fields: Array[FieldEntry] = []
	all_fields.append_array(unit_fields.get_all_fields())
	all_fields.append_array(global_fields.get_all_fields())

	for entry: FieldEntry in all_fields:
		if entry.effects.has("dot_damage"):
			total += float(entry.effects["dot_damage"]) * float(entry.current_stacks)

	return int(total)


static func collect_heal_per_turn(
	unit_fields: FieldContainer,
	global_fields: FieldContainer,
) -> int:
	var total: float = 0.0
	var all_fields: Array[FieldEntry] = []
	all_fields.append_array(unit_fields.get_all_fields())
	all_fields.append_array(global_fields.get_all_fields())

	for entry: FieldEntry in all_fields:
		if entry.effects.has("heal_per_turn"):
			total += float(entry.effects["heal_per_turn"]) * float(entry.current_stacks)

	return int(total)


static func has_effect(
	effect_key: String,
	unit_fields: FieldContainer,
	global_fields: FieldContainer,
) -> bool:
	for entry: FieldEntry in unit_fields.get_all_fields():
		if entry.effects.has(effect_key):
			return true
	for entry: FieldEntry in global_fields.get_all_fields():
		if entry.effects.has(effect_key):
			return true
	return false


static func get_effect_value(
	effect_key: String,
	unit_fields: FieldContainer,
	global_fields: FieldContainer,
	default: float = 0.0,
) -> float:
	var total := 0.0
	var found := false
	var all_fields: Array[FieldEntry] = []
	all_fields.append_array(unit_fields.get_all_fields())
	all_fields.append_array(global_fields.get_all_fields())

	for entry: FieldEntry in all_fields:
		if entry.effects.has(effect_key):
			total += float(entry.effects[effect_key]) * float(entry.current_stacks)
			found = true

	return total if found else default
