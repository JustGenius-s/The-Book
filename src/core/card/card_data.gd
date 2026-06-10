class_name CardData
extends Resource

@export var id: String
@export var display_name: String
@export var book_id: String
@export var rarity: int = 1
@export var tags: Array[String] = []
## 所属角色 id，同 character_id 的卡互为形态（可在战斗中切换）；空 = 无形态系统的独立卡
@export var character_id: String = ""

@export_group("Stats")
@export var base_hp: int = 100
@export var base_atk: int = 10
@export var base_def: int = 10
@export var base_spd: int = 100

@export_group("Skills")
@export var skills: Array[SkillData] = []

@export_group("Traits")
@export var traits: Array[TraitData] = []

@export_group("Equipment Slots")
@export var equipment_slots: Array[String] = ["weapon", "armor", "accessory"]

@export_group("Visuals")
@export var portrait: Texture2D
@export var stages: Array[String] = []
@export var live2d_model_path: String = ""
