class_name PlayerData
extends Resource

@export var owned_card_ids: Array[String] = []
@export var card_battle_team: Array[String] = []
## 已拥有的装备 id 集合（每件唯一，不可堆叠）
@export var owned_equipment_ids: Array[String] = []
## 卡牌 id → {slot: equipment_id}，一件装备只能穿给一张卡牌
@export var card_equipment: Dictionary = {}
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


# ---------- 装备 ----------

func has_equip(equip_id: String) -> bool:
	return owned_equipment_ids.has(equip_id)


func grant_equip(equip_id: String) -> void:
	if has_equip(equip_id):
		return
	owned_equipment_ids.append(equip_id)


func equip_card(card_id: String, equip_id: String) -> void:
	var equip := EquipmentLibrary.get_equip(equip_id)
	if equip == null:
		return
	for cid: String in card_equipment:
		for slot: String in card_equipment[cid]:
			if card_equipment[cid][slot] == equip_id and cid != card_id:
				card_equipment[cid].erase(slot)
				if card_equipment[cid].is_empty():
					card_equipment.erase(cid)
				break

	if not card_equipment.has(card_id):
		card_equipment[card_id] = {}
	card_equipment[card_id][equip.slot] = equip_id


func unequip_card(card_id: String, slot: String) -> void:
	if not card_equipment.has(card_id):
		return
	card_equipment[card_id].erase(slot)
	if card_equipment[card_id].is_empty():
		card_equipment.erase(card_id)


func get_card_equips(card_id: String) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	if not card_equipment.has(card_id):
		return result
	for slot: String in card_equipment[card_id]:
		var equip := EquipmentLibrary.get_equip(card_equipment[card_id][slot])
		if equip:
			result.append(equip)
	return result


# ---------- 货币 ----------

func add_currency(type: String, amount: int) -> void:
	currencies[type] = get_currency(type) + amount
	EventBus.currency_changed.emit(type, int(currencies[type]))


func to_dict() -> Dictionary:
	return {
		"owned_card_ids": owned_card_ids,
		"card_battle_team": card_battle_team,
		"owned_equipment_ids": owned_equipment_ids,
		"card_equipment": card_equipment,
		"currencies": currencies,
		"story_progress": story_progress,
		"autochess_rank": autochess_rank,
		"card_battle_rank": card_battle_rank,
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var pd := PlayerData.new()
	pd.owned_card_ids.assign(data.get("owned_card_ids", []))
	pd.card_battle_team.assign(data.get("card_battle_team", []))
	pd.owned_equipment_ids.assign(data.get("owned_equipment_ids", []))
	pd.card_equipment = data.get("card_equipment", {})
	pd.currencies = data.get("currencies", { "gold": 0, "diamond": 0 })
	pd.story_progress = data.get("story_progress", {})
	pd.autochess_rank = int(data.get("autochess_rank", 0))
	pd.card_battle_rank = int(data.get("card_battle_rank", 0))
	return pd
