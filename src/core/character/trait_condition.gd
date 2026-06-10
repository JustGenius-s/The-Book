class_name TraitCondition
extends Resource

## 特性触发条件，多个条件按 AND 组合。

enum ConditionType {
	GLOBAL_HAS_FIELD,   ## 全局有某字段（即"处于某场地"，如 water_qi）
	TERRAIN_IS,         ## 当前场地 id 精确匹配
	SELF_HAS_FIELD,     ## 持有者自身有某字段
	SELF_IS_CARD,       ## 持有者是某 card id（装备特性的"佩戴者羁绊"条件）
	SELF_HAS_EQUIPMENT, ## 持有者装备了某 equipment id
	ALLY_ON_FIELD,      ## 某 card id 的友方在场存活（不含自身）
	ENEMY_ON_FIELD,     ## 某 card id 的敌方在场存活
}

@export var type: ConditionType = ConditionType.GLOBAL_HAS_FIELD
## field id / terrain id / card id / equipment id，依条件类型而定
@export var value: String = ""
## 取反：可表达"某角色不在场""不处于某场地"等
@export var negate: bool = false
