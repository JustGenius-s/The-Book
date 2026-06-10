class_name EncounterData
extends Resource

## 一场 PVE 遭遇战的配置：敌方阵容、初始地形与奖励。

@export var id: String
@export var display_name: String
@export var enemy_cards: Array[CardData] = []
@export var terrain: TerrainData
@export var reward_gold: int = 0
