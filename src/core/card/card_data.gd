class_name CardData
extends Resource

@export var id: String
@export var display_name: String
@export var book_id: String
@export var rarity: int = 1
@export var element: String
@export var tags: Array[String] = []
@export var stages: Array[String] = []
@export var skills: Array[SkillData] = []
@export var base_hp: int = 100
@export var base_atk: int = 10
@export var base_def: int = 10
@export var base_spd: int = 100
