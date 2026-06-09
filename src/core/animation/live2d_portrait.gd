class_name Live2DPortrait
extends Node2D

## Wrapper for displaying character portraits.
## Uses GDCubism (Live2D) if available and model exists,
## otherwise falls back to a static PNG sprite.

signal portrait_ready
signal motion_finished(motion_name: String)

var _live2d_model: Node = null
var _static_sprite: Sprite2D = null
var _is_live2d: bool = false


func load_portrait(card: CardData) -> void:
	_clear()

	if _try_load_live2d(card.live2d_model_path):
		_is_live2d = true
	else:
		_load_static(card.portrait)
		_is_live2d = false

	portrait_ready.emit()


func play_motion(motion_group: String, index: int = 0) -> void:
	if not _is_live2d or _live2d_model == null:
		return
	if _live2d_model.has_method("start_motion"):
		_live2d_model.start_motion(motion_group, index)


func set_expression(expression_id: String) -> void:
	if not _is_live2d or _live2d_model == null:
		return
	if _live2d_model.has_method("set_expression"):
		_live2d_model.set_expression(expression_id)


func is_live2d() -> bool:
	return _is_live2d


func _try_load_live2d(model_path: String) -> bool:
	if model_path.is_empty():
		return false

	if not FileAccess.file_exists(model_path):
		return false

	if not ClassDB.class_exists(&"GDCubismUserModel"):
		push_warning("Live2DPortrait: GDCubism plugin not installed, falling back to static portrait")
		return false

	var model_node = ClassDB.instantiate(&"GDCubismUserModel")
	if model_node == null:
		return false

	model_node.set("assets", model_path)
	add_child(model_node)
	_live2d_model = model_node
	return true


func _load_static(texture: Texture2D) -> void:
	_static_sprite = Sprite2D.new()
	if texture:
		_static_sprite.texture = texture
	add_child(_static_sprite)


func _clear() -> void:
	if _live2d_model:
		_live2d_model.queue_free()
		_live2d_model = null
	if _static_sprite:
		_static_sprite.queue_free()
		_static_sprite = null
	_is_live2d = false
