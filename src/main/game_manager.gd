extends Node

enum GameMode { NONE, STORY, AUTOCHESS, CARD_BATTLE }

const DEFAULT_LOBBY_BG := "res://assets/ui/main_menu_bg_default.png"

var current_mode: GameMode = GameMode.NONE
var _lobby_bg_path: String = DEFAULT_LOBBY_BG


func set_lobby_bg(path: String) -> void:
	_lobby_bg_path = path


func get_lobby_bg_path() -> String:
	return _lobby_bg_path


func enter_story_mode() -> void:
	current_mode = GameMode.STORY
	SceneManager.change_scene("res://src/story/story_mode.tscn")


func enter_autochess_mode() -> void:
	current_mode = GameMode.AUTOCHESS
	SceneManager.change_scene("res://src/autochess/autochess_mode.tscn")


func enter_card_battle_mode() -> void:
	current_mode = GameMode.CARD_BATTLE
	SceneManager.change_scene("res://src/card_battle/card_battle_mode.tscn")


func enter_collection() -> void:
	SceneManager.change_scene("res://src/ui/collection/collection_screen.tscn")


func enter_equipment() -> void:
	SceneManager.change_scene("res://src/ui/equipment/equipment_screen.tscn")


func enter_equipment_for_card(card_id: String) -> void:
	set_meta("equip_preselect_card", card_id)
	SceneManager.change_scene("res://src/ui/equipment/equipment_screen.tscn")


func enter_shop() -> void:
	SceneManager.change_scene("res://src/ui/shop/shop_screen.tscn")


func return_to_main_menu() -> void:
	current_mode = GameMode.NONE
	SceneManager.change_scene("res://src/main/main.tscn")
