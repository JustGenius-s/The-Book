class_name FieldText
extends RefCounted

## 字段/场地文案工具：
## - 根据 FieldEntry.effects 自动生成效果说明
## - 把技能描述里的字段名和场地名渲染成可点击链接（[url] 标签）
## - 提供 lookup(url) 统一解析链接，返回详情 BBCode

const FIELDS_DIR := "res://data/fields"
const TERRAINS_DIR := "res://data/terrains"
const EQUIP_FIELDS_DIR := "res://data/equipment"

const URL_FIELD := "field:"
const URL_TERRAIN := "terrain:"

const BUFF_COLOR := "#7ec97e"
const DEBUFF_COLOR := "#e88a6a"
const SPECIAL_COLOR := "#8fb8de"
const TERRAIN_COLOR := "#c9a0dc"   # 场地名用淡紫色区分

const TARGET_NAMES := {
	SkillData.TargetType.SELF: "自身",
	SkillData.TargetType.SINGLE_ENEMY: "单体敌人",
	SkillData.TargetType.ALL_ENEMIES: "全体敌人",
	SkillData.TargetType.SINGLE_ALLY: "单体友方",
	SkillData.TargetType.ALL_ALLIES: "全体友方",
	SkillData.TargetType.RANDOM_ENEMY: "随机敌人",
}

## 效果 key -> 文案模板；{v} 为数值，{p} 为百分比数值
const EFFECT_TEMPLATES := {
	"stun": "无法行动",
	"dot_damage": "每回合受到 {v} 点伤害",
	"heal_per_turn": "每回合恢复 {v} 点生命",
	"shield": "获得 {v} 点护盾",
	"damage_reduction_percent": "受到的伤害降低 {p}%",
	"damage_bonus_percent": "造成的伤害提升 {p}%",
	"atk_percent": "攻击力 {sp}%",
	"def_percent": "防御 {sp}%",
	"spd_percent": "速度 {sp}%",
	"hp_percent": "生命上限 {sp}%",
	"atk_flat": "攻击力 {sv}",
	"def_flat": "防御 {sv}",
	"spd_flat": "速度 {sv}",
	"hp_flat": "生命上限 {sv}",
}


## 生成字段的完整说明，如「每回合受到 25 点伤害；持续 2 回合；可叠加 3 层」
static func describe(field: FieldEntry) -> String:
	var parts: PackedStringArray = []

	for key: String in field.effects:
		var value := float(field.effects[key])
		var template: String = EFFECT_TEMPLATES.get(key, "%s：%s" % [key, str(value)])
		parts.append(_fill(template, value))

	if field.is_permanent():
		parts.append("永久生效")
	else:
		parts.append("持续 %d 回合" % field.duration)

	if field.max_stacks > 1:
		parts.append("可叠加 %d 层" % field.max_stacks)

	return "；".join(parts)


## 技能涉及的全部字段（施加给目标/自身/全局、驱散、条件判定），按 id 去重
static func collect_skill_fields(skill: SkillData) -> Array[FieldEntry]:
	var by_id: Dictionary = {}

	for field: FieldEntry in skill.fields_to_apply + skill.fields_to_self + skill.fields_to_global:
		by_id[field.id] = field

	var referenced_ids: Array[String] = []
	referenced_ids.assign(skill.fields_to_remove)
	if skill.condition_field_id != "":
		referenced_ids.append(skill.condition_field_id)

	for id: String in referenced_ids:
		if by_id.has(id):
			continue
		var path := "%s/%s.tres" % [FIELDS_DIR, id]
		if ResourceLoader.exists(path):
			var field := load(path) as FieldEntry
			if field:
				by_id[field.id] = field

	var result: Array[FieldEntry] = []
	for field: FieldEntry in by_id.values():
		result.append(field)
	return result


## 技能涉及的场地（terrain_to_create 引用的场地）
static func collect_skill_terrains(skill: SkillData) -> Array[TerrainData]:
	if skill.terrain_to_create == "":
		return []
	var path := "%s/%s.tres" % [TERRAINS_DIR, skill.terrain_to_create]
	if not ResourceLoader.exists(path):
		return []
	var terrain := load(path) as TerrainData
	if terrain == null:
		return []
	return [terrain]


## 把技能描述渲染为 BBCode：字段名/场地名高亮 + 下划线，点击查看详情
static func decorate_description(skill: SkillData) -> String:
	var text := skill.description

	# 场地链接
	for terrain: TerrainData in collect_skill_terrains(skill):
		if terrain.display_name == "" or not text.contains(terrain.display_name):
			continue
		var decorated := "[url=%s%s][color=%s][u]%s[/u][/color][/url]" % [
			URL_TERRAIN, terrain.id, TERRAIN_COLOR, terrain.display_name,
		]
		text = text.replace(terrain.display_name, decorated)

	# 字段链接
	for field: FieldEntry in collect_skill_fields(skill):
		if field.display_name == "" or not text.contains(field.display_name):
			continue
		var decorated := "[url=%s%s][color=%s][u]%s[/u][/color][/url]" % [
			URL_FIELD, field.id, _color_of(field), field.display_name,
		]
		text = text.replace(field.display_name, decorated)

	return text


## 技能详情 BBCode：标题（目标 · 冷却）+ 字段/场地高亮描述。图鉴与战斗详情共用。
static func skill_bbcode(skill: SkillData) -> String:
	var cd_text := "冷却 %d 回合" % skill.cooldown if skill.cooldown > 0 else "普通攻击"
	var text := "[b]%s[/b]（%s · %s）" % [
		skill.display_name,
		TARGET_NAMES.get(skill.target, "未知"),
		cd_text,
	]
	if skill.description != "":
		text += "\n" + decorate_description(skill)
	return text


## 渲染单个字段为点击链接 BBCode，如 [url=field:burn][color=#e88a6a]灼烧[/color][/url] 每回合受到 25 点伤害
static func field_bbcode(field: FieldEntry) -> String:
	return "[url=%s%s][color=%s]%s[/color][/url] %s" % [
		URL_FIELD, field.id, _color_of(field), field.display_name, describe(field),
	]


## 根据点击链接（如 field:burn），返回对应的详情 BBCode；找不到返回空
static func lookup(url: String) -> String:
	if url.begins_with(URL_FIELD):
		return _field_detail(url.trim_prefix(URL_FIELD))
	elif url.begins_with(URL_TERRAIN):
		return _terrain_detail(url.trim_prefix(URL_TERRAIN))
	return ""


static func _field_detail(id: String) -> String:
	var path := "%s/%s.tres" % [FIELDS_DIR, id]
	if not ResourceLoader.exists(path):
		path = "%s/%s.tres" % [EQUIP_FIELDS_DIR, id]
	if not ResourceLoader.exists(path):
		return ""
	var field := load(path) as FieldEntry
	if field == null:
		return ""
	return "[b]%s[/b]（%s）\n%s" % [
		field.display_name,
		_badge_of(field),
		describe(field),
	]


static func _terrain_detail(id: String) -> String:
	var path := "%s/%s.tres" % [TERRAINS_DIR, id]
	if not ResourceLoader.exists(path):
		return ""
	var terrain := load(path) as TerrainData
	if terrain == null:
		return ""

	var lines: PackedStringArray = ["[b]场地：%s[/b]" % terrain.display_name]
	lines.append(terrain.description)
	for field: FieldEntry in terrain.global_fields:
		lines.append("「%s」%s" % [field.display_name, describe(field)])
	return "\n".join(lines)


static func _badge_of(field: FieldEntry) -> String:
	match field.type:
		FieldEntry.FieldType.BUFF:
			return "增益"
		FieldEntry.FieldType.DEBUFF:
			return "减益"
		_:
			return "特殊"


static func _fill(template: String, value: float) -> String:
	var percent := value * 100.0
	return template \
		.replace("{v}", str(int(value))) \
		.replace("{sv}", "%+d" % int(value)) \
		.replace("{p}", str(absi(int(percent)))) \
		.replace("{sp}", "%+d" % int(percent))


static func _color_of(field: FieldEntry) -> String:
	match field.type:
		FieldEntry.FieldType.BUFF:
			return BUFF_COLOR
		FieldEntry.FieldType.DEBUFF:
			return DEBUFF_COLOR
		_:
			return SPECIAL_COLOR
