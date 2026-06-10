class_name TerrainData
extends Resource

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var global_fields: Array[FieldEntry] = []
## 静态背景图；为空时战斗背景退回 bg_color 纯色
@export var bg_texture: Texture2D
## 预留：后期动画场景路径（粒子/动态演出），设置后优先于静态图
@export var bg_scene_path: String = ""
## 背景色调：作为遮罩调制色与无图时的兜底背景
@export var bg_color: Color = Color(0.09, 0.08, 0.12)
