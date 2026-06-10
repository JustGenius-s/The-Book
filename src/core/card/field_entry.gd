class_name FieldEntry
extends Resource

enum FieldType { BUFF, DEBUFF, SPECIAL }
enum FieldSource { SKILL, TERRAIN, EQUIPMENT }

@export var id: String
@export var display_name: String
@export var type: FieldType = FieldType.BUFF
@export var source: FieldSource = FieldSource.SKILL
@export var duration: int = -1
@export var max_stacks: int = 1
@export var current_stacks: int = 1
@export var effects: Dictionary = {}


func is_permanent() -> bool:
	return duration == -1


func is_expired() -> bool:
	return duration == 0


func duplicate_entry() -> FieldEntry:
	var copy := FieldEntry.new()
	copy.id = id
	copy.display_name = display_name
	copy.type = type
	copy.source = source
	copy.duration = duration
	copy.max_stacks = max_stacks
	copy.current_stacks = current_stacks
	copy.effects = effects.duplicate(true)
	return copy
