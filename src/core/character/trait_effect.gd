class_name TraitEffect
extends Resource

## 特性效果：向指定范围施加/移除字段（复用 FieldEntry 效果体系），
## 并可附带形态切换（仅对特性持有者生效）。

enum EffectTarget { SELF, ALL_ALLIES, ALL_ENEMIES, GLOBAL }

enum HpPolicy {
	KEEP_PERCENT,  ## 保持 HP 百分比（旧 60% → 新形态 max_hp 的 60%）
	KEEP_VALUE,    ## 保持当前 HP 数值（超出新上限则截断）
	FULL_RESTORE,  ## 切换后满血（适合"觉醒"类剧情形态）
}

enum CooldownPolicy {
	INHERIT_BY_ID,    ## 同 id 技能继承剩余冷却，新技能从 0 开始
	RESET_ALL,        ## 全部清零，切换后所有技能立即可用
	ALL_ON_COOLDOWN,  ## 全部进入冷却（防止变身后立刻使用大招）
}

enum FieldPolicy {
	KEEP_ALL,       ## 保留全部字段（灼烧/增益不因变身消失）
	CLEAR_DEBUFFS,  ## 净化：移除自身 DEBUFF 类字段
	CLEAR_BUFFS,    ## 代价：移除自身 BUFF 类字段
	CLEAR_ALL,      ## 全部清除（脱胎换骨）
}

@export var target: EffectTarget = EffectTarget.SELF
@export var fields_to_apply: Array[FieldEntry] = []
@export var fields_to_remove: Array[String] = []

@export_group("Form Switch")
## 切换到的形态 card id（须与持有者同 character_id），空 = 不切换
@export var switch_to_form: String = ""
@export var hp_policy: HpPolicy = HpPolicy.KEEP_PERCENT
@export var cooldown_policy: CooldownPolicy = CooldownPolicy.INHERIT_BY_ID
@export var field_policy: FieldPolicy = FieldPolicy.KEEP_ALL
