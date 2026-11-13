## M3 主场景控制器。
## 职责：关卡段落流式加载、波次生成、1-4P 玩家管理、TIME + 飞鹰、
## 计分与隐藏宝藏、HUD 显示、周目回环、正交相机跟随、headless 自测。
## 复用 M2 战斗核心（M2Actor/M2Player/M2Enemy/M2Data 不改），
## M3 只做框架与系统层。所有数值来自 data/*.json，不硬编码。
extends Node3D
class_name M3Arena

## ---- 场景对象 ----
var camera: Camera3D = null
var world_root: Node3D = null
var hud: M3Hud = null

## ---- M3 系统 ----
var stage_runner: M3StageRunner = null
var wave_director: M3WaveDirector = null
var player_manager: M3PlayerManager = null
var timer: M3Timer = null
var score: M3Score = null

## ---- 战斗核心兼容（M2 接口）----
var enemies: Array = []           ## M2 战斗核心遍历此数组
var player: M2Player = null       ## 主玩家引用（兼容 M2 接口）
var half_width: float = 7.6

## ---- 周目管理 ----
var current_stage_index: int = 0
var loop_count: int = 0
var ruleset_name: String = "arcade"
var ruleset: Dictionary = {}
var _loading_stage: bool = false

## ---- 自测 ----
var selftest: bool = false
var frame_count: int = 0

## ---- 特效 ----
var shake_offset: Vector2 = Vector2.ZERO
var shake_timer: float = 0.0
var shake_amp: float = 0.0

## 场景半宽。
func _box() -> float:
	return float(M2Data.m2_base().get("screen_half_width", half_width))

## 初始化。
func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	M3Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 注册 M2 兼容输入动作 + M3 多玩家输入动作。
func _ensure_input_actions() -> void:
	## M2 兼容动作（单人测试用）。
	var m2_actions := ["m2_left", "m2_right", "m2_up", "m2_down", "m2_a", "m2_b"]
	var dir_keys := {"m2_left": KEY_A, "m2_right": KEY_D, "m2_up": KEY_W, "m2_down": KEY_S}
	var act_keys := {"m2_a": KEY_J, "m2_b": KEY_K}
	for a in m2_actions:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		if a in dir_keys:
			var ev := InputEventKey.new()
			ev.keycode = dir_keys[a]
			ev.ctrl_pressed = true
			InputMap.action_add_event(a, ev)
		if a in act_keys:
			var ev2 := InputEventKey.new()
			ev2.keycode = act_keys[a]
			InputMap.action_add_event(a, ev2)
	## M3 多玩家输入动作由 PlayerManager 注册。
	player_manager_pre_register()

## 在系统构建前预注册输入（PlayerManager 尚未创建，单独调用）。
func player_manager_pre_register() -> void:
	var pm: M3PlayerManager = M3PlayerManager.new()
	pm.register_input_actions()
	pm.free()

## 构建世界灰盒（地面、边界墙、正交相机）。
func _build_world() -> void:
	world_root = Node3D.new()
	add_child(world_root)
	if M2Data.logic_only:
		return
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_box() * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.25, 0.3)
	floor.material_override = fmat
	floor.position = Vector3(0.0, 0.0, 0.0)
	world_root.add_child(floor)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.3, 0.2)
	for side in [-1, 1]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 4.0, 3.0)
		wall.mesh = box
		wall.material_override = wall_mat
		wall.position = Vector3(side * _box(), 2.0, 0.0)
		world_root.add_child(wall)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 3.0, 6.0)
	camera.size = _box() * 2.0
	add_child(camera)
	camera.look_at(Vector3.ZERO)

## 构建 M3 各系统并连接信号。
func _build_systems() -> void:
	ruleset = M3Data.ruleset(ruleset_name)
	## 关卡推进器。
	stage_runner = M3StageRunner.new()
	add_child(stage_runner)
	## 波次导演。
	wave_director = M3WaveDirector.new()
	add_child(wave_director)
	## 玩家管理器。
	player_manager = M3PlayerManager.new()
	add_child(player_manager)
	var credit: Dictionary = ruleset.get("CreditSystem", {})
	var start_lives := int(credit.get("start_lives", 3))
	player_manager.setup(start_lives, -_box() * 0.4)
	## 计时器。
	timer = M3Timer.new()
	add_child(timer)
	timer.configure(ruleset)
	## 计分。
	score = M3Score.new()
	add_child(score)
	score.configure(ruleset, M2Data.balance())
	## HUD。
	hud = M3Hud.new()
	add_child(hud)
	## 连接信号。
	wave_director.segment_cleared.connect(_on_segment_cleared)
	## 波次导演需要引用 arena 与 player_manager。
	wave_director.setup(self, player_manager)

## 开始游戏：加载第一关。
func _start_game() -> void:
	current_stage_index = 0
	loop_count = 0
	score.set_loop(0)
	_load_stage(current_stage_index)

## 加载指定索引的关卡。
func _load_stage(index: int) -> void:
	_loading_stage = true
	var order: Array = M3Data.stage_order()
	if index >= order.size():
		index = 0
	current_stage_index = index
	var sid: String = order[index]
	stage_runner.load_stage(sid)
	## 清空旧敌人。
	_clear_enemies()
	## 加载当前段波次。
	_load_segment_waves()
	## 重置计时器。
	timer.reset()
	## 生成默认 P1（若尚未加入）。
	if player_manager.all_players().is_empty():
		var heroes: Array = M2Data.characters().get("characters", [])
		if not heroes.is_empty():
			player_manager.join_player(0, heroes[0].get("id", "hero_01"))
	## 更新主玩家引用（兼容 M2 接口）。
	var all: Array = player_manager.all_players()
	if not all.is_empty():
		player = all[0]
	_loading_stage = false

## 加载当前段的波次到波次导演。空波次不触发信号（加载期间由 _loading_stage 抑制）。
func _load_segment_waves() -> void:
	var waves: Array = stage_runner.segment_waves()
	if waves.is_empty():
		return
	var sx: float = _box() * 0.6
	wave_director.load_waves(waves, sx, -1)

## 段落清空回调：推进段落，若末段则关卡完成。
## M3 阶段波次为空，用循环处理连续空段落，避免递归栈溢出。
func _on_segment_cleared() -> void:
	if _loading_stage:
		return
	while true:
		if not stage_runner.advance_segment():
			_on_stage_complete()
			return
		var waves: Array = stage_runner.segment_waves()
		if waves.is_empty():
			continue  ## 空波次直接推进下一段
		_load_segment_waves()
		return

## 关卡完成：推进下一关或回环。
func _on_stage_complete() -> void:
	var order: Array = M3Data.stage_order()
	current_stage_index += 1
	if current_stage_index >= order.size():
		## 末关通关 → 周目 +1，回 stage_01。
		current_stage_index = 0
		loop_count += 1
		score.set_loop(loop_count)
	_load_stage(current_stage_index)

## 清空所有敌人。
func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	wave_director.reset()

## 物理帧（实际运行时）。
func _physics_process(dt: float) -> void:
	if selftest:
		return
	simulate_tick(dt)

## 模拟一帧（自测与运行时共用）。
func simulate_tick(dt: float) -> void:
	frame_count += 1
	## 屏幕震动衰减。
	if shake_timer > 0.0:
		shake_timer -= dt
		if shake_timer <= 0.0:
			shake_amp = 0.0
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2(randf_range(-shake_amp, shake_amp), randf_range(-shake_amp, shake_amp))
	## 玩家输入与推进。
	player_manager.read_inputs()
	player_manager.tick(dt, self)
	## 玩家攻击/抓取帧推进。
	for p in player_manager.all_players():
		if p.is_dead or not is_instance_valid(p):
			continue
		if p.state in ["Attack1", "Attack2", "Attack3", "Attack4", "Special", "Heavy", "jump_attack"]:
			p._advance_attack(self)
		if p.state == "grab":
			p._advance_grab(self)
	## 波次推进。
	wave_director.tick(dt)
	## 敌人推进。
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			e.tick(dt, self)
			_clamp_actor(e)
	## 计时器。
	timer.tick(dt, self, player_manager)
	## 隐藏宝藏检测。
	_check_hidden_points()
	## 清理死亡敌人。
	_cleanup_dead()
	## 相机与 HUD。
	_update_camera()
	if hud != null:
		hud.update(player_manager, timer, score, stage_runner)

## 钳制角色在场景边界内（M2 兼容接口）。
func _clamp_actor(actor: M2Actor) -> void:
	var lim := _box() - actor.half_width
	var x := actor.global_position.x
	if x > lim:
		x = lim
		if actor.vx > 0.0:
			actor.on_wall_hit()
	elif x < -lim:
		x = -lim
		if actor.vx < 0.0:
			actor.on_wall_hit()
	actor.global_position = Vector3(x, maxf(actor.global_position.y, 0.0), 0.0)

## 清理死亡敌人（延迟移除，通知波次导演）。
func _cleanup_dead() -> void:
	var to_remove := []
	for e in enemies:
		if e.is_dead and e.state_frames > 30:
			to_remove.append(e)
	for e in to_remove:
		enemies.erase(e)
		wave_director.on_enemy_removed(e)
		if is_instance_valid(e):
			e.queue_free()

## 隐藏宝藏检测：玩家靠近隐藏点则计分（去重）。
func _check_hidden_points() -> void:
	var points: Array = stage_runner.segment_hidden_points()
	for pt in points:
		var pid: String = pt.get("id", "")
		if pid.is_empty() or score.has_hidden_point(pid):
			continue
		var px: float = float(pt.get("x", 0.0))
		var py: float = float(pt.get("y", 0.0))
		for p in player_manager.active_players():
			var dx: float = p.global_position.x - px
			var dy: float = p.global_position.y - py
			if dx * dx + dy * dy <= 1.5 * 1.5:
				score.add_hidden_point(pid)
				break

## ---- M2 战斗核心兼容接口 ----

func register_hit(target: M2Actor, dir: int, dmg_mult: float = 1.0) -> void:
	var heavy := dmg_mult >= 2.0
	var vfx: Dictionary = M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, heavy)
	_trigger_shake(float(vfx.get("player_hit_shake" if not heavy else "heavy_hit_shake", 0.3)))

func register_enemy_hit(target: M2Actor, dir: int) -> void:
	var vfx: Dictionary = M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, true)
	_trigger_shake(float(vfx.get("enemy_hit_shake", 0.2)))

func register_friendly_fire(src: M2Actor, target: M2Actor, dir: int) -> void:
	var vfx: Dictionary = M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, false)
	_trigger_shake(float(vfx.get("friendly_fire_shake", 0.15)))

func trigger_screen_shake(amp: float) -> void:
	if amp > shake_amp:
		shake_amp = amp
	shake_timer = 0.2

func _trigger_shake(amp: float) -> void:
	trigger_screen_shake(amp)

func _spawn_hit_particles(pos: Vector3, heavy: bool) -> void:
	if M2Data.logic_only:
		return
	var vfx: Dictionary = M2Data.vfx_cfg()
	var count := int(vfx.get("hit_particles", 4))
	if heavy:
		count = int(vfx.get("heavy_particles", 8))
	for i in count:
		var p := Marker3D.new()
		var dx := randf_range(-1.0, 1.0)
		var dy := randf_range(-1.0, 1.0)
		p.position = Vector3(pos.x + dx * 0.2, pos.y + dy * 0.2, 0.5)
		world_root.add_child(p)
		var timer := Timer.new()
		timer.wait_time = 0.3
		timer.one_shot = true
		timer.start()
		p.add_child(timer)
		var cb := Callable(p, "queue_free")
		timer.connect("timeout", cb)

## 更新相机（跟随玩家质心，含震动偏移）。
func _update_camera() -> void:
	if camera == null:
		return
	var active: Array = player_manager.active_players()
	if active.is_empty():
		return
	var cx := 0.0
	for p in active:
		cx += p.global_position.x
	cx /= float(active.size())
	camera.position.x = cx + shake_offset.x
	camera.position.y = 3.0 + shake_offset.y

## 切换规则集（可插拔）。
func set_ruleset(name: String) -> void:
	ruleset_name = name
	ruleset = M3Data.ruleset(name)
	timer.configure(ruleset)
	score.configure(ruleset, M2Data.balance())
	var credit: Dictionary = ruleset.get("CreditSystem", {})
	var start_lives := int(credit.get("start_lives", 3))
	for i in player_manager.SLOT_COUNT:
		player_manager.lives[i] = start_lives

## ---- Headless 自测（38 项断言）----

func _check(cond: bool, label: String, results: Array, counters: Dictionary) -> void:
	if cond:
		counters["passed"] += 1
		results.append("PASS  %s" % label)
	else:
		counters["failed"] += 1
		results.append("FAIL  %s" % label)

func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}

	## 1. 关卡数据加载。
	stage_runner.load_stage("stage_01")
	_check(not stage_runner.stage_data.is_empty(), "关卡 stage_01 数据加载", results, counters)

	## 2. 段落数 >= 3。
	_check(stage_runner.segment_count() >= 3, "关卡段落数 >= 3", results, counters)

	## 3. 段落推进。
	var idx_before := stage_runner.current_index
	stage_runner.advance_segment()
	_check(stage_runner.current_index == idx_before + 1, "段落推进 current_index+1", results, counters)

	## 4. 末段 Boss 场标记。
	stage_runner.load_stage("stage_01")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_check(stage_runner.is_boss_segment(), "末段标记为 Boss 场", results, counters)

	## 5. 波次导演加载波次。
	stage_runner.load_stage("stage_01")
	wave_director.load_waves([{"id": "w1", "spawns": [{"enemy": "grunt", "count": 2}], "max_onscreen": 4}], 5.0, -1)
	_check(wave_director.is_active(), "波次导演加载波次后激活", results, counters)

	## 6. 波次生成敌人。
	wave_director.tick(0.016)
	_check(enemies.size() >= 1, "波次生成敌人(>=1)", results, counters)

	## 7. 同屏上限约束。
	_clear_enemies()
	wave_director.load_waves([{"id": "w1", "spawns": [{"enemy": "grunt", "count": 20}], "max_onscreen": 3}], 5.0, -1)
	wave_director.tick(0.016)
	_check(enemies.size() <= 3, "同屏敌人数受上限约束(<=3)", results, counters)

	## 8-11. 1-4P 同时加入。
	_clear_enemies()
	wave_director.reset()
	stage_runner.load_stage("stage_01")
	player_manager.setup(3, -3.0)
	_check(player_manager.join_player(0, "hero_01"), "P1 加入", results, counters)
	_check(player_manager.join_player(1, "hero_02"), "P2 加入", results, counters)
	_check(player_manager.join_player(2, "hero_03"), "P3 加入", results, counters)
	_check(player_manager.join_player(3, "hero_04"), "P4 加入(4手柄同时)", results, counters)

	## 12. 槽位占满拒绝。
	_check(not player_manager.join_player(0, "hero_05"), "槽位占满后拒绝加入", results, counters)

	## 13. 中途加入给起身无敌帧。
	_check(player_manager.players[1].invincible_frames > 0, "中途加入给起身无敌帧", results, counters)

	## 14. TIME 初始值 99。
	timer.configure(M3Data.arcade())
	_check(timer.initial_time == 99.0, "TIME 初始值 99", results, counters)

	## 15. TIME 递减。
	timer.time_value = 99.0
	timer.tick(1.0, self, player_manager)
	_check(timer.time_value < 99.0, "TIME 随时间递减", results, counters)

	## 16-18. 飞鹰触发、推距、扣血。
	timer.configure(M3Data.arcade())
	timer.time_value = 0.5
	timer.eagle_cooldown = 0.0
	var p0: M2Player = player_manager.players[0]
	p0.hp = p0.max_hp
	var px_before := p0.global_position.x
	var hp_before := p0.hp
	timer.tick(1.0, self, player_manager)
	_check(timer.eagle_state != "idle", "TIME 归零触发飞鹰", results, counters)
	_check(p0.global_position.x > px_before, "飞鹰推距(玩家前移)", results, counters)
	_check(p0.hp < hp_before, "飞鹰扣血(HP下降)", results, counters)

	## 19. 击杀计分。
	score.configure(M3Data.arcade(), M2Data.balance())
	score.reset()
	var kill_gain := score.add_kill(0)
	_check(kill_gain == 100, "击杀基础分 100", results, counters)

	## 20. 连击加分。
	score.reset()
	var combo_gain := score.add_kill(5)
	_check(combo_gain == 100 + 10 * 5, "连击加分(5连击=150)", results, counters)

	## 21. 宝藏计分。
	score.reset()
	var tr_gain := score.add_treasure()
	_check(tr_gain == 500, "宝藏基础分 500", results, counters)

	## 22-23. 隐藏点首次计分与去重。
	score.reset()
	var hp_gain1 := score.add_hidden_point("hp_01")
	var hp_gain2 := score.add_hidden_point("hp_01")
	_check(hp_gain1 == 1000, "隐藏点首次计分 1000", results, counters)
	_check(hp_gain2 == 0, "隐藏点去重(第二次0分)", results, counters)

	## 24. 周目倍率计算。
	score.reset()
	score.set_loop(1)
	_check(abs(score.current_multiplier() - 1.2) < 0.001, "周目倍率 1.2^1=1.2", results, counters)

	## 25. 周目倍率作用于得分。
	score.reset()
	score.set_loop(1)
	var loop_kill := score.add_kill(0)
	_check(loop_kill == int(100 * 1.2), "周目倍率作用于击杀分(120)", results, counters)

	## 26. 命数初始值。
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	_check(player_manager.lives[0] == 3, "命数初始值 3", results, counters)

	## 27. 命数消耗。
	player_manager.lives[0] = 3
	player_manager.on_player_death(0)
	_check(player_manager.lives[0] == 2, "死亡消耗命数(-1)", results, counters)

	## 28. 续关恢复。
	player_manager.lives[0] = 1
	player_manager.on_player_death(0)
	_check(player_manager._continue_slot == 0, "命数耗尽触发续关", results, counters)
	player_manager._continue_timer = 0.0
	player_manager.tick(0.016, self)
	_check(player_manager.lives[0] == 1 and not player_manager.players[0].is_dead, "续关恢复玩家", results, counters)

	## 29. HUD 控件齐备。
	_check(hud != null and hud.hp_bars.size() == 4, "HUD 4 条 HP 条齐备", results, counters)
	_check(hud != null and hud.time_bar != null, "HUD TIME 条齐备", results, counters)
	_check(hud != null and hud.score_label != null, "HUD 分数标签齐备", results, counters)

	## 30. HUD 逐帧更新。
	hud.update(player_manager, timer, score, stage_runner)
	_check(hud.score_label.text.begins_with("SCORE"), "HUD 逐帧更新分数文本", results, counters)

	## 31. 规则集 arcade 加载。
	var arcade_rs := M3Data.arcade()
	_check(arcade_rs.has("CreditSystem") and arcade_rs.has("LoopPolicy") and arcade_rs.has("TimePressure"), "规则集 arcade 三块齐备", results, counters)

	## 32. 规则集 session 加载。
	var session_rs := M3Data.session()
	_check(session_rs.has("CreditSystem") and session_rs.has("LoopPolicy"), "规则集 session 可加载", results, counters)

	## 33. 规则集可插拔切换。
	set_ruleset("session")
	_check(ruleset_name == "session", "规则集切换为 session", results, counters)
	set_ruleset("arcade")
	_check(ruleset_name == "arcade", "规则集切换回 arcade", results, counters)

	## 34. 数据驱动：HUD 配置读取。
	var hud_cfg := M3Data.hud_m3()
	_check(hud_cfg.has("hud") and hud_cfg.has("eagle") and hud_cfg.has("colors"), "HUD 配置数据驱动读取", results, counters)

	## 35. 数据驱动：balance 计分参数。
	var bal: Dictionary = M2Data.balance()
	var sc: Dictionary = bal.get("score", {})
	_check(int(sc.get("kill_base", 0)) == 100, "balance 计分参数 kill_base=100", results, counters)

	## 36. 换关推进（stage_01 → stage_02）。
	current_stage_index = 0
	_load_stage(0)
	stage_runner.load_stage("stage_01")
	## 模拟关卡完成。
	_on_stage_complete()
	_check(current_stage_index == 1, "换关推进 stage_01→stage_02", results, counters)

	## 37. 末关回环（stage_06 → stage_01）。
	current_stage_index = 5
	_load_stage(5)
	stage_runner.load_stage("stage_06")
	loop_count = 0
	score.set_loop(0)
	_on_stage_complete()
	_check(current_stage_index == 0, "末关回环 stage_06→stage_01", results, counters)

	## 38. 周目 +1。
	_check(loop_count == 1, "末关通关周目 +1", results, counters)

	## 输出结果。
	var summary := "M3 selftest: %d passed, %d failed" % [counters["passed"], counters["failed"]]
	print(summary)
	for r in results:
		print(r)
	## CI 门禁（ci.yml）断言 "SELFTEST PASS" / "SELFTEST FAIL"。
	print("SELFTEST PASS" if counters["failed"] == 0 else "SELFTEST FAIL")
	if counters["failed"] > 0:
		push_error("M3 selftest FAILED: %d checks" % counters["failed"])
