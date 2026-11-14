## M8 难度与辅助管理器。
## 三档难度（easy / normal / hard）切换即时生效：
## 敌人 HP 按倍率缩放（在场扫描补缩放一次，meta 防重复）、
## TIME 初值按档覆盖、分数倍率作用于结算与最高分、
## 敌人伤害倍率作用于飞鹰扣血；辅助选项数据驱动。
## 所有数值来自 data/balance_m8.json，不硬编码。
extends Node
class_name M8Balance

## 难度档内应用标记（挂在敌人 meta 上防重复缩放）。
const DIFF_FLAG := "_m8_diff_applied"

## 当前难度档。
var current: String = "normal"

## 切换难度档（无效档名保持原档）。
func set_difficulty(name: String) -> bool:
	if not M8Data.difficulties().has(name):
		return false
	current = name
	return true

## 当前档配置。
func cfg() -> Dictionary:
	return M8Data.difficulty(current)

## 敌人 HP 倍率。
func enemy_hp_mult() -> float:
	return float(cfg().get("enemy_hp_mult", 1.0))

## 敌人伤害倍率。
func enemy_damage_mult() -> float:
	return float(cfg().get("enemy_damage_mult", 1.0))

## 分数倍率。
func score_mult() -> float:
	return float(cfg().get("score_mult", 1.0))

## TIME 初值。
func time_initial() -> float:
	return float(cfg().get("time_initial", 99.0))

## 对敌人应用难度 HP 缩放（幂等，已应用直接返回）。
func apply_to_enemy(enemy: M2Actor) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.get_meta(DIFF_FLAG, false):
		return false
	var mult := enemy_hp_mult()
	if mult <= 0.0:
		return false
	enemy.max_hp = maxi(1, int(round(float(enemy.max_hp) * mult)))
	if enemy.hp > enemy.max_hp:
		enemy.hp = enemy.max_hp
	enemy.set_meta(DIFF_FLAG, true)
	return true

## 按当前档覆盖 M3 计时器初值并复位。
func apply_time(timer: M3Timer) -> void:
	if timer == null:
		return
	timer.initial_time = time_initial()
	timer.reset()

## 按当前档调整飞鹰扣血（敌人伤害倍率作用于关卡灾害，从基础值乘倍率避免累积）。
func apply_eagle(timer: M3Timer) -> void:
	if timer == null:
		return
	var tp: Dictionary = M3Data.arcade().get("TimePressure", {})
	var base := float(tp.get("eagle_hp_cost_percent", timer.eagle_hp_cost_percent))
	timer.eagle_hp_cost_percent = base * enemy_damage_mult()

## 指定辅助项是否启用。
func assist_enabled(name: String) -> bool:
	return bool(M8Data.assist(name).get("enabled", false))
