class_name EquipmentData
extends Resource

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var slot: String = "weapon"
@export var price: int = 100
@export var stat_bonuses: Dictionary = {}
@export var innate_fields: Array[FieldEntry] = []
@export var passive_triggers: Array[EquipTrigger] = []
## 装备特性：与卡牌特性共用 TraitData 结构，持有者为穿戴该装备的单位
@export var traits: Array[TraitData] = []
## 羁绊角色 card_id：穿戴在该角色身上时 synergy_fields 额外生效
@export var synergy_character: String = ""
@export var synergy_fields: Array[FieldEntry] = []
@export_multiline var description: String
