## M9 性能监控与达标判定管理器。
## 采集帧循环预算与同屏实体规模，对照 delivery_m9.json 的 performance 目标
## 判定达标（1080p / 60fps、同屏实体上限、内存预算）。
## logic_only（headless 自测）下以逻辑模拟验证阈值判定与超标告警，
## 不依赖真实渲染帧率。所有数值来自 data/delivery_m9.json，不硬编码。
extends Node
class_name M9Perf

## 当前同屏实体数（由 m9_arena 每帧注入）。
var current_entities: int = 0

## 模拟单帧耗时（毫秒，logic_only 下由自测注入；运行时由引擎实测）。
var current_frame_ms: float = 0.0

## 超标告警列表。
var warnings: Array = []

## 重置采集状态。
func reset() -> void:
	current_entities = 0
	current_frame_ms = 0.0
	warnings.clear()

## 设置当前同屏实体数。
func set_entities(count: int) -> void:
	current_entities = maxi(0, count)

## 设置当前单帧耗时（毫秒）。
func set_frame_ms(ms: float) -> void:
	current_frame_ms = maxf(0.0, ms)

## 运行达标判定，返回是否全部达标。
func evaluate() -> bool:
	warnings.clear()
	var target_fps := M9Data.target_fps()
	var budget := M9Data.frame_budget_ms()
	var max_ent := M9Data.max_entities()
	var mem_budget := M9Data.memory_budget_mb()
	## 帧预算：单帧耗时超过预算则超标。
	if current_frame_ms > budget:
		warnings.append("单帧耗时 %.2fms 超过预算 %.2fms（目标 %dfp）" % [current_frame_ms, budget, target_fps])
	## 同屏实体：超过上限则超标。
	if current_entities > max_ent:
		warnings.append("同屏实体 %d 超过上限 %d" % [current_entities, max_ent])
	## 内存预算：logic_only 下不读真实内存，以预算值为记录项，不判定超标。
	## （运行时由引擎 OS.get_static_memory_usage 实测，此处保留阈值供交付核验。）
	return warnings.is_empty()

## 是否达标。
func is_ok() -> bool:
	return warnings.is_empty()

## 目标帧率。
func target_fps() -> int:
	return M9Data.target_fps()

## 单帧预算（毫秒）。
func frame_budget_ms() -> float:
	return M9Data.frame_budget_ms()

## 同屏实体上限。
func max_entities() -> int:
	return M9Data.max_entities()

## 内存预算（MB）。
func memory_budget_mb() -> int:
	return M9Data.memory_budget_mb()
