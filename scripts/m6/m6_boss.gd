## M6 Boss 基类与 SMEE / HOOK 招式状态机。
## 继承 M2Actor 接口（受击 / 投掷 / 倒地 / 命中停顿），接入 M3 敌人管线
## （加入 arena.enemies 后由主场景逐帧 tick，玩家攻击判定自动覆盖）。
## 招式帧表与 AI 参数全部来自 data/bosses_m6.json，不硬编码。
extends M2Actor
class_name M6Boss

signal defeat_sequence_started
signal defeat_sequence_finished

var boss_id: String = ""
var boss_cfg: Dictionary = {}
var ai_cfg: Dictionary = {}
var moves_cfg: Dictionary = {}
var player: M2Player = null

## 当前招式名（windup/attack/recover 期间有效）。
var state_move: String = ""
## 影子预警剩余帧。
var shadow_warning: int = 0
## 击败演出。
var defeat_timer: int = 0
var defeat_type: String = ""
var _defeat_started: bool = false
## HOOK 阶段（1/2/3）。
var phase: int = 1
## 炮台三连发 / 杂兵刷新定时器（帧）。
var cannon_timer: int = 0
var adds_timer: int = 0
## 叩头禁跳打窗口剩余帧（SMEE）。
var anti_jump_window: int = 0
## 阶段切换标志（自测用）。
var phase_switched: bool = false

## 初始化 Boss。arena 用于演出、炮台与杂兵刷新。
func setup_boss(id: String, spawn_x: float, arena) -> void:
	boss_id = id
	boss_cfg = M6Data.boss(id)
	if boss_cfg.is_empty():
		push_error("[M6Boss] missing boss data: %s" % id)
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

## 被投掷落地处理。
func _check_throw_land(arena) -> void:
	if on_floor:
		_finish_throw()
		arena.trigger_screen_shake(float(M2Data.vfx_cfg().get("throw_land_shake", 0.3)))

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

## 开始招式：进入 windup（带影子预警）。
func _begin_move(name: String) -> void:
	state_move = name
	shadow_warning = int(ai_cfg.get("shadow_warning_frames", 16))
	set_state("windup")
	state_frames = 0

## AI 主逻辑分派。
func _ai_tick(dt: float, arena) -> void:
	## HOOK 阶段切换与杂兵刷新（在 player 检查前执行）。
	if boss_id == "boss_06":
		_tick_hook_phases(arena)
	## 炮台三连发定时（SMEE）。
	if boss_id == "boss_05":
		cannon_timer -= 1
		if cannon_timer <= 0:
			cannon_timer = int(ai_cfg.get("cannon_triple_interval_frames", 300))
			_fire_cannon_triple(arena)
	if player == null or player.is_dead:
		return
	var dist_x: float = player.global_position.x - global_position.x
	var dir: int = 1 if dist_x > 0 else -1
	if boss_id == "boss_05":
		_ai_smee(arena, abs(dist_x), dir)
	elif boss_id == "boss_06":
		_ai_hook(arena, dist_x, abs(dist_x), dir)

## HOOK 三阶段切换：半血进阶段 2（召唤杂兵），低血进阶段 3（冲撞）。
func _tick_hook_phases(arena) -> void:
	if phase == 1 and hp <= int(float(max_hp) * float(ai_cfg.get("phase_2_hp_percent", 60)) / 100.0):
		phase = 2
		adds_timer = int(ai_cfg.get("adds_refresh_interval_frames", 240))
		phase_switched = true
	if phase == 2:
		adds_timer -= 1
		if adds_timer <= 0:
			adds_timer = int(ai_cfg.get("adds_refresh_interval_frames", 240))
			arena.spawn_hook_adds(int(ai_cfg.get("adds_max_onscreen", 4)))
	if phase == 2 and hp <= int(float(max_hp) * float(ai_cfg.get("phase_3_hp_percent", 30)) / 100.0):
		phase = 3
		phase_switched = true

## SMEE 发射炮台三连发（远程三连射击，委托 arena）。
func _fire_cannon_triple(arena) -> void:
	var mv: Dictionary = moves_cfg.get("cannon_triple", {})
	arena.spawn_cannon_triple(global_position.x, -facing, float(mv.get("range_m", 7.0)), int(mv.get("damage", 10)), float(mv.get("knockback_m", 1.2)))

## SMEE AI：接近 → 叩头（禁跳打）/ 挥砍。
func _ai_smee(arena, abs_x: float, dir: int) -> void:
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.1))
	## 叩头禁跳打窗口递减。
	if anti_jump_window > 0:
		anti_jump_window -= 1
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.6))
			set_state("walk")
		else:
			vx = 0.0
			## 叩头（伏地，触发禁跳打窗口）。
			_begin_move("kowtow")
			anti_jump_window = int(ai_cfg.get("anti_jump_window_frames", 40))
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			_begin_move("kowtow")
			anti_jump_window = int(ai_cfg.get("anti_jump_window_frames", 40))
	elif state == "windup":
		vx = 0.0
		if shadow_warning > 0:
			shadow_warning -= 1
		var mv: Dictionary = moves_cfg.get(state_move, {})
		if state_frames >= int(mv.get("windup_frames", 16)):
			set_state("attack")
			state_frames = 0
			_do_attack(arena, dir, mv)
	elif state == "attack":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("active_frames", 10)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 28)):
			set_state("idle")
			state_frames = 0

## HOOK AI：阶段 1 剑击；阶段 2 钩击 + 杂兵；阶段 3 冲撞。
func _ai_hook(arena, dist_x: float, abs_x: float, dir: int) -> void:
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.3))
	if state == "idle":
		facing = dir
		if phase == 3:
			## 阶段 3 冲撞。
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.8)) * 1.5
			set_state("charge")
		elif abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.8))
			set_state("walk")
		else:
			vx = 0.0
			if phase >= 2:
				_begin_move("hook")
			else:
				_begin_move("sword")
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			if phase >= 2:
				_begin_move("hook")
			else:
				_begin_move("sword")
	elif state == "charge":
		## 冲撞持续移动并命中。
		vx = facing * float(ai_cfg.get("approach_speed_mps", 1.8)) * 1.5
		var mv: Dictionary = moves_cfg.get("charge", {})
		var hb := Rect2(global_position.x + facing * (half_width + float(mv.get("reach_m", 2.0)) * 0.5), global_position.y - 0.4, float(mv.get("reach_m", 2.0)), 0.8)
		if hb.intersects(player.hurtbox()):
			var dmg: int = int(mv.get("damage", 20))
			hit_id_counter = _next_hit_id()
			player.take_damage(dmg, facing, float(mv.get("knockback_m", 3.0)), hit_id_counter)
			arena.register_enemy_hit(player, facing)
		## 修复：state_frames 已由 tick_state 每帧自增，不再手动 +1（原实现导致冲撞时长减半）。
		if state_frames >= 40:
			set_state("recover")
			state_frames = 0
	elif state == "windup":
		vx = 0.0
		if shadow_warning > 0:
			shadow_warning -= 1
		var mv2: Dictionary = moves_cfg.get(state_move, {})
		if state_frames >= int(mv2.get("windup_frames", 14)):
			set_state("attack")
			state_frames = 0
			_do_attack(arena, dir, mv2)
	elif state == "attack":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("active_frames", 8)):
			set_state("recover")
			state_frames = 0
	elif state == "recover":
		vx = 0.0
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 26)):
			set_state("idle")
			state_frames = 0
