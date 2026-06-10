extends Control

## 卡牌图鉴：展示全部卡牌，未拥有的置灰，点击查看详情。

const UNOWNED_TINT := Color(0.3, 0.3, 0.3)

@onready var _grid: GridContainer = $Scroll/Grid
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _detail_overlay: Control = $DetailOverlay
@onready var _detail_portrait: TextureRect = $DetailOverlay/Center/Panel/HBox/Portrait
@onready var _detail_name: Label = $DetailOverlay/Center/Panel/HBox/Info/NameLabel
@onready var _detail_owned: Label = $DetailOverlay/Center/Panel/HBox/Info/OwnedLabel
@onready var _detail_stats: Label = $DetailOverlay/Center/Panel/HBox/Info/StatsLabel
@onready var _detail_skills: RichTextLabel = $DetailOverlay/Center/Panel/HBox/Info/SkillsLabel


func _ready() -> void:
	$TopBar/BackButton.pressed.connect(GameManager.return_to_main_menu)
	$DetailOverlay/Center/Panel/HBox/Info/CloseButton.pressed.connect(
		func() -> void: _detail_overlay.visible = false
	)

	_gold_label.text = "金币：%d" % SaveManager.player.get_currency("gold")
	_populate_grid()


func _populate_grid() -> void:
	for card: CardData in CardLibrary.get_all_cards():
		_grid.add_child(_make_tile(card, SaveManager.player.has_card(card.id)))


func _make_tile(card: CardData, owned: bool) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(170, 230)
	tile.pressed.connect(_show_detail.bind(card, owned))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)

	var portrait := TextureRect.new()
	portrait.texture = card.portrait
	portrait.custom_minimum_size = Vector2(160, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		portrait.modulate = UNOWNED_TINT
	vbox.add_child(portrait)

	var rarity_label := Label.new()
	rarity_label.text = "★".repeat(card.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = card.display_name if owned else "？？？"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	return tile


func _show_detail(card: CardData, owned: bool) -> void:
	_detail_portrait.texture = card.portrait
	_detail_portrait.modulate = Color.WHITE if owned else UNOWNED_TINT
	_detail_name.text = "%s %s" % ["★".repeat(card.rarity), card.display_name]
	_detail_owned.text = "已拥有" if owned else "未拥有"
	_detail_owned.add_theme_color_override(
		"font_color",
		Color(0.5, 1.0, 0.5) if owned else Color(0.7, 0.7, 0.7),
	)
	_detail_stats.text = "生命 %d    攻击 %d    防御 %d    速度 %d" % [
		card.base_hp, card.base_atk, card.base_def, card.base_spd,
	]

	_detail_skills.clear()
	for skill: SkillData in card.skills:
		# 字段名高亮展示，悬浮可查看字段效果
		_detail_skills.append_text("%s\n\n" % FieldText.skill_bbcode(skill))

	_detail_overlay.visible = true
