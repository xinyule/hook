## M3 关卡推进器。
## 加载关卡数据，按 segments 顺序推进段落；段落边界由玩家位置触发，
## 当前段全部波次清空后推进下一段；末段（Boss 场）进入即标记锁定。
## 真实波次数据由 M4-M6 填充，M3 阶段 waves 为空时框架照常流转。
extends Node
class_name M3StageRunner

signal segment_advanced
signal stage_complete

var stage_id: String = ""
var stage_data: Dictionary = {}
var segments: Array = []
var current_index: int = 0

## 加载关卡。
func load_stage(id: String) -> void:
	stage_id = id
	stage_data = M3Data.stage(id)
	segments = stage_data.get("segments", [])
	current_index = 0

## 当前段落数据。
func current_segment() -> Dictionary:
	if current_index < segments.size():
		return segments[current_index]
	return {}

func segment_count() -> int:
	return segments.size()

func is_stage_complete() -> bool:
	return current_index >= segments.size()

func is_last_segment() -> bool:
	return current_index >= segments.size() - 1

## 末段是否为 Boss 场（关卡数据含 boss 字段即视为 Boss 段）。
func is_boss_segment() -> bool:
	if not is_last_segment():
		return false
	if stage_data.has("boss"):
		return true
	return current_segment().has("boss")

## 当前段落的波次列表（M3 阶段为空数组，M4-M6 填充）。
func segment_waves() -> Array:
	return current_segment().get("waves", [])

## 当前段落的隐藏点位列表。
func segment_hidden_points() -> Array:
	return current_segment().get("hidden_points", [])

## 推进到下一段，返回是否成功推进。
func advance_segment() -> bool:
	if is_stage_complete():
		return false
	current_index += 1
	segment_advanced.emit()
	return true

## 重置。
func reset() -> void:
	stage_id = ""
	stage_data = {}
	segments = []
	current_index = 0
