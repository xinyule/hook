## M6 主场景控制器。
## 继承 M5Arena，扩展 Stage 5-6 的 Boss 战（SMEE / HOOK）、机关道具
## （运财小兵 / 炮台 / Tinker Bell / 鳄鱼结局）与场景构建。
## 复用 M3 框架层、M2 战斗核心、M4/M5 模式，M6 只加场景、Boss、机关与自测。
## 所有数值来自 data/*.json，不硬编码。
extends M5Arena
class_name M6Arena

## ---- M6 扩展 ----
var props6: M6Props = null
var stage_scene6: M6StageScene = null
var boss6: M6Boss = null
## 鳄鱼结局进行中标志。
var _ending_active: bool = false

## ---- 构建 ----

## 初始化。
func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	M3Data.logic_only = selftest
	M4Data.logic_only = selftest
	M5Data.logic_only = selftest
	M6Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界灰盒与 M6 场景。
func _build_world() -> void:
	## M3 地面/墙/相机 + M5 场景节点（对 stage_05/06 无操作，无害）。
	super._build_world()
	## M6 场景构建器。
	stage_scene6 = M6StageScene.new()
	add_child(stage_scene6)

## 构建 M3/M5 系统 + M6 扩展。
func _build_systems() -> void:
	## M3 系统 + M5 道具/Boss 血条。
	super._build_systems()
	## M6 机关道具管理器。
	props6 = M6Props.new()
	add_child(props6)

## 加载指定索引的关卡（M6 扩展：构建场景 + 初始化道具 + 清空结局状态）。
func _load_stage(index: int) -> void:
	## M5 加载流程（M5 场景/道具对 stage_05/06 无害）。
	super._load_stage(index)
	## 构建 M6 场景与光照。
	var sid: String = stage_runner.stage_data.get("id", "")
	if stage_scene6 != null:
		stage_scene6.build(sid, stage_runner.stage_data)
	## 初始化 M6 机关道具。
	if props6 != null:
		props6.setup(self, sid)
	## 清空结局状态。
	_ending_active = false

## 生成当前关卡的 Boss。M6 Boss（SMEE/HOOK）用 M6Boss，M5 Boss 走父类逻辑。
func _spawn_boss() -> void:
	var stage_data: Dictionary = stage_runner.stage_data
	var boss_data: Dictionary = stage_data.get("boss", {})
	var boss_id: String = boss_data.get("id", "boss_04")
	if boss_id in ["boss_05", "boss_06"]:
		_spawn_m6_boss(boss_id)
	else:
		## M5 Boss（DAMON / 假 Hook）保持父类行为。
		super._spawn_boss()

## 生成 M6 Boss（SMEE 或 HOOK）。
func _spawn_m6_boss(boss_id: String) -> void:
	_clear_boss()
	var sx: float = _box() * 0.5
	boss6 = M6Boss.new()
	add_child(boss6)
	boss6.setup_boss(boss_id, sx, self)
	var target: Array = player_manager.active_players()
	if not target.is_empty():
		boss6.player = target[0]
	enemies.append(boss6)
	boss6.defeat_sequence_finished.connect(_on_boss_defeated)

## 清空 Boss（M5 boss + M6 boss6）。
func _clear_boss() -> void:
	super._clear_boss()
	if boss6 != null and is_instance_valid(boss6):
		boss6.queue_free()
	boss6 = null

## Boss 击败信号回调（延迟处理）。
func _on_boss_defeated() -> void:
	_boss_defeated = true

## Boss 击败后的关卡推进。HOOK 击败触发鳄鱼结局，SMEE 直接推进。
func _on_boss_defeated_tick() -> void:
	if boss6 != null and is_instance_valid(boss6) and boss6.boss_id == "boss_06":
		## HOOK 击败 → 鳄鱼结局演出。
		_clear_boss()
		if props6 != null:
			props6.spawn_crocodile()
		_ending_active = true
		return
	_clear_boss()
	_on_stage_complete()

## ---- 兼容接口（供 m6_boss 调用）----

## 召唤炮台三连发（由 SMEE 调用，委托给 props6）。
func spawn_cannon_triple(x: float, dir: int, range: float, damage: int, kb: float) -> void:
	if props6 != null:
		props6.spawn_cannon_triple(x, dir, range, damage, kb)

## 召唤 HOOK 杂兵刷新（由 HOOK 阶段 2 调用，生成普通敌人）。
func spawn_hook_adds(count: int) -> void:
	for i in count:
		if enemies.size() >= 12:
			break
		var e := M2Enemy.new()
		var sx: float = _box() * 0.6
		e.name = "HookAdd"
		add_child(e)
		e.setup_enemy("grunt", sx, 0)
		var target: Array = player_manager.active_players()
		if not target.is_empty():
			e.player = target[0]
		enemies.append(e)

## ---- 模拟帧 ----

## 模拟一帧（M6 扩展：道具 tick、拾取、可击碎、Boss 引用、结局）。
func simulate_tick(dt: float) -> void:
	## M5 基础逻辑（含 M5 道具/假 Hook/气功波）。
	super.simulate_tick(dt)
	## M6 道具推进。
	if props6 != null:
		props6.tick(dt)
	## M6 拾取检测（Tinker Bell 回血）。
	if props6 != null:
		props6.check_pickups(player_manager)
	## M6 可击碎物件受击检测。
	_check_breakable_hits6()
	## 更新 M6 Boss 目标玩家引用。
	if boss6 != null and is_instance_valid(boss6) and boss6.player == null:
		var active: Array = player_manager.active_players()
		if not active.is_empty():
			boss6.player = active[0]
	## 更新 Boss 血条。
	_update_boss_bar()
	## 鳄鱼结局推进。
	_tick_ending()

## 检测玩家攻击命中 M6 可击碎物件。
func _check_breakable_hits6() -> void:
	if props6 == null:
		return
	for p in player_manager.all_players():
		if p.is_dead or not is_instance_valid(p):
			continue
		if p.state in ["Attack1", "Attack2", "Attack3", "Attack4", "Special", "Heavy", "jump_attack"]:
			var hb: Rect2 = p.current_hitbox()
			if hb != Rect2():
				props6.apply_attack_to_breakables(hb, p)

## 鳄鱼结局推进：演出结束则关卡完成。
func _tick_ending() -> void:
	if _ending_active and props6 != null and props6.is_crocodile_done():
		_ending_active = false
		_on_stage_complete()

## 更新 Boss 血条显示。优先 M6 boss6，回退 M5 boss。
func _update_boss_bar() -> void:
	if boss_bar_label == null or boss_bar_progress == null:
		return
	if boss6 != null and is_instance_valid(boss6) and not boss6.is_dead:
		boss_bar_label.text = boss6.boss_cfg.get("display_name", "")
		boss_bar_progress.value = float(boss6.hp) / float(boss6.max_hp) * 100.0
		return
	if boss != null and is_instance_valid(boss) and not boss.is_dead:
		boss_bar_label.text = boss.boss_cfg.get("display_name", "")
		boss_bar_progress.value = float(boss.hp) / float(boss.max_hp) * 100.0
		return
	boss_bar_label.text = ""
	boss_bar_progress.value = 0.0

## ---- Headless 自测 ----

## 运行 M3 + M5 + M6 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项 + M5 扩展层 40 项 + M6 扩展层断言。
	_m3_selftest_checks(results, counters)
	_m5_selftest_checks(results, counters)
	_m6_selftest_checks(results, counters)
	_selftest_output(results, counters, "M6")

## M6 扩展层自测断言。
func _m6_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. stage_05 波次数据加载。
	stage_runner.load_stage("stage_05")
	var s5_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s5_segs.size() >= 3, "M6 stage_05 段落数 >= 3", results, counters)

	## 2. stage_05 5-A 波次非空。
	var s5_waves: Array = s5_segs[0].get("waves", [])
	_check(not s5_waves.is_empty(), "M6 stage_05 5-A 波次非空", results, counters)

	## 3. stage_05 5-B 波次非空。
	var s5_waves_b: Array = s5_segs[1].get("waves", [])
	_check(not s5_waves_b.is_empty(), "M6 stage_05 5-B 波次非空", results, counters)

	## 4. stage_05 5-C 隐藏点配置。
	var s5_hp: Array = s5_segs[2].get("hidden_points", [])
	_check(not s5_hp.is_empty(), "M6 stage_05 5-C 隐藏点配置", results, counters)

	## 5. stage_06 波次数据加载。
	stage_runner.load_stage("stage_06")
	var s6_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s6_segs.size() >= 3, "M6 stage_06 段落数 >= 3", results, counters)

	## 6. stage_06 6-A 波次非空。
	var s6_waves: Array = s6_segs[0].get("waves", [])
	_check(not s6_waves.is_empty(), "M6 stage_06 6-A 波次非空", results, counters)

	## 7. stage_06 6-B 波次非空。
	var s6_waves_b: Array = s6_segs[1].get("waves", [])
	_check(not s6_waves_b.is_empty(), "M6 stage_06 6-B 波次非空", results, counters)

	## 8. stage_06 6-C 隐藏点配置。
	var s6_hp: Array = s6_segs[2].get("hidden_points", [])
	_check(not s6_hp.is_empty(), "M6 stage_06 6-C 隐藏点配置", results, counters)

	## 9. SMEE Boss 数据加载。
	var smee_cfg: Dictionary = M6Data.boss("boss_05")
	_check(not smee_cfg.is_empty() and smee_cfg.get("display_name") == "SMEE", "M6 SMEE Boss 数据加载", results, counters)

	## 10. HOOK Boss 数据加载。
	var hook_cfg: Dictionary = M6Data.boss("boss_06")
	_check(not hook_cfg.is_empty() and hook_cfg.get("display_name") == "HOOK", "M6 HOOK Boss 数据加载", results, counters)

	## 11. bosses_m6 数据加载。
	var bosses_cfg: Dictionary = M6Data.bosses_m6()
	_check(not bosses_cfg.is_empty(), "M6 bosses_m6 数据加载", results, counters)

	## 12. props_m6 数据加载。
	var props_cfg: Dictionary = M6Data.props_m6()
	_check(not props_cfg.is_empty(), "M6 props_m6 数据加载", results, counters)

	## 13. 运财小兵配置读取。
	var tc_cfg: Dictionary = M6Data.treasure_carrier_cfg()
	_check(tc_cfg.has("treasure_drop_score") and tc_cfg.has("score"), "M6 运财小兵配置读取", results, counters)

	## 14. 炮台配置读取。
	var cannon_cfg: Dictionary = M6Data.cannon_cfg()
	_check(cannon_cfg.has("shot_damage") and cannon_cfg.has("warning_frames"), "M6 炮台配置读取", results, counters)

	## 15. Tinker Bell 配置读取。
	var tb_cfg: Dictionary = M6Data.tinker_bell_cfg()
	_check(tb_cfg.has("heal_percent") and tb_cfg.has("hidden_point_score"), "M6 Tinker Bell 配置读取", results, counters)

	## 16. 鳄鱼配置读取。
	var croc_cfg: Dictionary = M6Data.crocodile_cfg()
	_check(croc_cfg.has("ending_duration_frames") and croc_cfg.has("shake"), "M6 鳄鱼配置读取", results, counters)

	## 17. 可击碎物件配置读取。
	var brk_cfg: Dictionary = M6Data.breakables_cfg()
	_check(brk_cfg.has("crate") and brk_cfg.has("barrel") and brk_cfg.has("decoration"), "M6 可击碎物件配置读取", results, counters)

	## 18. M6Props 初始化 stage_05 生成道具。
	props6.setup(self, "stage_05")
	_check(not props6.prop_records.is_empty(), "M6 props 初始化 stage_05 生成道具", results, counters)

	## 19. M6Props 初始化 stage_06 生成道具。
	props6.setup(self, "stage_06")
	_check(not props6.prop_records.is_empty(), "M6 props 初始化 stage_06 生成道具", results, counters)

	## 20. SMEE Boss 生成。
	var smee: M6Boss = M6Boss.new()
	add_child(smee)
	smee.setup_boss("boss_05", 5.0, self)
	_check(smee.hp > 0 and smee.max_hp > 0, "M6 SMEE Boss 生成", results, counters)

	## 21. HOOK Boss 生成。
	var hook: M6Boss = M6Boss.new()
	add_child(hook)
	hook.setup_boss("boss_06", 5.0, self)
	_check(hook.hp > 0 and hook.max_hp > 0, "M6 HOOK Boss 生成", results, counters)

	## 22. SMEE HP 数值匹配。
	_check(smee.max_hp == int(smee_cfg.get("hp", 0)), "M6 SMEE HP 数值匹配数据", results, counters)

	## 23. HOOK HP 数值匹配。
	_check(hook.max_hp == int(hook_cfg.get("hp", 0)), "M6 HOOK HP 数值匹配数据", results, counters)

	## 24. SMEE 招式表加载。
	var smee_moves: Dictionary = smee.moves_cfg
	_check(smee_moves.has("kowtow") and smee_moves.has("slash") and smee_moves.has("cannon_triple"), "M6 SMEE 招式表加载", results, counters)

	## 25. HOOK 招式表加载。
	var hook_moves: Dictionary = hook.moves_cfg
	_check(hook_moves.has("sword") and hook_moves.has("hook") and hook_moves.has("charge"), "M6 HOOK 招式表加载", results, counters)

	## 26. SMEE 受击掉血。
	var smee_hp_before: int = smee.hp
	smee.take_damage(30, 1, 1.0, 3001)
	_check(smee.hp < smee_hp_before, "M6 SMEE 受击掉血", results, counters)

	## 27. SMEE 击败演出触发。
	smee.hp = 1
	smee.take_damage(999, 1, 1.0, 3002)
	_check(smee._defeat_started, "M6 SMEE 击败演出触发", results, counters)

	## 28. SMEE 击败演出终结。
	smee.finish_defeat()
	smee._tick_defeat(self)
	_check(smee.is_dead, "M6 SMEE 击败演出终结", results, counters)
	smee.queue_free()

	## 29. HOOK 受击掉血。
	var hook_hp_before: int = hook.hp
	hook.take_damage(40, 1, 1.0, 3003)
	_check(hook.hp < hook_hp_before, "M6 HOOK 受击掉血", results, counters)

	## 30. HOOK 击败演出触发。
	hook.hp = 1
	hook.take_damage(999, 1, 1.0, 3004)
	_check(hook._defeat_started, "M6 HOOK 击败演出触发", results, counters)

	## 31. HOOK 击败演出终结。
	hook.finish_defeat()
	hook._tick_defeat(self)
	_check(hook.is_dead, "M6 HOOK 击败演出终结", results, counters)
	hook.queue_free()

	## 32. HOOK 阶段 2 切换（半血）。
	var hook2: M6Boss = M6Boss.new()
	add_child(hook2)
	hook2.setup_boss("boss_06", 5.0, self)
	hook2.hp = int(float(hook2.max_hp) * 0.55)
	hook2._tick_hook_phases(self)
	_check(hook2.phase == 2 and hook2.phase_switched, "M6 HOOK 半血切换阶段 2", results, counters)

	## 33. HOOK 阶段 3 切换（低血）。
	hook2.hp = int(float(hook2.max_hp) * 0.25)
	hook2._tick_hook_phases(self)
	_check(hook2.phase == 3, "M6 HOOK 低血切换阶段 3", results, counters)

	## 34. HOOK 杂兵刷新。
	_clear_enemies()
	var adds_before: int = enemies.size()
	spawn_hook_adds(3)
	_check(enemies.size() > adds_before, "M6 HOOK 杂兵刷新生成", results, counters)

	## 35. SMEE 炮台三连发。
	props6.clear_all()
	props6.spawn_cannon_triple(0.0, 1, 7.0, 10, 1.5)
	_check(props6.cannon_shots.size() == 3, "M6 SMEE 炮台三连发", results, counters)

	## 36. 炮台弹道命中玩家。
	props6.clear_all()
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	var p0: M2Player = player_manager.players[0]
	p0.global_position = Vector3(3.0, 0.0, 0.0)
	p0.invincible_frames = 0
	props6.spawn_cannon_triple(2.5, 1, 7.0, 12, 1.5)
	## 推进弹道直到命中。
	for i in 200:
		props6.tick(0.016)
		if props6.cannon_shots.is_empty():
			break
	_check(p0.hp < p0.max_hp, "M6 炮台弹道命中玩家扣血", results, counters)

	## 37. 运财小兵击碎掉财宝计分。
	props6.clear_all()
	score.reset()
	props6.spawn_prop("treasure_carrier", 2.0)
	var tc_rec: Dictionary = {}
	for rec in props6.prop_records:
		if rec.type == "treasure_carrier":
			tc_rec = rec
			break
	tc_rec.hp = 1
	props6.apply_attack_to_breakables(Rect2(2.0 - 0.3, -0.3, 0.6, 0.6), p0)
	_check(score.score > 0, "M6 运财小兵击碎掉财宝计分", results, counters)

	## 38. 可击碎物件击碎计分。
	props6.clear_all()
	score.reset()
	props6.spawn_prop("crate", 2.0)
	var crate_rec: Dictionary = {}
	for rec in props6.prop_records:
		if rec.type == "crate":
			crate_rec = rec
			break
	crate_rec.hp = 1
	props6.apply_attack_to_breakables(Rect2(2.0 - 0.3, -0.3, 0.6, 0.6), p0)
	_check(score.score > 0, "M6 可击碎物件击碎计分", results, counters)

	## 39. Tinker Bell 回血。
	props6.clear_all()
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	p0 = player_manager.players[0]
	p0.hp = 1
	p0.invincible_frames = 0
	props6.spawn_prop("tinker_bell", 3.0)
	p0.global_position = Vector3(3.0, 0.0, 0.0)
	props6.check_pickups(player_manager)
	_check(p0.hp > 1, "M6 Tinker Bell 回血", results, counters)

	## 40. Tinker Bell 加分隐藏点。
	score.reset()
	props6.clear_all()
	props6.spawn_prop("tinker_bell", 3.0)
	p0.global_position = Vector3(3.0, 0.0, 0.0)
	props6.check_pickups(player_manager)
	_check(score.score > 0, "M6 Tinker Bell 加分", results, counters)

	## 41. 鳄鱼登场。
	props6.clear_all()
	props6.spawn_crocodile()
	_check(props6.crocodile_active, "M6 鳄鱼登场", results, counters)

	## 42. 鳄鱼演出结束判定。
	props6.crocodile_timer = 1
	props6.tick(0.016)
	_check(props6.is_crocodile_done(), "M6 鳄鱼演出结束判定", results, counters)

	## 43. HOOK 击败触发鳄鱼结局。
	props6.clear_all()
	_ending_active = false
	var hook3: M6Boss = M6Boss.new()
	add_child(hook3)
	hook3.setup_boss("boss_06", 5.0, self)
	boss6 = hook3
	boss6.player = p0
	enemies.append(boss6)
	boss6.hp = 1
	boss6.take_damage(999, 1, 1.0, 3005)
	boss6.finish_defeat()
	boss6._tick_defeat(self)
	_on_boss_defeated_tick()
	_check(props6.crocodile_active and _ending_active, "M6 HOOK 击败触发鳄鱼结局", results, counters)

	## 44. 鳄鱼结局完成后关卡推进。
	current_stage_index = 5
	props6.crocodile_timer = 1
	props6.tick(0.016)
	_tick_ending()
	_check(not _ending_active, "M6 鳄鱼结局完成后结束标志清除", results, counters)

	## 45. Boss 段进入生成 SMEE（stage_05）。
	_clear_boss()
	_clear_enemies()
	stage_runner.load_stage("stage_05")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(boss6 != null and is_instance_valid(boss6) and boss6.boss_id == "boss_05", "M6 Boss 段进入生成 SMEE", results, counters)

	## 46. Boss 段进入生成 HOOK（stage_06）。
	_clear_boss()
	_clear_enemies()
	stage_runner.load_stage("stage_06")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(boss6 != null and is_instance_valid(boss6) and boss6.boss_id == "boss_06", "M6 Boss 段进入生成 HOOK", results, counters)

	## 47. Boss 血条显示 SMEE。
	_clear_boss()
	_clear_enemies()
	stage_runner.load_stage("stage_05")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	_update_boss_bar()
	_check(boss_bar_label.text == "SMEE", "M6 Boss 血条显示 SMEE", results, counters)

	## 48. Boss 血条显示 HOOK。
	_clear_boss()
	_clear_enemies()
	stage_runner.load_stage("stage_06")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	_update_boss_bar()
	_check(boss_bar_label.text == "HOOK", "M6 Boss 血条显示 HOOK", results, counters)

	## 49. 六关完整数据加载。
	var order: Array = M3Data.stage_order()
	var all_loaded := true
	for sid in order:
		stage_runner.load_stage(sid)
		if stage_runner.stage_data.is_empty():
			all_loaded = false
	_check(all_loaded and order.size() == 6, "M6 六关完整数据加载", results, counters)

	## 50. 末关 HOOK 击败回环。
	_clear_boss()
	_clear_enemies()
	current_stage_index = 5
	loop_count = 0
	score.set_loop(0)
	stage_runner.load_stage("stage_06")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	boss6.hp = 1
	boss6.take_damage(999, 1, 1.0, 3006)
	boss6.finish_defeat()
	boss6._tick_defeat(self)
	_on_boss_defeated_tick()
	## 推进鳄鱼结局直到完成。
	for i in 300:
		if not _ending_active:
			break
		props6.tick(0.016)
		_tick_ending()
	_check(current_stage_index == 0 and loop_count == 1, "M6 末关 HOOK 击败回环周目+1", results, counters)

	## 清理测试 Boss 与道具。
	_clear_boss()
	_clear_enemies()
	props6.clear_all()
