extends Node

## Autoload：启动时扫描 data/equipment/ 下的全部装备资源，按 id 建立索引。

const EQUIPMENT_DIR := "res://data/equipment"

var _equips: Dictionary = {}
var _by_slot: Dictionary = {}


func _ready() -> void:
	_load_equips()


func get_equip(id: String) -> EquipmentData:
	return _equips.get(id)


func has_equip(id: String) -> bool:
	return _equips.has(id)


func get_all() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for e: EquipmentData in _equips.values():
		result.append(e)
	result.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool:
		return a.price < b.price
	)
	return result


func get_by_slot(slot: String) -> Array[EquipmentData]:
	if _by_slot.has(slot):
		return _by_slot[slot]
	return []


func _load_equips() -> void:
	var dir := DirAccess.open(EQUIPMENT_DIR)
	if dir == null:
		push_error("EquipmentLibrary: cannot open '%s'" % EQUIPMENT_DIR)
		return

	for file in dir.get_files():
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")):
			continue

		var path := EQUIPMENT_DIR + "/" + file.trim_suffix(".remap")
		var equip := load(path) as EquipmentData
		if equip == null:
			continue

		_equips[equip.id] = equip

		if not _by_slot.has(equip.slot):
			_by_slot[equip.slot] = []
		_by_slot[equip.slot].append(equip)
