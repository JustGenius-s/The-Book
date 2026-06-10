extends Node

var _current_scene: Node = null

func _ready() -> void:
	var root := get_tree().root
	_current_scene = root.get_child(root.get_child_count() - 1)


func change_scene(scene_path: String) -> void:
	call_deferred("_deferred_change_scene", scene_path)


func _deferred_change_scene(scene_path: String) -> void:
	var new_scene := ResourceLoader.load(scene_path) as PackedScene
	if new_scene == null:
		push_error("SceneManager: failed to load scene '%s'" % scene_path)
		return

	if _current_scene:
		_current_scene.free()

	_current_scene = new_scene.instantiate()
	get_tree().root.add_child(_current_scene)
	get_tree().current_scene = _current_scene
