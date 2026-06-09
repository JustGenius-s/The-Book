extends Node

enum GameMode { NONE, STORY, AUTOCHESS, CARD_BATTLE }

var current_mode: GameMode = GameMode.NONE


func enter_story_mode() -> void:
	current_mode = GameMode.STORY
	SceneManager.change_scene("res://src/story/story_mode.tscn")


func enter_autochess_mode() -> void:
	current_mode = GameMode.AUTOCHESS
	SceneManager.change_scene("res://src/autochess/autochess_mode.tscn")


func enter_card_battle_mode() -> void:
	current_mode = GameMode.CARD_BATTLE
	SceneManager.change_scene("res://src/card_battle/card_battle_mode.tscn")


func return_to_main_menu() -> void:
	current_mode = GameMode.NONE
	SceneManager.change_scene("res://src/main/main.tscn")
