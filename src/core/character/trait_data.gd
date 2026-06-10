class_name TraitData
extends Resource

## 特性：可挂在卡牌（CardData.traits）或装备（EquipmentData.traits）上，
## 由 TraitProcessor 在战斗中统一评估。

## PERSISTENT 状态型：条件满足期间持续生效，条件不再满足时自动撤销已施加的字段
## TRIGGERED 事件型：在 trigger 指定时机评估条件，满足则一次性施加效果
enum TraitKind { PERSISTENT, TRIGGERED }
enum TriggerEvent { ON_TURN_START, ON_TURN_END, ON_ATTACK, ON_HIT, ON_KILL }

@export var id: String
@export var display_name: String
@export var kind: TraitKind = TraitKind.PERSISTENT
## 仅事件型使用
@export var trigger: TriggerEvent = TriggerEvent.ON_TURN_START
## AND 组合：全部满足才激活
@export var conditions: Array[TraitCondition] = []
@export var effects: Array[TraitEffect] = []
@export_multiline var description: String
