## M8 隐藏宝藏登记与统计。
## 登记当前关卡全部隐藏点（读取 stage JSON 各段的 hidden_points），
## 收集去重复用 M3 score.has_hidden_point，统计已收集 / 总数，
## 驱动全收集成就判定。不改 M3 计分逻辑。
## 所有数值来自 stage JSON 与 data/balance_m8.json，不硬编码。
extends Node
class_name M8Treasure

## 当前关卡全部隐藏点配置（去重后）。
var total_points: Array = []
## 已收集点 id 集合。
var discovered: Dictionary = {}
## 已收集数量。
var discovered_count: int = 0
## 当前关卡 id。
var stage_id: String = ""

## 登记指定关卡的全部隐藏点。
## stage_data 为 stage_runner.stage_data（含 segments[].hidden_points）。
func setup(stage_id_str: String, stage_data: Dictionary) -> void:
	stage_id = stage_id_str
	total_points.clear()
	discovered.clear()
	discovered_count = 0
	var seen: Dictionary = {}
	var segments: Array = stage_data.get("segments", [])
	for seg in segments:
		if seg is not Dictionary:
			continue
		for pt in seg.get("hidden_points", []):
			if pt is not Dictionary:
				continue
			var pid := str(pt.get("id", ""))
			if pid.is_empty() or seen.has(pid):
				continue
			seen[pid] = true
			total_points.append({"id": pid, "x": float(pt.get("x", 0.0)), "y": float(pt.get("y", 0.0)), "score": int(pt.get("score", 1000))})

## 扫描收集：遍历全部登记点，已触发（score 已计分）且未登记的点记为已收集。
## 遍历 total_points 而非仅当前段，确保跨段已计分的点也能登记。
func scan(stage_runner: M3StageRunner, score: M3Score) -> int:
	if score == null:
		return 0
	var gained := 0
	for pt in total_points:
		if pt is not Dictionary:
			continue
		var pid := str(pt.get("id", ""))
		if pid.is_empty() or discovered.has(pid):
			continue
		if score.has_hidden_point(pid):
			discovered[pid] = true
			discovered_count += 1
			gained += 1
	return gained

## 是否全收集。
func all_collected() -> bool:
	return total_points.is_empty() or discovered_count >= total_points.size()

## 清空登记（切换关卡时调用）。
func reset() -> void:
	total_points.clear()
	discovered.clear()
	discovered_count = 0
	stage_id = ""
