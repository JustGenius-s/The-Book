class_name SkillData
extends Resource

enum SkillType { PASSIVE, ACTIVE, ULTIMATE }
enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES }

@export var id: String
@export var display_name: String
@export var type: SkillType = SkillType.ACTIVE
@export var target: TargetType = TargetType.SINGLE_ENEMY
@export var cooldown: int = 0
@export var damage_multiplier: float = 1.0
@export_multiline var description: String
