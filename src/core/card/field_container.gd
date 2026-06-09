class_name FieldContainer
extends RefCounted

signal field_added(entry: FieldEntry)
signal field_removed(id: String)
signal field_stacked(entry: FieldEntry)
signal field_expired(id: String)

var _fields: Dictionary = {}


func add_field(entry: FieldEntry) -> void:
	if _fields.has(entry.id):
		var existing: FieldEntry = _fields[entry.id]
		if existing.current_stacks < existing.max_stacks:
			existing.current_stacks += 1
			field_stacked.emit(existing)
		existing.duration = entry.duration
		return

	var copy := entry.duplicate_entry()
	_fields[copy.id] = copy
	field_added.emit(copy)


func remove_field(id: String) -> void:
	if _fields.has(id):
		_fields.erase(id)
		field_removed.emit(id)


func has_field(id: String) -> bool:
	return _fields.has(id)


func get_field(id: String) -> FieldEntry:
	return _fields.get(id)


func get_all_fields() -> Array[FieldEntry]:
	var result: Array[FieldEntry] = []
	for entry in _fields.values():
		result.append(entry)
	return result


func get_fields_by_type(type: FieldEntry.FieldType) -> Array[FieldEntry]:
	var result: Array[FieldEntry] = []
	for entry: FieldEntry in _fields.values():
		if entry.type == type:
			result.append(entry)
	return result


func tick() -> Array[String]:
	var expired_ids: Array[String] = []
	var to_remove: Array[String] = []

	for id: String in _fields:
		var entry: FieldEntry = _fields[id]
		if entry.is_permanent():
			continue
		entry.duration -= 1
		if entry.is_expired():
			to_remove.append(id)
			expired_ids.append(id)

	for id: String in to_remove:
		_fields.erase(id)
		field_expired.emit(id)

	return expired_ids


func clear_by_source(source: FieldEntry.FieldSource) -> void:
	var to_remove: Array[String] = []
	for id: String in _fields:
		var entry: FieldEntry = _fields[id]
		if entry.source == source:
			to_remove.append(id)

	for id: String in to_remove:
		_fields.erase(id)
		field_removed.emit(id)


func clear_all() -> void:
	var ids := _fields.keys()
	_fields.clear()
	for id: String in ids:
		field_removed.emit(id)


func size() -> int:
	return _fields.size()
