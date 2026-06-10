extends Node

## Autoload：启动时扫描 data/cards/ 下的全部卡牌资源，按 id 建立索引。
## 图鉴、编队、战斗等系统统一通过这里获取卡牌定义。

const CARDS_DIR := "res://data/cards"

var _cards: Dictionary = {}


func _ready() -> void:
	_load_cards()


func get_card(id: String) -> CardData:
	return _cards.get(id)


func has_card(id: String) -> bool:
	return _cards.has(id)


func get_all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in _cards.values():
		result.append(card)
	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.id < b.id
	)
	return result


func _load_cards() -> void:
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		push_error("CardLibrary: cannot open '%s'" % CARDS_DIR)
		return

	for file in dir.get_files():
		# 导出后的 pck 中资源文件会带 .remap 后缀
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")):
			continue
		var path := CARDS_DIR + "/" + file.trim_suffix(".remap")
		var card := load(path) as CardData
		if card == null:
			push_error("CardLibrary: '%s' is not a CardData" % path)
			continue
		if _cards.has(card.id):
			push_error("CardLibrary: duplicate card id '%s'" % card.id)
			continue
		_cards[card.id] = card
