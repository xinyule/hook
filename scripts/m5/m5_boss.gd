## M5 Boss 基类与 DAMON / 假 Hook 招式状态机。
## 继承 M2Actor 接口（受击 / 投掷 / 倒地 / 命中停顿），接入 M3 敌人管线
## （加入 arena.enemies 后由主场景逐帧 tick，玩家攻击判定自动覆盖）。
## 招式帧表与 AI 参数全部来自 data/bosses_m5.json，不硬编码。
extends M2Actor
class_name M5Boss

signal defeat_sequence_started
signal defeat_sequence_finished

var boss_id: String = ""
var boss_cfg: Dictionary = {}
var ai_cfg: Dictionary = {}
var moves_cfg: Dictionary = {}
var player: M2Player = null

## 当前招式名（windup/attack/recover 期间有效）。
var state_move: String = ""
## 影子预警剩余帧（DAMON 攻击前投影子提示）。
var shadow_warning: int = 0
## 击败演出。
var defeat_timer: int = 0
var defeat_type: String = ""
var _defeat_started: bool = false
## 气功波飞行道具状态（DAMON）。
var ki_wave_active: bool = false
var ki_wave_x: float = 0.0
var ki_wave_dir: int = 1
## 冰柱召唤计数（DAMON）。
var ice_pillar_count: int = 0
## 气功波 / 冰柱定时器（帧）。
var ki_wave_timer: int = 0
var ice_pillar_timer: int = 0

## 初始化 Boss。arena 用于演出、气功波与冰柱召唤。
func setup_boss(id: String, spawn_x: float, arena) -> void:
	boss_id = id
	boss_cfg = M5Data.boss(id)
	if boss_cfg.is_empty():
		push_error("[M5Boss] missing boss data: %s" % id)
		return
	ai_cfg = boss_cfg.get("ai", {})
	moves_cfg = boss_cfg.get("moves", {})
	actor_id = id
	set_spawn(spawn_x)
	## Boss 不在 M2Data.character / enemy 中，手工装配战斗属性。
	max_hp = int(boss_cfg.get("hp", 300))
	hp = max_hp
	half_width = float(boss_cfg.get("half_width", 0.5))
	facing = -1  ## 从画面右侧登场，面朝左。
	global_position = Vector3(spawn_x, 0.0, 0.0)
	if not M2Data.logic_only:
		_build_boss_visual()

## 构建 Boss 视觉占位（胶囊 + Boss 配色）。
func _build_boss_visual() -> void:
	_visual = Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = half_width
	cap.height = float(boss_cfg.get("visual_height", 1.8))
	body.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(boss_cfg.get("color", Color.WHITE))
	body.material_override = mat
	_visual.add_child(body)
	add_child(_visual)

## 每帧 AI 主循环（接口与 M2Enemy.tick 一致）。
func tick(dt: float, arena) -> void:
	tick_state()
	if is_thrown:
		integrate(dt)
		_check_throw_land(arena)
		return
	if _defeat_started:
		_tick_defeat(arena)
		integrate(dt)
		return
	if is_dead:
		return
	if is_downed:
		_handle_downed()
		integrate(dt)
		return
	_ai_tick(dt, arena)
	integrate(dt)

## 被投掷落地处理。假 Hook 互投：落地对范围内敌我造成伤害。
func _check_throw_land(arena) -> void:
	if on_floor:
		_finish_throw()
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("throw_land_shake", 0.3)))
		if boss_cfg.get("is_fake", false):
			_fake_hook_throw_damage(arena)

## 假 Hook 被投出落地：对范围内敌我造成投掷伤害（互投）。
func _fake_hook_throw_damage(arena) -> void:
	var fcfg: Dictionary = M5Data.fake_hook_cfg()
	var radius: float = float(fcfg.get("throw_land_radius_m", 1.2))
	var dmg: int = int(fcfg.get("throw_damage", 18))
	var kb: float = float(fcfg.get("throw_knockback_m", 2.5))
	## 伤害范围内其他假 Hook / 敌人（互投），不伤及投掷者（由 arena 传入标记）。
	for e in arena.enemies:
		if e == self or not is_instance_valid(e) or e.is_dead:
			continue
		if abs(e.global_position.x - global_position.x) <= radius:
			var dir: int = 1 if global_position.x >= e.global_position.x else -1
			e.take_damage(dmg, dir, kb, _next_hit_id())

## 倒地状态：等待起身。
func _handle_downed() -> void:
	if knockdown_frames <= 0:
		is_downed = false
		set_state("idle")
		state_frames = 0

## 受击：致死进入击败演出。
func take_damage(dmg: int, src_facing: int, knockback: float, hit_id: int) -> bool:
	var ok := super.take_damage(dmg, src_facing, knockback, hit_id)
	if hp <= 0 and not _defeat_started:
		_start_defeat()
	return ok

## 开始击败演出：演出期间不真正死亡，演出结束才 is_dead。
func _start_defeat() -> void:
	_defeat_started = true
	is_dead = false
	defeat_type = boss_cfg.get("defeat_sequence", {}).get("type", "")
	defeat_timer = int(boss_cfg.get("defeat_sequence", {}).get("duration_frames", 90))
	defeat_sequence_started.emit()

## 立即终结击败演出。
func finish_defeat() -> void:
	if _defeat_started:
		defeat_timer = 0

## 击败演出帧推进。
## 修复：发射信号后清零 _defeat_started，避免信号每帧重复触发。
func _tick_defeat(arena) -> void:
	defeat_timer -= 1
	if defeat_timer <= 0:
		is_dead = true
		_defeat_started = false
		defeat_sequence_finished.emit()

## 全局命中 id 递增（走 M2Actor 全局发号，跨攻击者唯一）。
func _next_hit_id() -> int:
	return M2Actor.next_hit_id()

## 执行招式命中判定（近身）。
func _do_attack(arena, dir: int, mv: Dictionary) -> void:
	var reach: float = float(mv.get("reach_m", 1.0))
	var hb := Rect2(global_position.x + dir * (half_width + reach * 0.5), global_position.y - 0.4, reach, 0.8)
	if hb.intersects(player.hurtbox()):
		var dmg: int = int(mv.get("damage", 12))
		var kb: float = float(mv.get("knockback_m", 1.5))
		hit_id_counter = _next_hit_id()
		player.take_damage(dmg, dir, kb, hit_id_counter)
		arena.register_enemy_hit(player, dir)
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("enemy_hit_shake", 0.2)))

## 开始招式：进入 windup（DAMON 带影子预警）。
func _begin_move(name: String) -> void:
	state_move = name
	if boss_id == "boss_04":
		shadow_warning = int(ai_cfg.get("shadow_warning_frames", 18))
	set_state("windup")
	state_frames = 0

## AI 主逻辑分派。
func _ai_tick(dt: float, arena) -> void:
	if player == null or player.is_dead:
		return
	var dist_x: float = player.global_position.x - global_position.x
	var dir: int = 1 if dist_x > 0 else -1
	if boss_id == "boss_03":
		_ai_fake_hook(arena, abs(dist_x), dir)
	elif boss_id == "boss_04":
		_ai_damon(arena, dist_x, abs(dist_x), dir)

## 假 Hook AI：接近 → 挥砍；可被投出互投。
func _ai_fake_hook(arena, abs_x: float, dir: int) -> void:
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.0))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.8))
			set_state("walk")
		else:
			vx = 0.0
			_begin_move("slash")
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			_begin_move("slash")
	elif state == "windup":
		vx = 0.0
		if shadow_warning > 0:
			shadow_warning -= 1
		var mv: Dictionary = moves_cfg.get(state_move, {})
		if state_frames >= int(mv.get("windup_frames", 12)):
			set_state("attack")
			state_frames = 0
			_do_attack(arena, dir, mv)
	elif state == "attack":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("active_frames", 6)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 22)):
			set_state("idle")
			state_frames = 0

## DAMON AI：接近 → 踢击；定时气功波 / 冰柱当墙；影子预警。
func _ai_damon(arena, dist_x: float, abs_x: float, dir: int) -> void:
	## 气功波定时发射（不依赖近身）。
	ki_wave_timer -= 1
	if ki_wave_timer <= 0:
		ki_wave_timer = int(ai_cfg.get("ki_wave_interval_frames", 240))
		_fire_ki_wave(arena, dir)
	## 冰柱定时召唤。
	ice_pillar_timer -= 1
	if ice_pillar_timer <= 0:
		ice_pillar_timer = int(ai_cfg.get("ice_pillar_interval_frames", 300))
		_summon_ice_pillar(arena)
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.2))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.5))
			set_state("walk")
		else:
			vx = 0.0
			_begin_move("kick")
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			_begin_move("kick")
	elif state == "windup":
		vx = 0.0
		if shadow_warning > 0:
			shadow_warning -= 1
		var mv: Dictionary = moves_cfg.get(state_move, {})
		if state_frames >= int(mv.get("windup_frames", 14)):
			set_state("attack")
			state_frames = 0
			_do_attack(arena, dir, mv)
	elif state == "attack":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("active_frames", 8)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 22)):
			set_state("idle")
			state_frames = 0

## 发射气功波（飞行道具）。逻辑层记录位置与方向，由 arena 结算命中。
func _fire_ki_wave(arena, dir: int) -> void:
	var mv: Dictionary = moves_cfg.get("ki_wave", {})
	ki_wave_active = true
	ki_wave_x = global_position.x
	ki_wave_dir = dir
	arena.spawn_ki_wave(ki_wave_x, dir, float(mv.get("range_m", 6.0)), int(mv.get("damage", 14)), float(mv.get("knockback_m", 1.5)))

## 召唤冰柱当墙（可踩反跳）。委托 arena 生成。
func _summon_ice_pillar(arena) -> void:
	ice_pillar_count += 1
	arena.spawn_ice_pillar(global_position.x + facing * 2.0)

## 气功波是否激活（自测用）。
func is_ki_wave_active() -> bool:
	return ki_wave_active
