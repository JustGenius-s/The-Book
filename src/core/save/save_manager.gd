extends Node

const SAVE_PATH := "user://saves/player.json"

var player: PlayerData = PlayerData.new()


func _ready() -> void:
	load_game()


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
