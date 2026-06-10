class_name TraitEffect
extends Resource

## 特性效果：向指定范围施加/移除字段，复用 FieldEntry 效果体系。

enum EffectTarget { SELF, ALL_ALLIES, ALL_ENEMIES, GLOBAL }

@export var target: EffectTarget = EffectTarget.SELF
@export var fields_to_apply: Array[FieldEntry] = []
@export var fields_to_remove: Array[String] = []
