## M2 玩家类。
## 在 M1 状态机基础上扩展：五角色招式差异、必杀技（A+B）、
## 落地必杀、墙跳、空投、背投、倒地追击、格挡。
## 招式帧表全部来自 combat_m2.json，不在脚本硬编码。
extends M2Actor
class_name M2Player

## ---- 输入 ----
var input_queue: Array = []          ## 待处理输入
var combo_queued: bool = false       ## 连段预约
var grab_hits: int = 0               ## 抓取已连击数
var grab_target: M2Actor = null      ## 抓取中目标
var active_hit: Dictionary = {}      ## 当前生效招式
var hit_enemies: Array = []          ## 本招式已命中集合（去重）
var combo_count: int = 0             ## 连击数（视觉）

## ---- 必杀 / 落地必杀 ----
var landing_ultimate_window: int = 0 ## 落地必杀剩余窗口帧
var ult_pressed: bool = false         ## A+B 是否刚按下

## ---- 墙跳 ----
var wall_side: int = 0               ## 上次撞墙方向

## 当前角色 id（从 1-5 选人）。
var character_id: String = "hero_01"

## 输入动作常量。
const ACT_LEFT := "m2_left"
const ACT_RIGHT := "m2_right"
const ACT_UP := "m2_up"
const ACT_DOWN := "m2_down"
const ACT_A := "m2_a"
const ACT_B := "m2_b"

func setup_player(id: String, spawn_x: float) -> void:
	character_id = id
	actor_id = id
	set_spawn(spawn_x)
	setup(id)
	global_position = Vector3(spawn_x, 0.0, 0.0)
	facing = 1

## 推入输入，带衰减（防连发堆积）。
func push_input(action: String) -> void:
	input_queue.append(action)
	if input_queue.size() > 8:
		input_queue.pop_front()

## 处理队列，取出下一个输入。
func _consume() -> String:
	if input_queue.is_empty():
		return ""
	return input_queue.pop_front()

## 取当前招式定义（按状态名查 attack_table）。
func current_move() -> Dictionary:
	var table: Dictionary = m2.get("attack_table", {})
	return table.get(state, {})

## 取攻击盒（考虑招式活跃帧）。
func current_hitbox() -> Rect2:
	var mv := current_move()
	var active_start := int(mv.get("active_frame", 0))
	var active_end := int(mv.get("active_frame_end", active_start))
	if state_frames < active_start or state_frames > active_end:
		return Rect2()
	return hitbox(true)

## 每帧主循环。
func tick(dt: float, arena: Node) -> void:
	tick_state()
	_decay_input()
	if is_thrown:
		integrate(dt)
		return
	if is_ulting:
		_handle_ultimate(dt, arena)
		integrate(dt)
		return
	if not on_floor:
		_handle_air(dt, arena)
		integrate(dt)
		return
	if is_downed:
		_handle_downed(dt, arena)
		integrate(dt)
		return
	_handle_ground(dt, arena)
	integrate(dt)

## 地面输入处理。
func _handle_ground(dt: float, arena: Node) -> void:
	var inp := _consume()
	## 必杀技预约：A+B 同时或先后按下。
	if inp == ACT_A:
		ult_pressed = true
	if inp == ACT_B and ult_pressed:
		_try_ultimate(arena)
		ult_pressed = false
		return
	if inp == ACT_B and not ult_pressed:
		ult_pressed = false

	## 移动。
	if state == "idle" or state == "walk":
		if inp == ACT_LEFT:
			vx = -float(M2Data.m2_base().get("move_speed_mps", 4.2))
			facing = -1
		elif inp == ACT_RIGHT:
			vx = float(M2Data.m2_base().get("move_speed_mps", 4.2))
			facing = 1
		elif inp == ACT_UP:
			_try_jump()
		elif inp == ACT_DOWN:
			set_state("down_attack")
			state_frames = 0
		elif inp == ACT_A:
			_try_start_attack(arena)
		elif inp == ACT_B:
			_try_grab(arena)
		if state == "idle" and vx != 0.0:
			set_state("walk")
		elif state == "walk" and vx == 0.0:
			set_state("idle")

## 空中输入处理。
func _handle_air(dt: float, arena: Node) -> void:
	var inp := _consume()
	## 空投：空中按 B 且有抓取目标。
	if inp == ACT_B and grab_target != null and not grab_target.is_dead:
		_air_throw(arena)
		return
	## 空中攻击。
	if inp == ACT_A and state != "jump_attack":
		set_state("jump_attack")
		state_frames = 0
		active_hit = current_move()
		hit_enemies.clear()
	## 墙跳：空中反向撞墙 + 按上。
	if inp == ACT_UP and is_wall_jumping:
		vy = float(M2Data.m2_base().get("jump_speed_mps", 9.0))
		vx = -facing * float(M2Data.m2_base().get("move_speed_mps", 4.2))

## 倒地状态处理（被击倒后起身前）。
func _handle_downed(dt: float, arena: Node) -> void:
	var inp := _consume()
	## 倒地追击：起身前可继续连击。
	if inp == ACT_A and downed_hits < _downed_max():
		_downed_hit(arena)
	## 起身：倒地计时结束或按上。
	if inp == ACT_UP or knockdown_frames <= 0:
		is_downed = false
		set_state("idle")

## 倒地追击最大连击数（POCKETS 为 8，其余 3-4）。
func _downed_max() -> int:
	var dc := M2Data.downed_chase()
	var pockets_char: String = dc.get("pockets_character", "hero_04")
	if character_id == pockets_char:
		return int(dc.get("pockets_max", 8))
	return int(dc.get("default_max", 4))

## 倒地追击单次打击。
func _downed_hit(arena: Node) -> void:
	downed_hits += 1
	downed_refresh = int(M2Data.downed_chase().get("refresh_frames", 6))
	## 对周围敌人造成小伤害。
	var hb := Rect2(global_position.x - 1.0, global_position.y - 0.5, 2.0, 1.0)
	for e in arena.enemies:
		if e.is_dead:
			continue
		if hb.intersects(e.hurtbox()):
			hit_id_counter += 1
			e.take_damage(8, facing, 0.8, hit_id_counter)
			arena.register_hit(e, facing)

## 尝试跳跃。
func _try_jump() -> void:
	if on_floor:
		vy = float(M2Data.m2_base().get("jump_speed_mps", 9.0))
		on_floor = false
		set_state("jump")
		state_frames = 0

## 尝试开始地面攻击（连段链）。
func _try_start_attack(arena: Node) -> void:
	if state == "idle" or state == "walk":
		_begin_attack(arena, "Attack1")
	elif state in ["Attack1", "Attack2", "Attack3"]:
		var next := ""
		if state == "Attack1":
			next = "Attack2"
		elif state == "Attack2":
			next = "Attack3"
		elif state == "Attack3":
			next = "Attack4"
		_begin_attack(arena, next)
	elif state == "Attack4":
		## 第四段后接 Special 或 Heavy（按快慢分支）。
		_begin_attack(arena, "Special")

## 开始一个招式。
func _begin_attack(arena: Node, move_name: String) -> void:
	var mv: Dictionary = m2.get("attack_table", {}).get(move_name, {})
	if mv.is_empty():
		return
	set_state(move_name)
	state_frames = 0
	active_hit = mv
	hit_enemies.clear()
	combo_count += 1

## 推进当前招式帧，活跃帧检测命中。
func _advance_attack(arena: Node) -> void:
	if state_frames == 0:
		return
	var mv := active_hit
	if mv.is_empty():
		return
	var total := int(mv.get("total_frames", 12))
	var active_start := int(mv.get("active_frame", 0))
	var active_end := int(mv.get("active_frame_end", active_start))
	## 活跃帧检测命中。
	if state_frames >= active_start and state_frames <= active_end:
		var hb := current_hitbox()
		if hb != Rect2():
			for e in arena.enemies:
				if e.is_dead or hit_enemies.has(e):
					continue
				if hb.intersects(e.hurtbox()):
					hit_enemies.append(e)
					hit_id_counter += 1
					var dmg := int(float(e.max_hp) * 0.12 * float(mv.get("damage_mult", 1.0)))
					var kb := float(mv.get("knockback_m", 1.0))
					e.take_damage(dmg, facing, kb, hit_id_counter)
					arena.register_hit(e, facing, mv.get("damage_mult", 1.0))
	## 招式结束。
	if state_frames >= total:
		set_state("idle")
		combo_count = 0

## 尝试抓取。
func _try_grab(arena: Node) -> void:
	var nearest := _nearest_enemy(arena)
	if nearest == null:
		return
	var base := M2Data.m2_base()
	var dist: float = abs(global_position.x - nearest.global_position.x)
	if dist <= float(base.get("grab_range", 0.9)) and abs(global_position.y - nearest.global_position.y) < 0.6:
		grab_target = nearest
		grab_hits = 0
		set_state("grab")
		state_frames = 0

## 推进抓取连击，达到上限自动投出。
func _advance_grab(arena: Node) -> void:
	if grab_target == null or grab_target.is_dead:
		grab_target = null
		set_state("idle")
		return
	var gcfg := M2Data.grab()
	var max_hits := int(gcfg.get("max_hits", 5))
	if state == "grab" and state_frames > 0 and state_frames % 8 == 0:
		grab_hits += 1
		var dmg := int(float(grab_target.max_hp) * 0.06)
		grab_target.take_damage(dmg, facing, 0.3, hit_id_counter)
		hit_id_counter += 1
		arena.register_hit(grab_target, facing, 1.0)
	if grab_hits >= max_hits:
		_throw_target(arena)

## 投出抓取目标。
func _throw_target(arena: Node) -> void:
	if grab_target == null:
		set_state("idle")
		return
	var cfg := M2Data.grab()
	var dmg_mult := float(cfg.get("throw_damage_mult", 2.5))
	var dmg := int(float(grab_target.max_hp) * 0.10 * dmg_mult)
	grab_target.take_damage(dmg, facing, 4.0, hit_id_counter)
	hit_id_counter += 1
	grab_target.start_throw(facing)
	grab_target.throw_bounces = int(cfg.get("wall_bounce_count", 1))
	arena.register_hit(grab_target, facing, dmg_mult)
	grab_target = null
	grab_hits = 0
	set_state("idle")

## 空投：空中抓取投出。
func _air_throw(arena: Node) -> void:
	if grab_target == null:
		return
	var cfg := M2Data.air_throw()
	var dmg := int(float(grab_target.max_hp) * 0.10 * float(cfg.get("damage_mult", 2.8)))
	grab_target.take_damage(dmg, facing, float(cfg.get("throw_vx", 7.0)), hit_id_counter)
	hit_id_counter += 1
	grab_target.start_throw(facing)
	grab_target.vx = facing * float(cfg.get("throw_vx", 7.0))
	grab_target.vy = float(cfg.get("throw_vy", 6.0))
	arena.register_hit(grab_target, facing, float(cfg.get("damage_mult", 2.8)))
	grab_target = null
	grab_hits = 0

## 背投：抓取中按下+B（简化为背后敌人抓取后投出）。
func _back_throw(arena: Node) -> void:
	if grab_target == null:
		return
	var cfg := M2Data.back_throw()
	var dmg := int(float(grab_target.max_hp) * 0.10 * float(cfg.get("damage_mult", 2.0)))
	grab_target.take_damage(dmg, -facing, float(cfg.get("throw_vx", 6.0)), hit_id_counter)
	hit_id_counter += 1
	grab_target.start_throw(-facing)
	grab_target.vx = -facing * float(cfg.get("throw_vx", 6.0))
	arena.register_hit(grab_target, -facing, float(cfg.get("damage_mult", 2.0)))
	grab_target = null
	grab_hits = 0

## 尝试必杀技（A+B）。
func _try_ultimate(arena: Node) -> void:
	var ult := M2Data.ultimate()
	var hp_pct := float(hp) / float(max_hp) * 100.0
	var cost := float(ult.get("hp_cost_percent", 8))
	var min_hp := float(ult.get("min_hp_percent", 15))
	if hp_pct < min_hp:
		return  ## 血量不足，禁用
	if hp_pct < cost:
		return
	hp -= int(max_hp * cost / 100.0)
	is_ulting = true
	ultimate_frames = int(ult.get("total_frames", 45))
	invincible_frames = int(ult.get("invincible", 45))
	set_state("ultimate")
	state_frames = 0
	## 必杀全屏判定。
	var hb := Rect2(global_position.x - 3.0, global_position.y - 2.0, 6.0, 4.0)
	for e in arena.enemies:
		if e.is_dead:
			continue
		if hb.intersects(e.hurtbox()):
			hit_id_counter += 1
			var dmg := int(float(e.max_hp) * 0.25)
			e.take_damage(dmg, facing, 3.0, hit_id_counter)
			arena.register_hit(e, facing, 3.0)
			arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("ultimate_shake", 0.6)))

## 必杀技帧推进。
func _handle_ultimate(dt: float, arena: Node) -> void:
	if state_frames == 0:
		return
	## 落地必杀窗口：必杀结束 6 帧内落地触发加强版。
	var lu := M2Data.landing_ultimate()
	if landing_ultimate_window > 0:
		landing_ultimate_window -= 1
	state_frames += 1

## 落地必杀：落地瞬间检测。
func on_land() -> void:
	if is_ulting and landing_ultimate_window > 0:
		var lu := M2Data.landing_ultimate()
		## 触发落地必杀冲击波。
		pass  ## 由 arena 在检测到落地时调用，产生额外特效与伤害

## 取最近敌人。
func _nearest_enemy(arena: Node) -> M2Actor:
	var nearest: M2Actor = null
	var best := 999.0
	for e in arena.enemies:
		if e.is_dead:
			continue
		var d: float = abs(global_position.x - e.global_position.x) + abs(global_position.y - e.global_position.y) * 0.5
		if d < best:
			best = d
			nearest = e
	return nearest

## 输入衰减。
func _decay_input() -> void:
	pass

## 重置玩家。
func reset_player() -> void:
	grab_target = null
	grab_hits = 0
	combo_count = 0
	hit_enemies.clear()
	ult_pressed = false
	is_ulting = false
	landing_ultimate_window = 0
	is_wall_jumping = false
	wall_jump_bounces = 0
	is_blocking = false
	downed_hits = 0
	reset_actor()
