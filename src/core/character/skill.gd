class_name SkillData
extends Resource

enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, RANDOM_ENEMY }
enum TriggerCondition { NONE, TARGET_HAS_FIELD, TARGET_MISSING_FIELD, GLOBAL_HAS_FIELD }

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var target: TargetType = TargetType.SINGLE_ENEMY
@export var cooldown: int = 0
@export var damage_multiplier: float = 1.0
@export var heal_multiplier: float = 0.0

@export_group("Field Interactions")
@export var fields_to_apply: Array[FieldEntry] = []
@export var fields_to_self: Array[FieldEntry] = []
@export var fields_to_global: Array[FieldEntry] = []
@export var fields_to_remove: Array[String] = []

@export_group("Terrain")
@export var terrain_to_create: String = ""

@export_group("Conditions")
@export var condition: TriggerCondition = TriggerCondition.NONE
@export var condition_field_id: String = ""
@export var conditional_bonus_multiplier: float = 0.0

@export_group("Description")
@export_multiline var description: String
