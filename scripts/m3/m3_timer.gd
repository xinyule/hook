## M3 TIME 计时与飞鹰演出。
## TIME 按 decrement_per_second 递减；归零触发飞鹰：从屏外推所有玩家前进，
## 扣 eagle_hp_cost_percent HP；飞鹰可按 idle 阈值重复触发。
## 所有数值来自 arcade.json 的 TimePressure 块。
extends Node
class_name M3Timer

signal eagle_triggered
signal time_zero

var initial_time: float = 99.0
var time_value: float = 99.0
var decrement_per_second: float = 1.0
var eagle_enabled: bool = true
var eagle_idle_threshold: float = 12.0
var eagle_push_distance: float = 8.0
var eagle_hp_cost_percent: float = 5.0
var eagle_cooldown: float = 0.0
var eagle_state: String = "idle"
var eagle_warning_frames: int = 0

## 从规则集配置。
func configure(ruleset: Dictionary) -> void:
	var tp: Dictionary = ruleset.get("TimePressure", {})
	initial_time = float(tp.get("time_bar_initial", 99))
	time_value = initial_time
	decrement_per_second = float(tp.get("decrement_per_second", 1))
	eagle_enabled = tp.get("eagle_enabled", true)
	eagle_idle_threshold = float(tp.get("eagle_idle_threshold_seconds", 12))
	eagle_push_distance = float(tp.get("eagle_push_distance_m", 8))
	eagle_hp_cost_percent = float(tp.get("eagle_hp_cost_percent", 5))

func reset() -> void:
	time_value = initial_time
	eagle_cooldown = 0.0
	eagle_state = "idle"
	eagle_warning_frames = 0

## 每帧推进。
func tick(dt: float, arena: Node3D, player_manager: Node3D) -> void:
	if eagle_cooldown > 0.0:
		eagle_cooldown -= dt
	time_value -= decrement_per_second * dt
	if time_value <= 0.0:
		time_value = 0.0
		if eagle_enabled and eagle_cooldown <= 0.0:
			trigger_eagle(arena, player_manager)

## 触发飞鹰：推所有玩家前进并扣血。
func trigger_eagle(arena: Node3D, player_manager: Node3D) -> void:
	eagle_state = "warning"
	eagle_warning_frames = 30
	for p in player_manager.active_players():
		if p == null:
			continue
		## 从屏外向前推。
		p.global_position = Vector3(
			p.global_position.x + eagle_push_distance,
			p.global_position.y, 0.0)
		## 扣血（直接扣，绕过无敌帧——飞鹰是关卡灾害）。
		if not p.is_dead:
			var cost := int(float(p.max_hp) * eagle_hp_cost_percent / 100.0)
			p.hp = maxi(p.hp - cost, 0)
			if p.hp <= 0:
				p.is_dead = true
				p.set_state("hurt")
	eagle_state = "active"
	eagle_cooldown = eagle_idle_threshold
	time_value = initial_time
	eagle_triggered.emit()
	time_zero.emit()
