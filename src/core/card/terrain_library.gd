extends Node

## Autoload：启动时扫描 data/terrains/ 下的全部地形资源，按 id 建立索引。
## 遭遇战未指定地形时从这里随机抽取。

const TERRAINS_DIR := "res://data/terrains"

var _terrains: Dictionary = {}


func _ready() -> void:
	_load_terrains()


func get_terrain(id: String) -> TerrainData:
	return _terrains.get(id)


func get_all() -> Array[TerrainData]:
	var result: Array[TerrainData] = []
	for terrain: TerrainData in _terrains.values():
		result.append(terrain)
	return result


func get_random() -> TerrainData:
	if _terrains.is_empty():
		return null
	var values := _terrains.values()
	return values[randi() % values.size()]


func _load_terrains() -> void:
	var dir := DirAccess.open(TERRAINS_DIR)
	if dir == null:
		push_error("TerrainLibrary: cannot open '%s'" % TERRAINS_DIR)
		return

	for file in dir.get_files():
		# 导出后的 pck 中资源文件会带 .remap 后缀
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")):
			continue
		var path := TERRAINS_DIR + "/" + file.trim_suffix(".remap")
		var terrain := load(path) as TerrainData
		if terrain == null:
			push_error("TerrainLibrary: '%s' is not a TerrainData" % path)
			continue
		_terrains[terrain.id] = terrain
