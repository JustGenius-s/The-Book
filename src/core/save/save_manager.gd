extends Node

const SAVE_PATH := "user://saves/player.json"

## 新档默认发放的卡牌，同时作为默认编队
const STARTER_CARDS: Array[String] = ["pangu", "nuwa", "yuhuangdadi"]
## 旧版初始卡牌，用于存档迁移
const OLD_STARTER_CARDS: Array[String] = ["wukong_king", "wukong_monk", "wukong_pilgrim", "wukong_stone"]
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
		_grant_starters()
	else:
		_migrate_if_needed()
	_unlock_all_cards()
	if player.card_battle_team.is_empty():
		player.card_battle_team.assign(STARTER_CARDS)
	save_game()


func _unlock_all_cards() -> void:
	for card: CardData in CardLibrary.get_all_cards():
		if not player.has_card(card.id):
			player.grant_card(card.id)


func _grant_starters() -> void:
	for card: CardData in CardLibrary.get_all_cards():
		player.grant_card(card.id)
	for equip_id: String in STARTER_EQUIPS:
		player.grant_equip(equip_id)
	player.add_currency("gold", STARTER_GOLD)


func _migrate_if_needed() -> void:
	# 迁移旧悟空初始卡牌 → 新角色
	for old_id in OLD_STARTER_CARDS:
		if not player.has_card(old_id):
			return  # 玩家已经扩展了卡牌池，无需迁移
	# 全部旧初始卡牌都在 → 执行迁移
	for old_id in OLD_STARTER_CARDS:
		player.owned_card_ids.erase(old_id)
	for card_id: String in STARTER_CARDS:
		player.grant_card(card_id)
	player.card_battle_team.assign(STARTER_CARDS)


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
