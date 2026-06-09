class_name EquipmentData
extends Resource

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var slot: String = "weapon"
@export var stat_bonuses: Dictionary = {}
@export var innate_fields: Array[FieldEntry] = []
@export var passive_triggers: Array[EquipTrigger] = []
@export_multiline var description: String
