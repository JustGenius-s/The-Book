class_name PlayerData
extends Resource

@export var owned_card_ids: Array[String] = []
@export var currencies: Dictionary = { "gold": 0, "diamond": 0 }
@export var story_progress: Dictionary = {}
@export var autochess_rank: int = 0
@export var card_battle_rank: int = 0


func to_dict() -> Dictionary:
	return {
		"owned_card_ids": owned_card_ids,
		"currencies": currencies,
		"story_progress": story_progress,
		"autochess_rank": autochess_rank,
		"card_battle_rank": card_battle_rank,
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var pd := PlayerData.new()
	pd.owned_card_ids = data.get("owned_card_ids", [])
	pd.currencies = data.get("currencies", { "gold": 0, "diamond": 0 })
	pd.story_progress = data.get("story_progress", {})
	pd.autochess_rank = data.get("autochess_rank", 0)
	pd.card_battle_rank = data.get("card_battle_rank", 0)
	return pd
