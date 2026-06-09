class_name TerrainManager
extends RefCounted

signal terrain_changed(old_id: String, new_id: String)

var _current_terrain: TerrainData = null
var _global_fields: FieldContainer


func _init(global_fields: FieldContainer) -> void:
	_global_fields = global_fields


func get_current_terrain() -> TerrainData:
	return _current_terrain


func set_terrain(terrain: TerrainData) -> void:
	var old_id := _current_terrain.id if _current_terrain else ""

	_global_fields.clear_by_source(FieldEntry.FieldSource.TERRAIN)

	_current_terrain = terrain

	if terrain:
		for field: FieldEntry in terrain.global_fields:
			var copy := field.duplicate_entry()
			copy.source = FieldEntry.FieldSource.TERRAIN
			copy.duration = -1
			_global_fields.add_field(copy)

	terrain_changed.emit(old_id, terrain.id if terrain else "")


func clear_terrain() -> void:
	var old_id := _current_terrain.id if _current_terrain else ""
	_global_fields.clear_by_source(FieldEntry.FieldSource.TERRAIN)
	_current_terrain = null
	terrain_changed.emit(old_id, "")
