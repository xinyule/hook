## M4 Boss 基类与 BUTCHER / JASON 招式状态机。
## 继承 M2Actor 接口（受击 / 投掷 / 倒地 / 命中停顿），接入 M3 敌人管线
## （加入 arena.enemies 后由主场景逐帧 tick，玩家攻击判定自动覆盖）。
## 招式帧表与 AI 参数全部来自 data/bosses_m4.json，不硬编码。
extends M2Actor
class_name M4Boss

signal defeat_sequence_started
signal defeat_sequence_finished

var boss_id: String = ""
var boss_cfg: Dictionary = {}
var ai_cfg: Dictionary = {}
var moves_cfg: Dictionary = {}
var player: M2Player = null

## 当前招式名（windup/attack/recover 期间有效）。
var state_move: String = ""
## 阶段（JASON 半血进入阶段 2）。
var phase: int = 1
## 铁球召唤计时（帧）。
var iron_ball_timer: int = 0
## 击败演出。
var defeat_timer: int = 0
var defeat_type: String = ""
var _defeat_started: bool = false
## 卖血窗口（BUTCHER 被投到右墙起身后的空挡，帧）。
var sell_blood_window: int = 0

## 初始化 Boss。arena 用于演出与铁球召唤。
func setup_boss(id: String, spawn_x: float, arena) -> void:
	boss_id = id
	boss_cfg = M4Data.boss(id)
	if boss_cfg.is_empty():
		push_error("[M4Boss] missing boss data: %s" % id)
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
	cap.height = float(boss_cfg.get("visual_height", 1.7))
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
		_tick_defeat()
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

## 倒地状态：等待起身（起身后空砍一刀）。
func _handle_downed() -> void:
	if knockdown_frames <= 0:
		is_downed = false
		set_state("getup")
		state_frames = 0

## 撞墙回调：BUTCHER 在右墙触发卖血窗口。
func on_wall_hit() -> void:
	vx = 0.0
	var sb: Dictionary = ai_cfg.get("sell_blood", {})
	if boss_id == "boss_01" and sb.get("enabled", false) and global_position.x > 0.0:
		sell_blood_window = int(sb.get("window_frames", 30))

## 受击：卖血窗口内伤害倍率；致死进入击败演出。
func take_damage(dmg: int, src_facing: int, knockback: float, hit_id: int) -> bool:
	if sell_blood_window > 0 and not is_dead:
		var mult := float(ai_cfg.get("sell_blood", {}).get("damage_multiplier", 1.5))
		dmg = int(dmg * mult)
		sell_blood_window = 0
	var ok := super.take_damage(dmg, src_facing, knockback, hit_id)
	if hp <= 0 and not _defeat_started:
		_start_defeat()
	return ok

## 开始击败演出：演出期间不真正死亡，演出结束才 is_dead。
func _start_defeat() -> void:
	_defeat_started = true
	is_dead = false
	defeat_type = boss_cfg.get("defeat_sequence", {}).get("type", "")
	defeat_timer = int(boss_cfg.get("defeat_sequence", {}).get("peck_duration_frames", 120))
	defeat_sequence_started.emit()

## 立即终结击败演出（铁球压死用）。
func finish_defeat() -> void:
	if _defeat_started:
		defeat_timer = 0

## 击败演出帧推进。
## 修复：发射信号后清零 _defeat_started，避免信号每帧重复触发。
func _tick_defeat() -> void:
	defeat_timer -= 1
	if defeat_timer <= 0:
		is_dead = true
		_defeat_started = false
		defeat_sequence_finished.emit()

## 蜂窝连锁：被带蜂窝的玩家投出时触发（放鞭炮演出，可秒 / 打掉一管多）。
## 返回本次伤害；返回 0 表示未触发。
func apply_honeycomb_damage(arena) -> int:
	var chain: Dictionary = boss_cfg.get("honeycomb_chain", {})
	if not chain.get("enabled", false) or _defeat_started:
		return 0
	var dmg := int(float(max_hp) * float(chain.get("damage_percent_of_max_hp", 20)) / 100.0)
	hp -= dmg
	## 多人免疫：两名及以上玩家在场时不死（原作「双人及以上打不死」）。
	if chain.get("two_player_immune", true) and hp <= 0:
		var alive := 0
		var pm: M3PlayerManager = arena.player_manager
		if pm != null:
			alive = pm.active_players().size()
		if alive >= 2:
			hp = 1
	if hp <= 0:
		_start_defeat()
	return dmg

## AI 主逻辑分派。
func _ai_tick(dt: float, arena) -> void:
	## JASON 半血切换铁球阶段（在 player 检查前执行，确保无玩家时也能切换）。
	if boss_id == "boss_02" and phase == 1:
		if hp <= int(float(max_hp) * float(ai_cfg.get("phase_2_hp_percent", 50)) / 100.0):
			phase = 2
			iron_ball_timer = int(ai_cfg.get("iron_ball", {}).get("summon_interval_frames", 180))
	## JASON 铁球阶段：定时召唤大铁球（不依赖玩家，用当前位置作为落点）。
	if boss_id == "boss_02" and phase == 2:
		iron_ball_timer -= 1
		if iron_ball_timer <= 0:
			iron_ball_timer = int(ai_cfg.get("iron_ball", {}).get("summon_interval_frames", 180))
			var target_x: float = global_position.x
			if player != null and not player.is_dead:
				target_x = player.global_position.x
			arena.spawn_iron_ball(target_x)
	if player == null or player.is_dead:
		return
	var dist_x: float = player.global_position.x - global_position.x
	var dir: int = 1 if dist_x > 0 else -1
	if boss_id == "boss_01":
		_ai_butcher(arena, abs(dist_x), dir)
	elif boss_id == "boss_02":
		_ai_jason(arena, dist_x, abs(dist_x), dir)

## 开始招式：进入 windup。
func _begin_move(name: String) -> void:
	state_move = name
	set_state("windup")
	state_frames = 0

## 全局命中 id 递增（走 M2Actor 全局发号，跨攻击者唯一）。
func _next_hit_id() -> int:
	return M2Actor.next_hit_id()

## 执行招式命中判定。
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

## BUTCHER AI：接近 → 挥砍；倒地起身后空砍一刀；右墙卖血。
func _ai_butcher(arena, abs_x: float, dir: int) -> void:
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.0))
	if state == "idle":
		facing = dir
		if sell_blood_window > 0:
			sell_blood_window -= 1
		if abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.6))
			set_state("walk")
		else:
			vx = 0.0
			_begin_move("chop")
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			_begin_move("chop")
	elif state == "getup":
		vx = 0.0
		## 起身后空砍一刀再恢复（原作「击倒后空砍一刀再起身」）。
		if state_frames >= int(ai_cfg.get("getup_frames", 24)):
			_begin_move("getup_swing")
	elif state == "windup":
		vx = 0.0
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
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 20)):
			set_state("idle")
			state_frames = 0

## JASON AI：接近 → 铁管挥舞 / 近身抓敲；半血阶段在 _ai_tick 中切换，此处定时召唤铁球。
func _ai_jason(arena, dist_x: float, abs_x: float, dir: int) -> void:
	var atk_range: float = float(ai_cfg.get("attack_range_m", 1.3))
	if state == "idle":
		facing = dir
		if abs_x > atk_range:
			vx = dir * float(ai_cfg.get("approach_speed_mps", 1.2))
			set_state("walk")
		else:
			vx = 0.0
			## 贴脸时抓人用铁管敲（高伤招式）。
			if abs_x < atk_range * 0.6:
				_begin_move("grab_bash")
			else:
				_begin_move("pipe_swing")
	elif state == "walk":
		if abs_x <= atk_range:
			vx = 0.0
			_begin_move("pipe_swing")
	elif state == "windup":
		vx = 0.0
		var mv: Dictionary = moves_cfg.get(state_move, {})
		if state_frames >= int(mv.get("windup_frames", 18)):
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
		if state_frames >= int(moves_cfg.get(state_move, {}).get("recover_frames", 24)):
			set_state("idle")
			state_frames = 0
	## 铁球召唤逻辑已移至 _ai_tick，此处不再重复。
