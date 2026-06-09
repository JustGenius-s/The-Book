extends Control


func _on_btn_story_pressed() -> void:
	GameManager.enter_story_mode()


func _on_btn_auto_chess_pressed() -> void:
	GameManager.enter_autochess_mode()


func _on_btn_card_battle_pressed() -> void:
	GameManager.enter_card_battle_mode()
