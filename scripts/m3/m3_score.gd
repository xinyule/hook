## M3 计分系统。
## 击杀 / 连击 / 宝藏 / 隐藏点计分，周目倍率作用于所有得分。
## 隐藏点靠近触发后去重，同一隐藏点只计分一次。
## 数值来自 balance.json 的 score 块与 arcade.json 的 LoopPolicy。
extends Node
class_name M3Score

var score: int = 0
var loop_count: int = 0
var score_multiplier_per_loop: float = 1.2
var kill_base: int = 100
var combo_bonus_per_hit: int = 10
var treasure_base: int = 500
var hidden_point_base: int = 1000
var _hidden_collected: Array = []

## 从规则集与平衡配置。
func configure(ruleset: Dictionary, balance: Dictionary) -> void:
	var lp: Dictionary = ruleset.get("LoopPolicy", {})
	score_multiplier_per_loop = float(lp.get("score_multiplier_per_loop", 1.2))
	var sc: Dictionary = balance.get("score", {})
	kill_base = int(sc.get("kill_base", 100))
	combo_bonus_per_hit = int(sc.get("combo_bonus_per_hit", 10))
	treasure_base = int(sc.get("treasure_base", 500))
	hidden_point_base = int(sc.get("hidden_point_base", 1000))

## 当前周目得分倍率。
func current_multiplier() -> float:
	return score_multiplier_per_loop ** loop_count

## 击杀计分（含连击加成），返回本次得分。
func add_kill(combo: int = 0) -> int:
	var gained := int((kill_base + combo_bonus_per_hit * combo) * current_multiplier())
	score += gained
	return gained

## 宝藏计分，返回本次得分。
func add_treasure() -> int:
	var gained := int(treasure_base * current_multiplier())
	score += gained
	return gained

## 可击碎物件计分（M4 场景物件），返回本次得分。
func add_breakable(base: int) -> int:
	var gained := int(base * current_multiplier())
	score += gained
	return gained

## 隐藏点计分（去重），返回本次得分（已收集过返回 0）。
func add_hidden_point(point_id: String) -> int:
	if _hidden_collected.has(point_id):
		return 0
	_hidden_collected.append(point_id)
	var gained := int(hidden_point_base * current_multiplier())
	score += gained
	return gained

func has_hidden_point(point_id: String) -> bool:
	return _hidden_collected.has(point_id)

func reset() -> void:
	score = 0
	loop_count = 0
	_hidden_collected.clear()

func set_loop(count: int) -> void:
	loop_count = count
