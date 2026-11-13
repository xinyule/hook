## M2 敌人类。
## 七类敌人 AI，由 enemies.json 的 ai 块驱动：
## grunt（基础近战）、drunk（醉酒摇摆+友伤）、flyer（空中突袭）、
## fatty（抓取型）、spearman（远程突刺）、flail（格挡+起身击退）、
## swordsman（慢速重击）。
## 行为差异全部来自数据，不在脚本硬编码。
extends M2Actor
class_name M2Enemy

## 目标玩家引用。
var player: M2Player = null
## 攻击状态标记。
var attack_done: bool = false
## 变体配色 id。
var variant_id: int = 0
## 行为类型（从 ai.behavior 读取）。
var behavior: String = "melee"
## 远程攻击冷却。
var ranged_cooldown: int = 0
## 格挡状态。
var can_block: bool = false
## 空中悬浮高度。
var fly_height: float = 0.0
## 后退距离计数。
var backoff_timer: int = 0

## 初始化敌人。
func setup_enemy(id: String, spawn_x: float, variant: int = 0) -> void:
	actor_id = id
	set_spawn(spawn_x)
	setup(id)
	variant_id = variant
	behavior = ai.get("behavior", "melee")
	can_block = ai.get("block", {}).get("enabled", false)
	fly_height = float(ai.get("fly_height_m", 0.0))
	global_position = Vector3(spawn_x, fly_height, 0.0)
	if variant > 0:
		_apply_variant_color(variant)

## 应用变体配色。
func _apply_variant_color(variant: int) -> void:
	if _visual == null:
		return
	var colors: Dictionary = M2Data.enemies().get("variant_colors", {})
	var key := actor_id + "_v" + str(variant)
	if colors.has(key):
		var body := _visual.get_child(0)
		if body is MeshInstance3D:
			(body.material as StandardMaterial3D).albedo_color = Color(colors[key])

## 撞墙回调（敌人版：反弹 + 清速）。
func on_wall_hit() -> void:
	vx = 0.0
	if behavior == "flyer":
		## 飞者撞墙后短暂悬停。
		backoff_timer = 10

## 每帧 AI 主循环。
func tick(dt: float, arena: Node) -> void:
	tick_state()
	if is_thrown:
		integrate(dt)
		_check_throw_land(arena)
		return
	if is_dead:
		return
	if is_downed:
		_handle_downed(dt, arena)
		integrate(dt)
		return
	_ai_tick(dt, arena)
	integrate(dt)

## 被投掷落地处理。
func _check_throw_land(arena: Node) -> void:
	if on_floor:
		_finish_throw()
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("throw_land_shake", 0.3)))

## 倒地状态：等待起身。
func _handle_downed(dt: float, arena: Node) -> void:
	if knockdown_frames <= 0:
		is_downed = false
		set_state("idle")

## AI 主逻辑。
func _ai_tick(dt: float, arena: Node) -> void:
	if player == null or player.is_dead:
		return
	var dist_x: float = player.global_position.x - global_position.x
	var dist_y: float = player.global_position.y - global_position.y
	var abs_x: float = abs(dist_x)
	var dir: int = 1 if dist_x > 0 else -1

	## 格挡判定：面朝玩家且在格挡状态。
	if can_block and state == "idle" and abs_x < float(ai.get("attack_range_m", 0.8)) * 1.2:
		facing = dir
		if player.state in ["Attack1", "Attack2", "Attack3", "Attack4", "Special", "jump_attack"]:
			is_blocking = true
			block_frames = 8

	## 按行为类型分派。
	if behavior == "ranged":
		_ai_ranged(dt, arena, dist_x, abs_x, dir)
	elif behavior == "flyer":
		_ai_flyer(dt, arena, dist_x, abs_x, dir, dist_y)
	elif behavior == "grapple":
		_ai_grapple(dt, arena, abs_x, dir)
	elif behavior == "slow_heavy":
		_ai_slow_heavy(dt, arena, abs_x, dir)
	elif behavior == "stagger":
		_ai_stagger(dt, arena, abs_x, dir)
	elif behavior == "block_counter":
		_ai_block_counter(dt, arena, abs_x, dir)
	else:
		_ai_melee(dt, arena, abs_x, dir)

## 基础近战 AI（grunt）。
func _ai_melee(dt: float, arena: Node, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 0.8))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 2.0))
			set_state("walk")
		else:
			vx = 0.0
			set_state("windup")
			state_frames = 0
	elif state == "windup":
		vx = 0.0
		if state_frames >= int(ai.get("windup_frames", 12)):
			set_state("attack")
			state_frames = 0
			_do_enemy_attack(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 8)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 16)):
			set_state("idle")
			state_frames = 0

## 远程突刺 AI（spearman）。
func _ai_ranged(dt: float, arena: Node, dist_x: float, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 2.0))
	var retreat := float(ai.get("backoff_m", 1.5))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 1.8))
			set_state("walk")
		elif abs_x < atk_range * 0.5:
			## 太近，后退保持距离。
			vx = -dir * float(ai.get("speed_mps", 1.8))
			set_state("walk")
		else:
			vx = 0.0
			if ranged_cooldown <= 0:
				set_state("windup")
				state_frames = 0
		if ranged_cooldown > 0:
			ranged_cooldown -= 1
	elif state == "windup":
		vx = 0.0
		if state_frames >= int(ai.get("windup_frames", 16)):
			set_state("attack")
			state_frames = 0
			_do_ranged_attack(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 10)):
			set_state("recover")
			state_frames = 0
			ranged_cooldown = 40
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 20)):
			set_state("idle")
			state_frames = 0

## 执行近战攻击。
func _do_enemy_attack(arena: Node, dir: int) -> void:
	var hb := Rect2(global_position.x + dir * (half_width + 0.3), global_position.y - 0.4, float(ai.get("attack_range_m", 0.8)), 0.8)
	if hb.intersects(player.hurtbox()):
		var dmg := int(ai.get("damage", 8))
		var kb := float(ai.get("knockback_m", 1.0))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb, hit_id_counter)
		arena.register_enemy_hit(player, dir)
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("enemy_hit_shake", 0.2)))

## 执行远程突刺。
func _do_ranged_attack(arena: Node, dir: int) -> void:
	## 简化：突刺瞬间判定，不生成飞行体（M2 沙盒阶段）。
	var reach := float(ai.get("attack_range_m", 2.0))
	var hb := Rect2(global_position.x, global_position.y - 0.3, dir * reach, 0.6)
	if hb.intersects(player.hurtbox()):
		var dmg := int(ai.get("damage", 10))
		var kb := float(ai.get("knockback_m", 1.5))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb, hit_id_counter)
		arena.register_enemy_hit(player, dir)
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("enemy_hit_shake", 0.2)))

## 空中突袭 AI（flyer）。
func _ai_flyer(dt: float, arena: Node, dist_x: float, abs_x: float, dir: int, dist_y: float) -> void:
	var atk_range := float(ai.get("attack_range_m", 1.2))
	if state == "idle":
		facing = dir
		## 悬停接近玩家水平位置。
		var target_y := fly_height
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 3.0))
			## 向玩家高度俯冲。
			if abs(global_position.y - player.global_position.y) > 0.5:
				vy = -float(ai.get("speed_mps", 3.0)) * 0.5
			set_state("walk")
		else:
			vx = 0.0
			## 俯冲攻击。
			vy = -float(ai.get("speed_mps", 3.0))
			set_state("windup")
			state_frames = 0
	elif state == "windup":
		if state_frames >= int(ai.get("windup_frames", 8)):
			set_state("attack")
			state_frames = 0
			_do_flyer_dive(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 6)):
			## 攻击后拉起。
			vy = float(ai.get("speed_mps", 3.0)) * 0.5
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		vy = float(ai.get("speed_mps", 3.0)) * 0.3
		if state_frames >= int(ai.get("recover_frames", 12)):
			## 回到悬浮高度。
			global_position.y = fly_height
			vy = 0.0
			set_state("idle")
			state_frames = 0

## 飞者俯冲攻击。
func _do_flyer_dive(arena: Node, dir: int) -> void:
	var hb := Rect2(global_position.x - 0.6, global_position.y - 0.6, 1.2, 1.2)
	if hb.intersects(player.hurtbox()):
		var dmg := int(ai.get("damage", 10))
		var kb := float(ai.get("knockback_m", 1.5))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb, hit_id_counter)
		arena.register_enemy_hit(player, dir)
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("enemy_hit_shake", 0.2)))

## 抓取型 AI（fatty）。
func _ai_grapple(dt: float, arena: Node, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 1.0))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 1.6))
			set_state("walk")
		else:
			vx = 0.0
			set_state("windup")
			state_frames = 0
	elif state == "windup":
		vx = 0.0
		if state_frames >= int(ai.get("windup_frames", 20)):
			set_state("attack")
			state_frames = 0
			_do_grapple(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 12)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 24)):
			set_state("idle")
			state_frames = 0

## 执行抓取（Fatty 抓住玩家）。
func _do_grapple(arena: Node, dir: int) -> void:
	var hb := Rect2(global_position.x + dir * (half_width + 0.2), global_position.y - 0.4, 0.8, 0.8)
	if hb.intersects(player.hurtbox()) and not player.is_thrown:
		## 简化：抓取造成持续伤害并击退。
		var dmg := int(ai.get("damage", 6))
		var kb := float(ai.get("knockback_m", 0.5))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb, hit_id_counter)
		arena.register_enemy_hit(player, dir)

## 慢速重击 AI（swordsman）。
func _ai_slow_heavy(dt: float, arena: Node, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 1.1))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 1.4))
			set_state("walk")
		else:
			vx = 0.0
			set_state("windup")
			state_frames = 0
	elif state == "windup":
		vx = 0.0
		if state_frames >= int(ai.get("windup_frames", 24)):
			set_state("attack")
			state_frames = 0
			_do_enemy_attack(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 14)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 28)):
			set_state("idle")
			state_frames = 0

## 醉酒摇摆 AI（drunk）——含友伤。
func _ai_stagger(dt: float, arena: Node, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 0.8))
	## 随机摇摆方向。
	if state == "idle":
		facing = dir
		## 随机加入横向摇摆。
		if randf() < 0.05:
			vx = -vx
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 1.8)) * randf_range(0.5, 1.2)
			set_state("walk")
		else:
			vx = 0.0
			set_state("windup")
			state_frames = 0
	elif state == "windup":
		vx = randf_range(-0.5, 0.5)
		if state_frames >= int(ai.get("windup_frames", 16)):
			set_state("attack")
			state_frames = 0
			_do_enemy_attack_friendly(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 10)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 20)):
			set_state("idle")
			state_frames = 0

## 醉酒者攻击——可命中友军（友伤开关）。
func _do_enemy_attack_friendly(arena: Node, dir: int) -> void:
	var hb := Rect2(global_position.x + dir * (half_width + 0.3), global_position.y - 0.4, float(ai.get("attack_range_m", 0.8)), 0.8)
	## 先打玩家。
	if hb.intersects(player.hurtbox()):
		_deal_damage_to(player, dir, arena)
	## 友伤：也命中其他敌人。
	var ff := M2Data.friendly_fire_cfg()
	if ff.get("enemy_to_enemy", true):
		for e in arena.enemies:
			if e == self or e.is_dead:
				continue
			if hb.intersects(e.hurtbox()):
				_deal_damage_to(e, dir, arena)

## 统一伤害分发。
func _deal_damage_to(target: M2Actor, dir: int, arena: Node) -> void:
	var dmg := int(ai.get("damage", 8))
	var kb := float(ai.get("knockback_m", 1.0))
	hit_id_counter = _next_hit_id()
	target.take_damage(dmg, dir, kb, hit_id_counter)
	if target is M2Player:
		arena.register_enemy_hit(target, dir)
	else:
		arena.register_friendly_fire(self, target, dir)
	arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("enemy_hit_shake", 0.2)))

## 格挡反击 AI（flail）。
func _ai_block_counter(dt: float, arena: Node, abs_x: float, dir: int) -> void:
	var atk_range := float(ai.get("attack_range_m", 0.9))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai.get("speed_mps", 1.6))
			set_state("walk")
		else:
			vx = 0.0
			## 高概率格挡。
			if randf() < 0.6:
				is_blocking = true
				block_frames = 12
				set_state("block")
			else:
				set_state("windup")
				state_frames = 0
	elif state == "block":
		vx = 0.0
		if block_frames <= 0:
			## 格挡结束后反击。
			set_state("attack")
			state_frames = 0
			_do_counter(arena, dir)
	elif state == "windup":
		vx = 0.0
		if state_frames >= int(ai.get("windup_frames", 18)):
			set_state("attack")
			state_frames = 0
			_do_enemy_attack(arena, dir)
	elif state == "attack":
		if state_frames >= int(ai.get("attack_frames", 10)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		if state_frames >= int(ai.get("recover_frames", 22)):
			set_state("idle")
			state_frames = 0

## 格挡反击：格挡成功后的额外伤害。
func _do_counter(arena: Node, dir: int) -> void:
	var hb := Rect2(global_position.x + dir * (half_width + 0.3), global_position.y - 0.4, float(ai.get("attack_range_m", 0.9)), 0.8)
	if hb.intersects(player.hurtbox()):
		var dmg := int(ai.get("damage", 12))
		var kb := float(ai.get("knockback_m", 2.0))
		var gb := float(ai.get("getup_knockback", 1.5))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb + gb, hit_id_counter)
		arena.register_enemy_hit(player, dir)
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("heavy_hit_shake", 0.4)))

## 全局命中 id 递增。
func _next_hit_id() -> int:
	_hit_id += 1
	return _hit_id

## 重置敌人。
func reset_enemy() -> void:
	attack_done = false
	ranged_cooldown = 0
	can_block = false
	is_blocking = false
	backoff_timer = 0
	reset_actor()
