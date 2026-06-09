extends Control

const DEFAULT_BG := "res://assets/ui/main_menu_bg_default.png"

@onready var _bg: TextureRect = $Background


func _ready() -> void:
	var bg_path := GameManager.get_lobby_bg_path()
	set_background(bg_path)


func set_background(path: String) -> void:
	if not ResourceLoader.exists(path):
		path = DEFAULT_BG
	_bg.texture = load(path)


func _on_btn_story_pressed() -> void:
	GameManager.enter_story_mode()


func _on_btn_auto_chess_pressed() -> void:
	GameManager.enter_autochess_mode()


func _on_btn_card_battle_pressed() -> void:
	GameManager.enter_card_battle_mode()
