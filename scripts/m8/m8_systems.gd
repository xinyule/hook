## M8 成就 / 练习模式 / 最高分系统。
## 成就：条件式定义（击杀 / 连击 / 宝藏 / 无伤通关 / 全角色通关），
## 事件驱动解锁、去重、可查询。
## 练习模式：无限续关 / 假人 / 时间减速参数，开关切换。
## 最高分：按「角色 + 关卡」记录，本地持久化（user:// JSON），
## logic_only（headless 自测）下仅内存读写，不落盘。
## 所有数值来自 data/balance_m8.json，不硬编码。
extends Node
class_name M8Systems

## ---- 成就 ----
var unlocked: Dictionary = {}
var total_kills: int = 0
var best_combo: int = 0
var treasure_count: int = 0
var no_damage_clears: int = 0
var cleared_heroes: Array = []

## 击杀事件（累计击杀数）。
func notify_kill(count: int) -> void:
	total_kills += count
	_evaluate("kills", total_kills)

## 连击事件（历史最高连击）。
func notify_combo(combo: int) -> void:
	if combo > best_combo:
		best_combo = combo
	_evaluate("combo", best_combo)

## 宝藏收集事件（当前已收集总数）。
func notify_treasure(count: int) -> void:
	treasure_count = count
	_evaluate("treasures", treasure_count)

## 无伤通关事件。
func notify_no_damage_clear() -> void:
	no_damage_clears += 1
	_evaluate("no_damage_clear", no_damage_clears)

## 角色通关事件（去重记录）。
func notify_hero_clear(hero_id: String) -> void:
	if not cleared_heroes.has(hero_id):
		cleared_heroes.append(hero_id)
	_evaluate("all_heroes_clear", cleared_heroes.size())

## 评估所有匹配条件的成就，满足即解锁（去重）。
func _evaluate(condition: String, value: int) -> void:
	for ach in M8Data.achievements():
		if ach is not Dictionary:
			continue
		if str(ach.get("condition", "")) != condition:
			continue
		var id := str(ach.get("id", ""))
		if id.is_empty() or unlocked.has(id):
			continue
		if value >= int(ach.get("threshold", 0)):
			unlocked[id] = true

## 指定成就是否已解锁。
func is_unlocked(ach_id: String) -> bool:
	return unlocked.has(ach_id)

## 已解锁数量。
func unlocked_count() -> int:
	return unlocked.size()

## 重置成就统计（新周目）。
func reset_achievements() -> void:
	unlocked.clear()
	total_kills = 0
	best_combo = 0
	treasure_count = 0
	no_damage_clears = 0
	cleared_heroes.clear()

## ---- 练习模式 ----
var practice_active: bool = false

## 切换练习模式。
func toggle_practice() -> bool:
	practice_active = not practice_active
	return practice_active

## 当前时间缩放（练习模式开启取配置值，否则 1.0）。
func time_scale() -> float:
	if not practice_active:
		return 1.0
	return float(M8Data.practice().get("time_scale", 1.0))

## 练习模式是否启用假人生成。
func practice_spawn_dummy() -> bool:
	return practice_active and bool(M8Data.practice().get("spawn_dummy", false))

## 练习模式假人 HP。
func practice_dummy_hp() -> int:
	return int(M8Data.practice().get("dummy_hp", 9999))

## ---- 最高分 ----
var highscores: Dictionary = {}

## 最高分持久路径。
func _persist_path() -> String:
	return str(M8Data.highscore_meta().get("persist_path", "user://hook3d_highscore.json"))

## 从磁盘加载最高分（logic_only 下仅内存，不读盘）。
func load() -> Dictionary:
	if M8Data.logic_only:
		return highscores
	var path := _persist_path()
	if not FileAccess.file_exists(path):
		return highscores
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return highscores
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		highscores = parsed
	return highscores

## 保存最高分到磁盘（logic_only 下仅内存）。
func save() -> void:
	if M8Data.logic_only:
		return
	var path := _persist_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(highscores))

## 更新最高分：分数高于记录则更新并落盘，返回是否更新。
func update(hero_id: String, stage_id: String, score: int) -> bool:
	var key := hero_id + ":" + stage_id
	var old := int(highscores.get(key, 0))
	if score > old:
		highscores[key] = score
		save()
		return true
	return false

## 查询最高分（避免与 Object.get 冲突，故命名 get_highscore）。
func get_highscore(hero_id: String, stage_id: String) -> int:
	return int(highscores.get(hero_id + ":" + stage_id, 0))
