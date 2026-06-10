extends Node

const SAVE_PATH := "user://saves/player.json"

## 新档默认发放的卡牌，同时作为默认编队
const STARTER_CARDS: Array[String] = ["wukong_king", "wukong_monk", "wukong_stone"]
## 新档默认发放的装备
const STARTER_EQUIPS: Array[String] = ["1_ruyi_bang", "5_suozijia"]
## 新档初始金币（够进商店买件入门装备）
const STARTER_GOLD := 200

var player: PlayerData = PlayerData.new()


func _ready() -> void:
	load_game()
	_ensure_starter_content()


func _ensure_starter_content() -> void:
	var is_new := player.owned_card_ids.is_empty()
	if is_new:
		for card_id: String in STARTER_CARDS:
			player.grant_card(card_id)
	if player.card_battle_team.is_empty():
		player.card_battle_team.assign(STARTER_CARDS)
	if is_new and player.owned_equipment_ids.is_empty():
		for equip_id: String in STARTER_EQUIPS:
			player.grant_equip(equip_id)
		player.add_currency("gold", STARTER_GOLD)
	save_game()


func save_game() -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing")
		return

	var json_str := JSON.stringify(player.to_dict(), "\t")
	file.store_string(json_str)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		player = PlayerData.new()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file for reading")
		player = PlayerData.new()
		return

	var json_str := file.get_as_text()
	var data = JSON.parse_string(json_str)
	if data is Dictionary:
		player = PlayerData.from_dict(data)
	else:
		push_error("SaveManager: invalid save data")
		player = PlayerData.new()
