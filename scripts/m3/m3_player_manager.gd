## M3 玩家管理器。
## 4 槽位管理；P1-P4 输入检测（自测用模拟输入事件）；
## 中途加入在段落起点生成并给起身无敌帧；命数管理；
## 死亡 → 命数 -1，耗尽 → 投币续关（短暂停顿后原分数续玩）。
## 复用 M2 的 M2Player，不改战斗核心。
extends Node3D
class_name M3PlayerManager

signal player_joined
signal player_died
signal player_continued

const SLOT_COUNT: int = 4

var players: Array = []           ## 长度为 4，元素为 M2Player 或 null
var lives: Array = []             ## 每个槽位的剩余命数
var character_ids: Array = []     ## 每个槽位选择的角色 id
var spawn_x: float = -3.0
var _continue_timer: float = 0.0
var _continue_slot: int = -1
var _dead_counted: Array = []     ## 已处理过死亡的槽位索引（避免重复扣命）

## 初始化槽位。
func setup(start_lives: int, spawn_x_pos: float) -> void:
	players.clear()
	lives.clear()
	character_ids.clear()
	for i in SLOT_COUNT:
		players.append(null)
		lives.append(start_lives)
		character_ids.append("")
	spawn_x = spawn_x_pos

## 玩家加入指定槽位。返回是否成功。
func join_player(slot: int, character_id: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if players[slot] != null:
		return false  ## 槽位已占满
	var p := M2Player.new()
	p.name = "Player_%d" % (slot + 1)
	## 先入树再初始化。
	add_child(p)
	p.setup_player(character_id, spawn_x)
	## 中途加入给起身无敌帧。
	p.invincible_frames = 60
	players[slot] = p
	character_ids[slot] = character_id
	player_joined.emit(slot)
	return true

## 取存活玩家列表。
func active_players() -> Array:
	var out: Array = []
	for p in players:
		if p != null and not p.is_dead:
			out.append(p)
	return out

## 取所有玩家（含死亡，用于 HUD）。
func all_players() -> Array:
	var out: Array = []
	for p in players:
		if p != null:
			out.append(p)
	return out

## 玩家死亡处理：命数 -1，耗尽则投币续关。
func on_player_death(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	lives[slot] -= 1
	player_died.emit(slot)
	if lives[slot] <= 0:
		## 投币续关：短暂停顿后原分数续玩。
		_continue_slot = slot
		_continue_timer = 1.0

## 每帧推进续关计时与玩家 tick。
func tick(dt: float, arena: Node3D) -> void:
	## 续关倒计时。
	if _continue_slot >= 0:
		_continue_timer -= dt
		if _continue_timer <= 0.0:
			_do_continue(_continue_slot)
			_continue_slot = -1
	## 推进所有玩家。
	for i in SLOT_COUNT:
		var p: M2Player = players[i]
		if p == null:
			continue
		p.tick(dt, arena)
		arena._clamp_actor(p)
		## 检测死亡（每个槽位只扣一次命）。
		if p.is_dead and not _dead_counted.has(i):
			_dead_counted.append(i)
			on_player_death(i)

## 执行续关：重置玩家、补满命数、保留分数（分数在 M3Score 全局，不受影响）。
func _do_continue(slot: int) -> void:
	var p: M2Player = players[slot]
	if p == null:
		return
	p.reset_player()
	_dead_counted.erase(slot)
	lives[slot] = 1
	player_continued.emit(slot)

## 读取 P1-P4 输入并推入对应玩家。
func read_inputs() -> void:
	## 输入动作映射：每个玩家一组 m3_pX_left/right/up/a/b。
	var mapping := {
		0: {"left": "m3_p1_left", "right": "m3_p1_right", "up": "m3_p1_up", "a": "m3_p1_a", "b": "m3_p1_b"},
		1: {"left": "m3_p2_left", "right": "m3_p2_right", "up": "m3_p2_up", "a": "m3_p2_a", "b": "m3_p2_b"},
		2: {"left": "m3_p3_left", "right": "m3_p3_right", "up": "m3_p3_up", "a": "m3_p3_a", "b": "m3_p3_b"},
		3: {"left": "m3_p4_left", "right": "m3_p4_right", "up": "m3_p4_up", "a": "m3_p4_a", "b": "m3_p4_b"},
	}
	for slot in SLOT_COUNT:
		var p: M2Player = players[slot]
		if p == null or p.is_dead:
			continue
		var m: Dictionary = mapping[slot]
		if Input.is_action_just_pressed(m.left):
			p.push_input(M2Player.ACT_LEFT)
		if Input.is_action_just_pressed(m.right):
			p.push_input(M2Player.ACT_RIGHT)
		if Input.is_action_just_pressed(m.up):
			p.push_input(M2Player.ACT_UP)
		if Input.is_action_just_pressed(m.a):
			p.push_input(M2Player.ACT_A)
		if Input.is_action_just_pressed(m.b):
			p.push_input(M2Player.ACT_B)

## 注入模拟输入（自测用）：直接向指定槽位玩家推入动作。
func inject_input(slot: int, action: String) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	var p: M2Player = players[slot]
	if p != null and not p.is_dead:
		p.push_input(action)

## 注册 P1-P4 输入动作。
func register_input_actions() -> void:
	## P1: A/D 移动 J 攻击 K 跳
	## P2: ←/→ 移动 , 攻击 . 跳
	## P3: I/L 移动 Z 攻击 X 跳（修复：原用 J/K 与 P1 冲突，本地多人互串）
	## P4: T/F 移动 G 跳 R 攻击 H 跳
	var defs := [
		{"p1_left": KEY_A, "p1_right": KEY_D, "p1_up": KEY_W, "p1_a": KEY_J, "p1_b": KEY_K},
		{"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_up": KEY_UP, "p2_a": KEY_COMMA, "p2_b": KEY_PERIOD},
		{"p3_left": KEY_I, "p3_right": KEY_L, "p3_up": KEY_U, "p3_a": KEY_Z, "p3_b": KEY_X},
		{"p4_left": KEY_T, "p4_right": KEY_F, "p4_up": KEY_G, "p4_a": KEY_R, "p4_b": KEY_H},
	]
	for d in defs:
		for key in d:
			var action_name: String = "m3_" + key
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			var ev := InputEventKey.new()
			ev.keycode = d[key]
			InputMap.action_add_event(action_name, ev)
