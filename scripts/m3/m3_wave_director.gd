## M3 波次导演。
## 按 wave 配置从 enemies.json 模板生成敌人；同屏敌人数受
## balance.spawn.max_enemies_onscreen 限制；一波清空推进下一波；
## 全部波次清空 → 段完成事件。
## M3 阶段真实波次为空，框架照常流转；自测可注入合成波次验证生成逻辑。
##
## wave 配置格式（M4-M6 填充真实数据）：
##   {"id":"w1", "spawns":[{"enemy":"grunt","count":3}], "max_onscreen":4}
extends Node
class_name M3WaveDirector

signal wave_cleared
signal segment_cleared

var arena: Node3D = null
var player_manager: Node3D = null
var waves: Array = []
var wave_index: int = 0
var _pending: Array = []          ## 待生成的敌人模板 id 队列
var _wave_enemies: Array = []     ## 当前波次生成的敌人引用
var _spawn_x: float = 0.0
var _spawn_side: int = 1
var _max_onscreen: int = 12
var _active: bool = false

## 初始化。arena 与 player_manager 由主场景注入。
func setup(anode: Node3D, pman: Node3D) -> void:
	arena = anode
	player_manager = pman
	var sp: Dictionary = M2Data.balance().get("spawn", {})
	_max_onscreen = int(sp.get("max_enemies_onscreen", 12))

## 载入波次列表并开始。空波次列表视为无波次，不触发段完成事件
##（避免与主场景 _on_segment_cleared 形成同步递归；M3 阶段占位关卡波次为空）。
func load_waves(wave_list: Array, spawn_x: float, side: int = 1) -> void:
	waves = wave_list
	wave_index = 0
	_spawn_x = spawn_x
	_spawn_side = side
	if waves.is_empty():
		_active = false
		return
	_active = true
	_start_next_wave()

func is_active() -> bool:
	return _active

## 开始下一波，展开 spawns 到待生成队列。
func _start_next_wave() -> void:
	if wave_index >= waves.size():
		_active = false
		segment_cleared.emit()
		return
	var w: Dictionary = waves[wave_index]
	_pending.clear()
	_wave_enemies.clear()
	var spawns: Array = w.get("spawns", [])
	for s in spawns:
		var eid: String = s.get("enemy", "grunt")
		var count: int = int(s.get("count", 1))
		for i in count:
			_pending.append(eid)
	## 本波屏幕上限（wave 可覆盖全局上限）。
	var local_cap := int(w.get("max_onscreen", _max_onscreen))
	_max_onscreen = local_cap
	wave_index += 1

## 每帧生成与清波检测。
func tick(dt: float) -> void:
	if not _active:
		return
	## 生成敌人（受同屏上限约束）。
	var onscreen := _count_onscreen()
	while _pending.size() > 0 and onscreen < _max_onscreen:
		var eid: String = _pending.pop_front()
		_spawn_enemy(eid)
		onscreen += 1
	## 检测当前波是否清空。
	if _pending.is_empty() and _wave_enemies.is_empty():
		wave_cleared.emit()
		_start_next_wave()

## 当前波次生成的敌人中仍存活的数量。
func _count_onscreen() -> int:
	var n := 0
	for e in _wave_enemies:
		if is_instance_valid(e) and not e.is_dead:
			n += 1
	return n

## 生成单个敌人。
func _spawn_enemy(eid: String) -> void:
	var tpl: Dictionary = M2Data.enemy(eid)
	if tpl.is_empty():
		return
	var e := M2Enemy.new()
	var sx := _spawn_x + _spawn_side * (_wave_enemies.size() * 1.2)
	e.name = "Wave_%s" % eid
	## 先入树再初始化，避免 !is_inside_tree() 警告。
	arena.add_child(e)
	e.setup_enemy(eid, sx, 0)
	## 指定目标玩家（取第一个存活玩家）。
	var target: Array = player_manager.active_players()
	if not target.is_empty():
		e.player = target[0]
	arena.enemies.append(e)
	_wave_enemies.append(e)

## 敌人死亡时从本波追踪列表移除（由 arena 在清理时回调）。
func on_enemy_removed(e: Node) -> void:
	_wave_enemies.erase(e)

func reset() -> void:
	waves.clear()
	wave_index = 0
	_pending.clear()
	_wave_enemies.clear()
	_active = false
