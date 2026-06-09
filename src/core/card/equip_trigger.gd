class_name EquipTrigger
extends Resource

enum TriggerEvent {
	ON_ATTACK,
	ON_HIT,
	ON_TURN_START,
	ON_TURN_END,
	ON_KILL,
	ON_ALLY_DEATH,
}

@export var event: TriggerEvent = TriggerEvent.ON_ATTACK
@export var chance: float = 1.0
@export var field_to_apply: FieldEntry
@export var apply_to_self: bool = false
