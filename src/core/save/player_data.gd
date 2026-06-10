class_name PlayerData
extends Resource

@export var owned_card_ids: Array[String] = []
@export var card_battle_team: Array[String] = []
@export var currencies: Dictionary = { "gold": 0, "diamond": 0 }
@export var story_progress: Dictionary = {}
@export var autochess_rank: int = 0
@export var card_battle_rank: int = 0


func has_card(card_id: String) -> bool:
	return owned_card_ids.has(card_id)


func grant_card(card_id: String) -> void:
	if has_card(card_id):
		return
	owned_card_ids.append(card_id)
	EventBus.card_unlocked.emit(card_id)


func get_currency(type: String) -> int:
	return int(currencies.get(type, 0))


func add_currency(type: String, amount: int) -> void:
	currencies[type] = get_currency(type) + amount
	EventBus.currency_changed.emit(type, int(currencies[type]))


func to_dict() -> Dictionary:
	return {
		"owned_card_ids": owned_card_ids,
		"card_battle_team": card_battle_team,
		"currencies": currencies,
		"story_progress": story_progress,
		"autochess_rank": autochess_rank,
		"card_battle_rank": card_battle_rank,
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var pd := PlayerData.new()
	pd.owned_card_ids.assign(data.get("owned_card_ids", []))
	pd.card_battle_team.assign(data.get("card_battle_team", []))
	pd.currencies = data.get("currencies", { "gold": 0, "diamond": 0 })
	pd.story_progress = data.get("story_progress", {})
	pd.autochess_rank = int(data.get("autochess_rank", 0))
	pd.card_battle_rank = int(data.get("card_battle_rank", 0))
	return pd
